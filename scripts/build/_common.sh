#!/usr/bin/env bash
# Common helpers for per-library build scripts.
# Source this with `source "$(dirname "$0")/_common.sh"` from each lib script.

set -euo pipefail

# ─── paths (resolved relative to repo root) ─────────────────────────────────
SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "${SCRIPT_DIR_COMMON}/../.." && pwd)"
export SOURCES_DIR="${REPO_ROOT}/sources"
export BUILD_DIR="${REPO_ROOT}/build"
export INSTALL_DIR="${REPO_ROOT}/install"
export REGISTRY_FILE="${REPO_ROOT}/registry.toml"

# ─── platform ───────────────────────────────────────────────────────────────
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
case "${HOST_OS}-${HOST_ARCH}" in
  linux-x86_64)   export PLATFORM="linux-x86_64"; export SHLIB_EXT="so" ;;
  darwin-arm64)   export PLATFORM="macos-arm64"; export SHLIB_EXT="dylib" ;;
  *) echo "FATAL: platform ${HOST_OS}-${HOST_ARCH} not supported" >&2; exit 1 ;;
esac

is_linux() { [[ "${PLATFORM}" == "linux-x86_64" ]]; }
is_macos() { [[ "${PLATFORM}" == "macos-arm64" ]]; }
export -f is_linux is_macos 2>/dev/null || true

# GNU ld-only linker flag. Empty on macOS (Apple ld64 rejects it).
if is_linux; then
  export LDFLAGS_GNU_LD="-Wl,-z,noseparate-code"
else
  export LDFLAGS_GNU_LD=""
fi

# ─── toolchain knobs ────────────────────────────────────────────────────────
export NPROC="$(nproc 2>/dev/null || echo 4)"
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig:${INSTALL_DIR}/share/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
export CMAKE_PREFIX_PATH="${INSTALL_DIR}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
# Make build-time tools (e.g. glib-genmarshal) findable in their own subsequent
# invocations once installed under ${INSTALL_DIR}/bin.
export PATH="${INSTALL_DIR}/bin:${PATH}"
# NOTE: we deliberately do NOT export LD_LIBRARY_PATH=${INSTALL_DIR}/lib here.
# The toolchain (gcc, ld, objdump, readelf, strip…) is dynamically linked
# against system libz/libbfd; putting our freshly-built libz on
# LD_LIBRARY_PATH causes the loader to prefer ours and can fail with
# "ELF load command address/offset not properly aligned" or similar, breaking
# every subsequent invocation. Built artifacts get RUNPATH=$ORIGIN via
# post_process_install so they find siblings at runtime without
# LD_LIBRARY_PATH. Individual scripts can opt-in per-command if a configure
# test genuinely needs to execute one of our libs.
# Default flags. -fPIC mandatory for shared libs; no -march so artifact is portable.
export CFLAGS="${CFLAGS:--O2 -fPIC -pipe}"
export CXXFLAGS="${CXXFLAGS:--O2 -fPIC -pipe}"
# Help compiler/linker find our staged install tree without us having to
# repeat -I/-L flags in every build script. RUNPATH is normalized by patchelf
# in post_process_install (do NOT bake $ORIGIN here — many upstream Makefiles
# would expand it inside the shell and emit a literal "RIGIN" rpath).
export CPPFLAGS="${CPPFLAGS:-} -I${INSTALL_DIR}/include"
if is_linux; then
  export LDFLAGS="${LDFLAGS:-} -L${INSTALL_DIR}/lib -L${INSTALL_DIR}/lib64 -Wl,-z,noseparate-code"
else
  # macOS ld64: no -z,noseparate-code; no lib64 (macOS only uses lib).
  export LDFLAGS="${LDFLAGS:-} -L${INSTALL_DIR}/lib"
fi

# ─── logging ────────────────────────────────────────────────────────────────
log()   { printf '\033[1;34m[%s]\033[0m %s\n' "${LIB_NAME:-libcommon}" "$*"; }
fatal() { printf '\033[1;31m[%s] FATAL:\033[0m %s\n' "${LIB_NAME:-libcommon}" "$*" >&2; exit 1; }

