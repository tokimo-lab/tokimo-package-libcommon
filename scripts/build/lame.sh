#!/usr/bin/env bash
# lame 3.100 — autotools. LGPL-2.0-or-later. MP3 encoder library. No deps.
#
# Notes:
#   --disable-frontend  drops the lame CLI (would pull ncurses/termcap on
#                       some Linux distros; not needed for libavcodec link).
#   --disable-decoder   drops mpglib (decoding only); libmp3lame still
#                       provides the encoder symbols ffmpeg needs.
LIB_NAME="lame"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir lame)"
build="$(prepare_build_dir lame)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-frontend \
    --disable-decoder

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libmp3lame.so.0"
log "done"
