#!/usr/bin/env bash
# libtiff 4.7.0 — cmake. Provides libtiff.so.6.
LIB_NAME="libtiff"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir libtiff)"
build="$(prepare_build_dir libtiff)"

log "configuring (cmake)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -Dtiff-tools=OFF \
  -Dtiff-tests=OFF \
  -Dtiff-contrib=OFF \
  -Dtiff-docs=OFF \
  -Dcxx=OFF \
  -Dlzma=ON \
  -Dzstd=ON \
  -Dwebp=ON \
  -Dlerc=OFF \
  -Djbig=OFF \
  -Dlibdeflate=OFF \
  -Djpeg12=OFF \
  -Dold-jpeg=OFF

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

if is_windows; then
  WINDOWS_DLL_OVERRIDE="libtiff.dll" assert_soname "libtiff.so.6"
else
  assert_soname "libtiff.so.6"
fi
log "done"
