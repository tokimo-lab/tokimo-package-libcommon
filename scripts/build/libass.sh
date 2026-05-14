#!/usr/bin/env bash
# libass 0.17.3 — autotools. ISC. Subtitle renderer (ASS/SSA).
# Depends on base: freetype, fribidi, harfbuzz, fontconfig.
LIB_NAME="libass"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libass)"
build="$(prepare_build_dir libass)"

ass_extra=()
if is_windows; then
  # Disable fontconfig on Windows (use DirectWrite via core text not avail
  # on mingw; libass works with freetype-only path through harfbuzz).
  # Actually we built fontconfig on Windows in base layer — keep it on.
  :
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-require-system-font-provider \
    "${ass_extra[@]}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libass.so.9"
log "done"
