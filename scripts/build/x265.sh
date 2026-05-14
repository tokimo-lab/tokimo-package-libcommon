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
# macOS arm64: no x86 asm (yasm/nasm targeting x86) — x265 has its own
# arm64 NEON path enabled via ENABLE_ASSEMBLY=ON + CMAKE_SYSTEM_PROCESSOR.
if is_macos; then
  x265_extra+=(-DCROSS_COMPILE_ARM=OFF -DENABLE_ASSEMBLY=ON)
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

assert_soname "libx265.so.215"
log "done"
