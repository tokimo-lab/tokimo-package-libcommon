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
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
# Default flags. -fPIC mandatory for shared libs; no -march so artifact is portable.
export CFLAGS="${CFLAGS:--O2 -fPIC -pipe}"
export CXXFLAGS="${CXXFLAGS:--O2 -fPIC -pipe}"
# RUNPATH is normalized by patchelf in post_process_install. Do NOT bake
# $ORIGIN into LDFLAGS — many upstream Makefiles will macro-expand it inside
# the build shell and emit a literal "RIGIN" rpath.
export LDFLAGS="${LDFLAGS:-}"

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
      patchelf --force-rpath --set-rpath '$ORIGIN' "${f}" || log "warn: patchelf failed on ${f##*/}"
    fi
    if command -v strip >/dev/null 2>&1; then
      strip --strip-unneeded "${f}" 2>/dev/null || true
    fi
  done
  shopt -u nullglob
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
    s="$(objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print $2; exit}')" || true
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
      objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print "    " $2}'
    done
    fatal "SONAME mismatch"
  fi
  log "verified SONAME: ${expected}  →  ${found#${INSTALL_DIR}/}"
}
