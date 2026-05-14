#!/usr/bin/env bash
# SVT-AV1 2.2.1 — cmake. BSD-3-Clause. Scalable AV1 encoder (Intel + AOM).
#
# x86 has native asm; arm64 has NEON. We disable APPS so we don't build the
# SvtAv1EncApp CLI (pulls extra deps and is not consumed by ffmpeg).
LIB_NAME="SVT-AV1"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir SVT-AV1)"
build="$(prepare_build_dir SVT-AV1)"

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_APPS=OFF \
  -DBUILD_DEC=OFF \
  -DBUILD_TESTING=OFF \
  -DENABLE_NASM=ON

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libSvtAv1Enc.so.3"
log "done"
