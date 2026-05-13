#!/usr/bin/env bash
# libffi 3.4.6 — autotools.
LIB_NAME="libffi"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libffi)"
build="$(prepare_build_dir libffi)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-docs \
    --disable-multi-os-directory

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libffi.so.8"
log "done"
