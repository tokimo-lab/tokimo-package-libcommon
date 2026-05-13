#!/usr/bin/env bash
# libtasn1 4.20.0 — autotools.
LIB_NAME="libtasn1"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libtasn1)"
build="$(prepare_build_dir libtasn1)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libtasn1.so.6"
log "done"
