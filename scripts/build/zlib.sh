#!/usr/bin/env bash
# zlib 1.3.1 — classic configure (custom, not autoconf)
LIB_NAME="zlib"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir zlib)"
build="$(prepare_build_dir zlib)"

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
