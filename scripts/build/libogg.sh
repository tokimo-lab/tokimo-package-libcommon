#!/usr/bin/env bash
# libogg 1.3.5 — autotools. BSD-3-Clause. Ogg container (carrier for vorbis
# / theora / opus / FLAC). No internal libcommon deps.
LIB_NAME="libogg"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libogg)"
build="$(prepare_build_dir libogg)"

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

assert_soname "libogg.so.0"
log "done"
