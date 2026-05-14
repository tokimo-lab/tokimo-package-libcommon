#!/usr/bin/env bash
# dav1d 1.5.1 — meson. BSD-2-Clause. AV1 decoder by VideoLAN.
#
# No internal libcommon deps. We disable tools (dav1d CLI), tests, and
# examples — ffmpeg only consumes libdav1d.so via pkg-config + --enable-libdav1d.
LIB_NAME="dav1d"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir dav1d)"
build="$(prepare_build_dir dav1d)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Denable_tools=false \
    -Denable_tests=false \
    -Denable_examples=false

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "post-processing"
post_process_install

assert_soname "libdav1d.so.7"
log "done"
