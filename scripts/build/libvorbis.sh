#!/usr/bin/env bash
# libvorbis 1.3.7 — autotools. BSD-3-Clause. Vorbis audio codec.
# Depends on libogg (Wave A).
LIB_NAME="libvorbis"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libvorbis)"
build="$(prepare_build_dir libvorbis)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-docs \
    --disable-examples

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libvorbis.so.0"
assert_soname "libvorbisenc.so.2"
log "done"
