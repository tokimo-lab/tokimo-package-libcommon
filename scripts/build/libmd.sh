#!/usr/bin/env bash
# libmd 1.1.0 — autotools.
LIB_NAME="libmd"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libmd)"
build="$(prepare_build_dir libmd)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
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

assert_soname "libmd.so.0"
log "done"