# ─── helpers ────────────────────────────────────────────────────────────────

# Ensure a tool exists.
need_tool() {
  command -v "$1" >/dev/null 2>&1 || fatal "missing tool: $1"
}

# Read sha256sum of a SONAME from registry.toml. (Not used yet — registry has
# soname status, not source sha. We rely on deps.toml + fetch-sources.sh.)

# Drop unwanted shared-lib variants by basename stem (cross-platform).
#   drop_lib libfoo  → removes install/lib/libfoo.so*, libfoo.dylib,
#                       libfoo.*.dylib, libfoo-*.so*, libfoo-*.dylib, etc.
# Use ONLY exact stems (no glob chars). For wildcard stems use drop_lib_glob.
drop_lib() {
  local stem="$1"
  local libdir="${INSTALL_DIR}/lib"
  shopt -s nullglob
  local f
  for f in "${libdir}/${stem}".so* \
           "${libdir}/${stem}".dylib \
           "${libdir}/${stem}".*.dylib; do
    rm -f "${f}"
  done
  shopt -u nullglob
}

# Drop a pkg-config file by name (no .pc suffix).
drop_pc() {
  rm -f "${INSTALL_DIR}/lib/pkgconfig/$1.pc" 2>/dev/null || true
}

# Setup a clean per-lib build directory and return its path.
prepare_build_dir() {
  local name="$1"
  local b="${BUILD_DIR}/${name}"
  rm -rf "${b}"
  mkdir -p "${b}"
  echo "${b}"
}

# Find source root: sources/<name> directory.
source_dir() {
  local name="$1"
  local s="${SOURCES_DIR}/${name}"
  [[ -d "${s}" ]] || fatal "source dir not found: ${s} (run scripts/fetch-sources.sh first)"
  echo "${s}"
}

# Post-process every produced shared library in install/lib:
#   Linux:  RUNPATH=$ORIGIN, strip --strip-unneeded
#   macOS:  install_name=@rpath/<base>, LC_RPATH=@loader_path, rewrite
#           internal abs-path LC_LOAD_DYLIB refs to @rpath/<base>, fail on
#           brew/MacPorts leakage, ad-hoc codesign.
# Skips static libs and non-shared files. Idempotent.
post_process_install() {
  if is_macos; then
    post_process_install_macos
  else
    post_process_install_linux
  fi
}

