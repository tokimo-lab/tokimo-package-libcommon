#!/usr/bin/env bash
# fribidi 1.0.16 — ships both autotools (configure) and meson. Use autotools
# to keep the toolchain footprint small.
LIB_NAME="fribidi"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir fribidi)"
build="$(prepare_build_dir fribidi)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-debug \
    --disable-deprecated \
    --disable-docs

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libfribidi.so.0"
log "done"
