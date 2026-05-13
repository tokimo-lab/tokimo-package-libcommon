#!/usr/bin/env bash
# lz4 1.10.0 — cmake project lives under build/cmake/
LIB_NAME="lz4"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir lz4)"
build="$(prepare_build_dir lz4)"

need_tool cmake

log "configuring"
cmake -S "${src}/build/cmake" -B "${build}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DLZ4_BUILD_CLI=OFF \
  -DLZ4_BUILD_LEGACY_LZ4C=OFF

log "building"
cmake --build "${build}" -j"${NPROC}"

log "installing"
cmake --install "${build}"

log "post-processing"
post_process_install

assert_soname "liblz4.so.1"
log "done"
