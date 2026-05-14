#!/usr/bin/env bash
# x264 (videolan stable snapshot 31e19f9, "r3107") — custom configure.
# GPL-2.0-or-later. H.264 encoder. No internal libcommon deps.
#
# Notes:
#   --enable-shared    libx264.so.164  (SONAME = X264_BUILD = 164)
#   --disable-cli      no x264 CLI binary (we only need the lib).
#   --disable-asm on macOS arm64 is NOT needed: x264 has full NEON asm.
#   On Windows / mingw the SONAME-like DLL is `libx264-164.dll` (autotools).
LIB_NAME="x264"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool nasm

src="$(source_dir x264)"
build="$(prepare_build_dir x264)"

# x264's configure expects to be run from inside the build directory using
# absolute path to its own configure script.
cd "${build}"

x264_extra=()
if is_windows; then
  # mingw: explicit host so configure picks "MINGW" + .dll output naming.
  x264_extra+=(--host=x86_64-w64-mingw32 --cross-prefix=)
fi

log "configuring"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-cli \
    --disable-lavf \
    --disable-swscale \
    --disable-ffms \
    --disable-gpac \
    --disable-lsmash \
    --enable-pic \
    "${x264_extra[@]}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libx264.so.164"
log "done"
