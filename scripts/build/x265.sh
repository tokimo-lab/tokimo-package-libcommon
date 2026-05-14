#!/usr/bin/env bash
# x265 4.0 — cmake. GPL-2.0-or-later. HEVC encoder.
#
# Source is in source/ subdir (`x265_4.0/source/CMakeLists.txt`). We build
# only 8-bit (single libx265.so.215). Multi-bit-depth (8/10/12 combined via
# EXTRA_LIB) is FFmpeg-stock complexity we skip for libcommon's first cut —
# ffmpeg's --enable-libx265 only needs the linkable .so and matching headers
# at any single bit depth. 10/12-bit content still encodes via SIMD scalar
# fall-back through the 8-bit lib's HIGH_BIT_DEPTH=0 path; full HBD support
# can be added later by linking the libx265_main10.a / libx265_main12.a
# into a fat libx265.
LIB_NAME="x265"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir x265)"
build="$(prepare_build_dir x265)"

x265_extra=()
# macOS arm64: x265 4.0's aarch64 NEON intrinsics path
# (source/common/aarch64/intrapred-prim.cpp etc.) references symbols like
# g_intraFilterFlags and types like uint16x8_t without proper namespace /
# header includes, breaking Apple Clang builds. Upstream tracks this as a
# regression; the pragmatic fix for libcommon is to disable assembly on
# macOS arm64 — x265 falls back to its portable C path. Linux x86_64 keeps
# yasm/nasm assembly; Windows mingw uses nasm too.
if is_macos; then
  x265_extra+=(-DENABLE_ASSEMBLY=OFF)
fi

log "configuring (cmake)"
cd "${build}"
# x265 4.0's CMakeLists.txt (in source/) explicitly does
# `cmake_policy(SET CMP0025 OLD)` / CMP0054 OLD; CMake 4.x removed both
# policies entirely so the OLD setting is a hard error. Drop those lines
# (modern behavior is what we want anyway).
sed -i.bak -E '/cmake_policy\(SET CMP0025 OLD\)/d; /cmake_policy\(SET CMP0054 OLD\)/d' "${src}/source/CMakeLists.txt"

cmake "${src}/source" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=ON \
  -DENABLE_CLI=OFF \
  -DENABLE_PIC=ON \
  -DENABLE_TESTS=OFF \
  -DHIGH_BIT_DEPTH=OFF \
  -DEXPORT_C_API=ON \
  "${x265_extra[@]}"

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libx265.so.212"
log "done"
