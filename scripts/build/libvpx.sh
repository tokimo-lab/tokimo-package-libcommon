#!/usr/bin/env bash
# libvpx 1.14.1 — custom configure. BSD-3-Clause. VP8/VP9 codec.
LIB_NAME="libvpx"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libvpx)"
build="$(prepare_build_dir libvpx)"

vpx_target=""
vpx_extra=()
if is_linux; then
  vpx_target="x86_64-linux-gcc"
elif is_macos; then
  # Apple Silicon native build. libvpx supports arm64-darwin*-gcc.
  vpx_target="arm64-darwin20-gcc"
elif is_windows; then
  vpx_target="x86_64-win64-gcc"
fi

cd "${build}"
log "configuring (target=${vpx_target})"
"${src}/configure" \
  --prefix="${INSTALL_DIR}" \
  --libdir="${INSTALL_DIR}/lib" \
  --target="${vpx_target}" \
  --enable-shared \
  --disable-static \
  --enable-pic \
  --enable-vp8 --enable-vp9 \
  --enable-vp9-highbitdepth \
  --enable-runtime-cpu-detect \
  --enable-postproc \
  --enable-multi-res-encoding \
  --enable-temporal-denoising \
  --enable-vp9-temporal-denoising \
  --disable-examples \
  --disable-tools \
  --disable-docs \
  --disable-unit-tests \
  "${vpx_extra[@]}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libvpx.so.10"
log "done"
