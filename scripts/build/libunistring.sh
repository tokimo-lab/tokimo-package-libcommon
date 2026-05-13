#!/usr/bin/env bash
# libunistring 1.2 — autotools.
LIB_NAME="libunistring"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libunistring)"
build="$(prepare_build_dir libunistring)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-rpath

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libunistring.so.5"
log "done"
