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
  linux-x86_64)   export PLATFORM="linux-x86_64" ;;
  *) echo "FATAL: platform ${HOST_OS}-${HOST_ARCH} not supported in P1.A" >&2; exit 1 ;;
esac

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
export LDFLAGS="${LDFLAGS:-} -L${INSTALL_DIR}/lib -L${INSTALL_DIR}/lib64 -Wl,-z,noseparate-code"

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

# Post-process every produced .so in install/lib:
#   1. force RUNPATH = $ORIGIN
#   2. strip --strip-unneeded (preserve dynsym)
# Skips static libs and non-ELF files. Idempotent.
post_process_install() {
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
      # Strip any pre-existing RPATH/RUNPATH first, then install RUNPATH
      # (NOT RPATH). Without --force-rpath, patchelf emits DT_RUNPATH, which
      # honors LD_LIBRARY_PATH overrides and is the modern default.
      #
      # IDEMPOTENCY GUARD: patchelf 0.17.2 has a cumulative bug — each
      # --set-rpath pass appends extra zero-size RW LOAD segments to the
      # file. After ~10+ passes the resulting file becomes unloadable with
      # "ELF load command address/offset not properly aligned" at runtime
      # (loader sees them, downstream libs that NEEDED us then fail to
      # load). Because post_process_install runs after every build and
      # patches every .so in install/lib, earlier libs accumulate dozens
      # of passes by the time later layers build. Skip files that are
      # already correctly patched.
      #
      # DATA-ONLY LIBS: skip files with zero DT_NEEDED entries (e.g.
      # libicudata.so — a 30 MB blob with no dependencies). Their giant
      # first LOAD segment confuses patchelf 0.17.2's segment-padding
      # arithmetic, producing alignment errors. They don't need RUNPATH
      # anyway since they don't dlopen anything.
      local current_rpath needed_count
      current_rpath="$(patchelf --print-rpath "${f}" 2>/dev/null || true)"
      needed_count="$(patchelf --print-needed "${f}" 2>/dev/null | wc -l)"
      if [[ "${current_rpath}" != '$ORIGIN' && "${needed_count}" -gt 0 ]]; then
        patchelf --remove-rpath "${f}" 2>/dev/null || true
        patchelf --set-rpath '$ORIGIN' "${f}" || log "warn: patchelf failed on ${f##*/}"
      fi
    fi
    if command -v strip >/dev/null 2>&1; then
      # Strip atomically: write to temp, only swap on success. Some binutils
      # versions (2.41 on AlmaLinux 8) SIGBUS mid-write on certain ELF files,
      # which would corrupt the original if we stripped in-place.
      if strip --strip-unneeded -o "${f}.stripped" "${f}" >/dev/null 2>&1; then
        mv -f "${f}.stripped" "${f}"
      else
        rm -f "${f}.stripped"
      fi
    fi
  done
  shopt -u nullglob

  # Drop static archives and libtool .la files — we only ship .so shared libs.
  rm -f "${INSTALL_DIR}/lib"/*.a "${INSTALL_DIR}/lib"/*.la 2>/dev/null || true
  rm -f "${INSTALL_DIR}/lib64"/*.a "${INSTALL_DIR}/lib64"/*.la 2>/dev/null || true

  # Normalize lib64 → lib for any *.so* files (RH default puts shared libs in
  # lib64; we want a single canonical install/lib so package.sh & verify.sh
  # see everything). Also relocate lib64/pkgconfig/*.pc -> lib/pkgconfig/*.pc.
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

# Verify expected SONAME exists in install/lib. Calls fail if not.
# Usage: assert_soname libz.so.1
assert_soname() {
  local expected="$1"
  local libdir="${INSTALL_DIR}/lib"
  need_tool objdump

  shopt -s nullglob
  local found=""
  for f in "${libdir}"/*.so*; do
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    local s
    # Unset LD_LIBRARY_PATH for the tool invocation: objdump itself links
    # against libz/libbfd, and our staged install/lib (which we put on
    # LD_LIBRARY_PATH so configure tests can run our libs) can clash with the
    # toolchain libz, causing "ELF load command address/offset not properly
    # aligned" and a 127 exit.
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
