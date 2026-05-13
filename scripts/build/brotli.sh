#!/usr/bin/env bash
# brotli 1.1.0 — cmake. We ship libbrotlicommon + libbrotlidec only; the
# encoder is dropped after install to keep libcommon's surface tight.
LIB_NAME="brotli"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir brotli)"
build="$(prepare_build_dir brotli)"

need_tool cmake

log "configuring"
cmake -S "${src}" -B "${build}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_C_FLAGS="${CFLAGS}" \
  -DBUILD_SHARED_LIBS=ON \
  -DBROTLI_DISABLE_TESTS=ON

log "building"
cmake --build "${build}" -j"${NPROC}"

log "installing"
cmake --install "${build}"

# Drop encoder — not part of libcommon's exported surface.
rm -f "${INSTALL_DIR}/lib"/libbrotlienc.a 2>/dev/null || true
drop_lib libbrotlienc
drop_pc libbrotlienc

log "post-processing"
post_process_install

assert_soname "libbrotlicommon.so.1"
assert_soname "libbrotlidec.so.1"
log "done"
