#!/usr/bin/env bash
# graphite2 1.3.14 — cmake (C++).
LIB_NAME="graphite2"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir graphite2)"
build="$(prepare_build_dir graphite2)"

need_tool cmake

log "configuring"
cmake -S "${src}" -B "${build}" \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
  -DBUILD_SHARED_LIBS=ON \
  -DGRAPHITE2_COMPARE_RENDERER=OFF \
  -DGRAPHITE2_NTRACING=ON \
  -DGRAPHITE2_NFILEFACE=OFF \
  -DGRAPHITE2_TESTS=OFF \
  -DGRAPHITE2_NSEGCACHE=ON

log "building"
# graphite2 cmake adds tests/ subdir unconditionally; tests/featuremap fails
# on gcc 16 (missing <cstdint> includes). Build only the shared lib target.
cmake --build "${build}" -j"${NPROC}" --target graphite2

log "installing"
cmake --install "${build}"

log "post-processing"
post_process_install

assert_soname "libgraphite2.so.3"
log "done"
