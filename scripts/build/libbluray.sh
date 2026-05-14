#!/usr/bin/env bash
# libbluray 1.3.4 — autotools. LGPL-2.1-or-later. Blu-ray disc playback API.
# We disable BDJ (Blu-ray Java) entirely so we don't need a JDK at build
# time. Depends on base libxml2 + freetype + fontconfig.
LIB_NAME="libbluray"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libbluray)"
build="$(prepare_build_dir libbluray)"

# Gitlab archive ships without autotools artifacts — regenerate.
if [[ ! -f "${src}/configure" ]] || [[ ! -f "${src}/.libcommon-autoreconf-done" ]]; then
  log "running autoreconf -fi"
  (cd "${src}" && autoreconf -fi)
  touch "${src}/.libcommon-autoreconf-done"
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-bdjava-jar \
    --disable-doxygen-doc \
    --disable-examples \
    --without-libxml2 \
    --without-freetype \
    --without-fontconfig

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libbluray.so.2"
log "done"
