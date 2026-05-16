#!/usr/bin/env bash
# orc 0.4.40 — meson. BSD-3-Clause. Optimised Runtime Compiler used by
# libvips (and gstreamer) to JIT SIMD inner loops.
#
# Produces:
#   Linux:   liborc-0.4.so.0
#   macOS:   liborc-0.4.0.dylib
#   Windows: liborc-0.4-0.dll
#
# orc also installs `liborc-test-0.4.so.0` (test helpers) — we disable it
# via -Dorc-test=disabled because nothing in libvips/ffmpeg pipelines needs
# it and shipping it would force us to register an extra SONAME.
LIB_NAME="orc"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir orc)"
build="$(prepare_build_dir orc)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dorc-test=disabled \
    -Dbenchmarks=disabled \
    -Dexamples=disabled \
    -Dtests=disabled \
    -Dtools=disabled \
    -Dgtk_doc=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "post-processing"
post_process_install

assert_soname "liborc-0.4.so.0"
log "done"