post_process_install_linux() {
  local libdir="${INSTALL_DIR}/lib"
  [[ -d "${libdir}" ]] || return 0

  if ! command -v patchelf >/dev/null 2>&1; then
    log "patchelf not found, skipping RUNPATH normalization (CI MUST have patchelf)"
  fi

  shopt -s nullglob
  for f in "${libdir}"/*.so*; do
    # Resolve symlinks: only process real files.
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    # ELF check.
    head -c 4 "${f}" | od -An -c 2>/dev/null | grep -q "177   E   L   F" || continue

    if command -v patchelf >/dev/null 2>&1; then
      # See historical comment in earlier revision: patchelf 0.17.2 has a
      # cumulative append bug; data-only libs (libicudata) break it. Guard.
      local current_rpath needed_count
      current_rpath="$(patchelf --print-rpath "${f}" 2>/dev/null || true)"
      needed_count="$(patchelf --print-needed "${f}" 2>/dev/null | wc -l)"
      if [[ "${current_rpath}" != '$ORIGIN' && "${needed_count}" -gt 0 ]]; then
        patchelf --remove-rpath "${f}" 2>/dev/null || true
        patchelf --set-rpath '$ORIGIN' "${f}" || log "warn: patchelf failed on ${f##*/}"
      fi
    fi
    if command -v strip >/dev/null 2>&1; then
      if strip --strip-unneeded -o "${f}.stripped" "${f}" >/dev/null 2>&1; then
        mv -f "${f}.stripped" "${f}"
      else
        rm -f "${f}.stripped"
      fi
    fi
  done
  shopt -u nullglob

  # Drop static archives and libtool .la files.
  rm -f "${INSTALL_DIR}/lib"/*.a "${INSTALL_DIR}/lib"/*.la 2>/dev/null || true
  rm -f "${INSTALL_DIR}/lib64"/*.a "${INSTALL_DIR}/lib64"/*.la 2>/dev/null || true

  # Normalize lib64 → lib.
  if [[ -d "${INSTALL_DIR}/lib64" ]]; then
    mkdir -p "${INSTALL_DIR}/lib"
    shopt -s nullglob dotglob
    for src in "${INSTALL_DIR}/lib64"/*.so*; do
      [[ -e "${src}" ]] || continue
      mv -f "${src}" "${INSTALL_DIR}/lib/"
    done
    if [[ -d "${INSTALL_DIR}/lib64/pkgconfig" ]]; then
      mkdir -p "${INSTALL_DIR}/lib/pkgconfig"
      for pc in "${INSTALL_DIR}/lib64/pkgconfig"/*.pc; do
        [[ -f "${pc}" ]] || continue
        mv -f "${pc}" "${INSTALL_DIR}/lib/pkgconfig/"
      done
    fi
    shopt -u nullglob dotglob
  fi
}

# macOS: per-dylib post-processing.
#
# Each dylib in install/lib gets:
#   1. install_name (LC_ID_DYLIB) → @rpath/<basename>
#   2. LC_RPATH += @loader_path (idempotent: only add if missing)
#   3. Every LC_LOAD_DYLIB pointing inside ${INSTALL_DIR}/lib or to a build
#      tree → rewritten to @rpath/<dep-basename>
#   4. Any LC_LOAD_DYLIB pointing to /opt/homebrew, /opt/local, /usr/local
#      → FATAL (we missed a dep, must be built in libcommon)
#   5. ad-hoc codesign (-s -)
post_process_install_macos() {
  local libdir="${INSTALL_DIR}/lib"
  [[ -d "${libdir}" ]] || return 0

  need_tool install_name_tool
  need_tool otool
  need_tool codesign

  shopt -s nullglob
  for f in "${libdir}"/*.dylib; do
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    # Mach-O check (first 4 bytes 0xcffaedfe little-endian for 64-bit).
    local magic
    magic="$(xxd -p -l 4 "${f}" 2>/dev/null || true)"
    case "${magic}" in
      cffaedfe|cefaedfe|feedfacf|feedface) ;;
      *) continue ;;
    esac

    local base id
    base="$(basename "${f}")"
    id="@rpath/${base}"

    # 1. Set install_name.
    install_name_tool -id "${id}" "${f}" 2>/dev/null || \
      log "warn: install_name_tool -id failed on ${base}"

    # 2. Add LC_RPATH @loader_path if not already present.
    if ! otool -l "${f}" 2>/dev/null | grep -A2 'cmd LC_RPATH' | grep -q '@loader_path$'; then
      install_name_tool -add_rpath "@loader_path" "${f}" 2>/dev/null || true
    fi

    # 3. Rewrite LC_LOAD_DYLIB entries.
    local dep
    while IFS= read -r dep; do
      [[ -z "${dep}" ]] && continue
      case "${dep}" in
        # System: allowed as-is.
        /usr/lib/*|/System/Library/*|@rpath/*|@loader_path/*|@executable_path/*)
          continue
          ;;
        # Brew / MacPorts / user-local — these are leaks. FATAL.
        /opt/homebrew/*|/opt/local/*|/usr/local/*)
          fatal "${base}: links against ${dep} (must be built inside libcommon)"
          ;;
      esac

      local dep_base="$(basename "${dep}")"
      # Internal install prefix OR build tree refs → rewrite to @rpath.
      if [[ "${dep}" == "${INSTALL_DIR}/lib/"* ]] || \
         [[ "${dep}" == "${BUILD_DIR}/"* ]] || \
         [[ "${dep}" == "${REPO_ROOT}/"* ]]; then
        install_name_tool -change "${dep}" "@rpath/${dep_base}" "${f}" 2>/dev/null || true
        continue
      fi
      # Anything else (absolute path outside our tree, not in allow-list above) → fatal.
      fatal "${base}: unexpected LC_LOAD_DYLIB ${dep}"
    done < <(otool -L "${f}" 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v "^${base}$" || true)

    # 4. ad-hoc codesign (must be LAST: signature is invalidated by header edits).
    codesign -s - -f "${f}" 2>/dev/null || log "warn: codesign failed on ${base}"
  done
  shopt -u nullglob

  # Drop static archives + .la files.
  rm -f "${INSTALL_DIR}/lib"/*.a "${INSTALL_DIR}/lib"/*.la 2>/dev/null || true
}

# Map a Linux SONAME like "libfoo.so.N" to the default macOS dylib basename
# "libfoo.N.dylib". Most libcommon SONAMEs follow this rule; explicit
# overrides live in registry.toml's libs[].macos field.
soname_to_macos_basename() {
  local soname="$1"
  if [[ "${soname}" =~ ^(.+)\.so\.([0-9.]+)$ ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.dylib"
  else
    # No .so.N suffix → strip ".so" if present.
    echo "${soname%.so}.dylib"
  fi
}

# Verify expected SONAME exists in install/lib. Calls fail if not.
# Usage: assert_soname libz.so.1
#   Linux: checks SONAME via objdump.
#   macOS: looks for the corresponding dylib (default mapping) and verifies
#          its install_name is @rpath/<basename>.
assert_soname() {
  local expected="$1"
  local libdir="${INSTALL_DIR}/lib"

  if is_macos; then
    assert_soname_macos "${expected}"
    return
  fi

  need_tool objdump

  shopt -s nullglob
  local found=""
  for f in "${libdir}"/*.so*; do
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    local s
    s="$(env -u LD_LIBRARY_PATH objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print $2; exit}')" || true
    if [[ "${s}" == "${expected}" ]]; then
      found="${f}"
      break
    fi
  done
  shopt -u nullglob

  if [[ -z "${found}" ]]; then
    log "ERROR: expected SONAME '${expected}' not found in ${libdir}"
    log "Present:"
    for f in "${libdir}"/*.so*; do
      [[ -L "${f}" ]] && continue
      [[ -f "${f}" ]] || continue
      env -u LD_LIBRARY_PATH objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print "    " $2}'
    done
    fatal "SONAME mismatch"
  fi
  log "verified SONAME: ${expected}  →  ${found#${INSTALL_DIR}/}"
}

assert_soname_macos() {
  local expected="$1"
  local libdir="${INSTALL_DIR}/lib"
  local mac_base="${MACOS_SONAME_OVERRIDE:-}"
  [[ -z "${mac_base}" ]] && mac_base="$(soname_to_macos_basename "${expected}")"

  local f="${libdir}/${mac_base}"
  if [[ ! -f "${f}" || -L "${f}" ]]; then
    log "ERROR: expected dylib '${mac_base}' (for SONAME ${expected}) not found in ${libdir}"
    log "Present .dylib files:"
    shopt -s nullglob
    for x in "${libdir}"/*.dylib; do
      [[ -L "${x}" ]] && continue
      log "    ${x##*/}"
    done
    shopt -u nullglob
    fatal "macOS dylib missing for ${expected}"
  fi

  # Verify install_name = @rpath/<mac_base>
  local id
  id="$(otool -D "${f}" 2>/dev/null | tail -n +2 | head -1 | tr -d ' ')"
  if [[ "${id}" != "@rpath/${mac_base}" ]]; then
    log "WARN: ${mac_base} install_name is '${id}' (expected '@rpath/${mac_base}')"
  fi
  log "verified dylib: ${expected}  →  lib/${mac_base}"
  unset MACOS_SONAME_OVERRIDE
}
