#!/usr/bin/env bash
# expat 2.6.4 — autotools.
LIB_NAME="expat"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir expat)"
build="$(prepare_build_dir expat)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --without-docbook \
    --without-examples \
    --without-tests

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libexpat.so.1"
log "done"
