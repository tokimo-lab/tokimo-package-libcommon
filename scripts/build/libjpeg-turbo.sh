#!/usr/bin/env bash
# libjpeg-turbo 3.0.4 — cmake. Provides libjpeg.so.62 (IJG 6.2 API).
LIB_NAME="libjpeg-turbo"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir libjpeg-turbo)"
build="$(prepare_build_dir libjpeg-turbo)"

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=ON \
  -DENABLE_STATIC=OFF \
  -DWITH_TURBOJPEG=OFF \
  -DWITH_JAVA=OFF

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

if is_windows; then
  WINDOWS_DLL_OVERRIDE="libjpeg-62.dll" assert_soname "libjpeg.so.62"
else
  assert_soname "libjpeg.so.62"
fi
log "done"
