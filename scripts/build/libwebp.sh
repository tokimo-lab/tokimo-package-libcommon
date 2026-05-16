#!/usr/bin/env bash
# libwebp 1.4.0 — autotools. Produces libsharpyuv + libwebp + libwebpmux + libwebpdemux.
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
    --enable-libwebpdemux \
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

# Defensive: drop the standalone decoder lib (libwebpdecoder duplicates symbols
# from libwebp.so and we never need it separately).
drop_lib libwebpdecoder
drop_pc libwebpdecoder

log "post-processing"
post_process_install

assert_soname "libsharpyuv.so.0"
assert_soname "libwebp.so.7"
assert_soname "libwebpmux.so.3"
assert_soname "libwebpdemux.so.2"
log "done"
