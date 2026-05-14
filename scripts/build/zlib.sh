#!/usr/bin/env bash
# zlib 1.3.1 — classic configure (custom, not autoconf)
LIB_NAME="zlib"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir zlib)"
build="$(prepare_build_dir zlib)"

if is_windows; then
  # zlib's posix-y configure script does not detect msys2 as Windows; it
  # would happily produce libz.so.1.3.1. Use the dedicated win32 makefile
  # (win32/Makefile.gcc) which produces the canonical mingw zlib1.dll +
  # libz.dll.a import library.
  log "building (win32/Makefile.gcc)"
  cd "${src}"
  make -f win32/Makefile.gcc clean >/dev/null 2>&1 || true
  # Build only library targets; skip test exes (example.exe / minigzip.exe)
  # which sometimes hit ld linker quirks on the runner and are not needed.
  make -j"${NPROC}" -f win32/Makefile.gcc \
    CFLAGS="${CFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    libz.a zlib1.dll

  log "installing"
  # win32/Makefile.gcc honors BINARY_PATH, INCLUDE_PATH, LIBRARY_PATH and
  # SHARED_MODE=1 (install both static + shared).
  make -f win32/Makefile.gcc install \
    BINARY_PATH="${INSTALL_DIR}/bin" \
    INCLUDE_PATH="${INSTALL_DIR}/include" \
    LIBRARY_PATH="${INSTALL_DIR}/lib" \
    SHARED_MODE=1

  log "post-processing"
  post_process_install
  WINDOWS_DLL_OVERRIDE="zlib1.dll" assert_soname "libz.so.1"
  log "done"
  exit 0
fi

log "configuring (out-of-tree)"
cd "${build}"
# zlib's configure must be run from the build dir AGAINST the src dir.
# It supports out-of-tree by SRCDIR env override only since 1.3+.
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --shared

log "building"
make -j"${NPROC}"

log "installing"
make install

if is_macos; then
  # zlib's macOS install rule only copies libz.<full-version>.dylib;
  # recreate the libz.dylib / libz.1.dylib symlinks we need.
  cd "${INSTALL_DIR}/lib"
  full=$(ls libz.*.dylib 2>/dev/null | grep -E '^libz\.[0-9.]+\.dylib$' | head -1)
  if [[ -n "${full}" ]]; then
    rm -f libz.dylib libz.1.dylib
    ln -s "${full}" libz.1.dylib
    ln -s "${full}" libz.dylib
  fi
  cd "${build}"
fi

log "post-processing"
post_process_install

assert_soname "libz.so.1"
log "done"
