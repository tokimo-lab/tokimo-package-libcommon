#!/usr/bin/env bash
# fftw 3.3.10 — autotools. GPL-2.0-or-later. Double-precision FFT.
#
# libvips uses fftw3 (double precision) at runtime via vips_fwfft1/invfft1.
# We build ONLY the double-precision lib (no --enable-single / --enable-long-double)
# because that's all libvips links against and bundling 3 variants is wasteful.
#
# Produces:
#   Linux:   libfftw3.so.3 (+ libfftw3_threads.so.3 when --enable-threads)
#   macOS:   libfftw3.3.dylib (+ libfftw3_threads.3.dylib)
#   Windows: libfftw3-3.dll (+ libfftw3_threads-3.dll)
LIB_NAME="fftw"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir fftw)"
build="$(prepare_build_dir fftw)"

# fftw's configure auto-detects SSE2/AVX but the released tarball was built
# with autoconf 2.69 macros that emit `-msse2 -mavx` unconditionally on
# x86_64 — fine for our manylinux_2_28 + macos-14 + msys2 targets.

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-fortran \
    --disable-doc \
    --enable-threads \
    --with-our-malloc

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libfftw3.so.3"
log "done"
