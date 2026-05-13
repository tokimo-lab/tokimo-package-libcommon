#!/usr/bin/env bash
# lcms2 2.16 — autotools.
LIB_NAME="lcms2"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir lcms2)"
build="$(prepare_build_dir lcms2)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --without-jpeg \
    --without-tiff

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "liblcms2.so.2"
log "done"
