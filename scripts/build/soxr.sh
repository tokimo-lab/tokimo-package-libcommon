#!/usr/bin/env bash
# soxr 0.1.3 — cmake. LGPL-2.1-or-later. SoX Resampler library. No deps.
#
# We don't need lsr (libsamplerate ABI shim), tests, examples, or OpenMP
# threading (ffmpeg drives its own threading).
LIB_NAME="soxr"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir soxr)"
build="$(prepare_build_dir soxr)"

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DWITH_LSR_BINDINGS=OFF \
  -DWITH_OPENMP=OFF

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libsoxr.so.0"
log "done"
