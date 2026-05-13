#!/usr/bin/env bash
# libpng 1.6.43 — autotools. Depends on zlib.
LIB_NAME="libpng"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libpng)"
build="$(prepare_build_dir libpng)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
CPPFLAGS="-I${INSTALL_DIR}/include" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libpng16.so.16"
log "done"
