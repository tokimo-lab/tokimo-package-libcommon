#!/usr/bin/env bash
# zstd 1.5.7 — cmake build lives under build/cmake/, NOT the top-level dir.
LIB_NAME="zstd"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir zstd)"
build="$(prepare_build_dir zstd)"

need_tool cmake

log "configuring (cmake from build/cmake)"
cmake -S "${src}/build/cmake" -B "${build}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DZSTD_BUILD_SHARED=ON \
  -DZSTD_BUILD_STATIC=OFF \
  -DZSTD_BUILD_PROGRAMS=OFF \
  -DZSTD_BUILD_TESTS=OFF \
  -DZSTD_LEGACY_SUPPORT=OFF \
  -DZSTD_PROGRAMS_LINK_SHARED=ON

log "building"
cmake --build "${build}" -j"${NPROC}"

log "installing"
cmake --install "${build}"

log "post-processing"
post_process_install

assert_soname "libzstd.so.1"
log "done"
