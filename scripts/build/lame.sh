#!/usr/bin/env bash
# lame 3.100 — autotools. LGPL-2.0-or-later. MP3 encoder library. No deps.
#
# Notes:
#   --disable-frontend  drops the lame CLI (would pull ncurses/termcap on
#                       some Linux distros; not needed for libavcodec link).
#
# NOTE: do NOT pass --disable-decoder. Even when the decoder runtime is
# disabled, lame's exported symbol list (libmp3lame.sym) still references
# the hip_* / lame_decode_* symbols, which causes the link to fail on
# linkers that enforce export lists (Apple ld64, mingw ld). GNU ld on
# Linux silently tolerates the missing exports, but we keep the decoder
# enabled on every platform for parity. The extra mpglib code is ~30 KB.
LIB_NAME="lame"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir lame)"
build="$(prepare_build_dir lame)"

# lame 3.100 ships include/libmp3lame.sym which lists `lame_init_old`,
# but that symbol is no longer defined in the source. GNU ld silently
# tolerates the missing export, but Apple ld64 and mingw ld fail the
# link with "Undefined symbols: _lame_init_old". Drop the stale entry
# from the export list before configure. Patch is idempotent.
if grep -q '^lame_init_old$' "${src}/include/libmp3lame.sym"; then
  log "patching: remove stale lame_init_old export (not defined in 3.100)"
  sed -i.bak '/^lame_init_old$/d' "${src}/include/libmp3lame.sym"
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-frontend

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libmp3lame.so.0"
log "done"
