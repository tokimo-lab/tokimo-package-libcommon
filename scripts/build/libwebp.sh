#!/usr/bin/env bash
# libwebp 1.4.0 — autotools. Produces libsharpyuv + libwebp + libwebpmux.
# We do NOT ship libwebpdemux / libwebpdecoder (libvips territory).
LIB_NAME="libwebp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libwebp)"
build="$(prepare_build_dir libwebp)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --enable-libwebpmux \
    --disable-libwebpdemux \
    --disable-libwebpdecoder \
    --disable-libwebpextras \
    --disable-gl \
    --disable-sdl \
    --disable-png \
    --disable-jpeg \
    --disable-tiff \
    --disable-gif

log "building"
make -j"${NPROC}"

log "installing"
make install

# Defensive: drop any decoder/demux that slipped through despite configure flags.
rm -f "${INSTALL_DIR}/lib"/libwebpdemux.so* 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib"/libwebpdecoder.so* 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib/pkgconfig/libwebpdemux.pc" 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib/pkgconfig/libwebpdecoder.pc" 2>/dev/null || true

log "post-processing"
post_process_install

assert_soname "libsharpyuv.so.0"
assert_soname "libwebp.so.7"
assert_soname "libwebpmux.so.3"
log "done"
