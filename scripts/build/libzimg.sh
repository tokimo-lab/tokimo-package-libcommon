#!/usr/bin/env bash
# libzimg release-3.0.5 — autotools. WTFPL. Z.lib zimg (scale/colorspace/depth).
LIB_NAME="libzimg"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libzimg)"
build="$(prepare_build_dir libzimg)"

# zimg ships autoreconf-generated configure as `./autogen.sh`. We always
# regenerate to pick the platform's modern config.guess.
if [[ ! -f "${src}/configure" ]] || [[ ! -f "${src}/.libcommon-autogen-done" ]]; then
  log "running autogen.sh"
  (cd "${src}" && bash autogen.sh)
  touch "${src}/.libcommon-autogen-done"
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libzimg.so.2"
log "done"
