#!/usr/bin/env bash
# libaom 3.10.0 — cmake. BSD-2-Clause + PATENTS. AV1 reference encoder/decoder.
LIB_NAME="libaom"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir libaom)"
build="$(prepare_build_dir libaom)"

aom_extra=()
if is_macos; then
  # arm64 native; aom auto-detects via CMAKE_SYSTEM_PROCESSOR.
  aom_extra+=(-DCONFIG_RUNTIME_CPU_DETECT=1)
fi

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_DOCS=0 \
  -DENABLE_EXAMPLES=0 \
  -DENABLE_TESTS=0 \
  -DENABLE_TOOLS=0 \
  -DENABLE_NASM=1 \
  -DCONFIG_AV1_ENCODER=1 \
  -DCONFIG_AV1_DECODER=1 \
  "${aom_extra[@]}"

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libaom.so.3"
log "done"
