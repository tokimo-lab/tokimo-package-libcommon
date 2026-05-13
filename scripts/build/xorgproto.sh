#!/usr/bin/env bash
# xorgproto 2024.1 — X11 protocol headers (X.h, Xproto.h, …). Header-only,
# no .so output. Built via meson (autotools build was dropped upstream).
LIB_NAME="xorgproto"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir xorgproto)"
build="$(prepare_build_dir xorgproto)"

log "configuring (meson)"
meson setup "${build}" "${src}" \
  --prefix="${INSTALL_DIR}" \
  --libdir=lib \
  --buildtype=release

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "done (headers + pkg-config only, no SONAME)"
