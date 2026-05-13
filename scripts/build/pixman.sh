#!/usr/bin/env bash
# pixman 0.43.4 — meson-only (autotools was dropped upstream).
LIB_NAME="pixman"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir pixman)"
build="$(prepare_build_dir pixman)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dgtk=disabled \
    -Dlibpng=disabled \
    -Dtests=disabled \
    -Ddemos=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "post-processing"
post_process_install

assert_soname "libpixman-1.so.0"
log "done"
