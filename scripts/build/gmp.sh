#!/usr/bin/env bash
# gmp 6.3.0 — autotools, no C++ bindings.
LIB_NAME="gmp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir gmp)"
build="$(prepare_build_dir gmp)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --enable-cxx=no

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libgmp.so.10"
log "done"
