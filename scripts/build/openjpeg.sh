#!/usr/bin/env bash
# openjpeg 2.5.2 — cmake.
LIB_NAME="openjpeg"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir openjpeg)"
build="$(prepare_build_dir openjpeg)"

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DBUILD_CODEC=OFF \
  -DBUILD_DOC=OFF \
  -DBUILD_TESTING=OFF

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libopenjp2.so.7"
log "done"
