#!/usr/bin/env bash
# soxr 0.1.3 — cmake. LGPL-2.1-or-later. SoX Resampler library. No deps.
#
# We don't need lsr (libsamplerate ABI shim), tests, examples, or OpenMP
# threading (ffmpeg drives its own threading).
LIB_NAME="soxr"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir soxr)"
build="$(prepare_build_dir soxr)"

# soxr's SIMD32/SIMD64 variants assume x86 SSE intrinsics; on Apple Silicon
# the macros compile but reference functions that are never defined,
# yielding link-time undefined symbols (__soxr_ordered_convolve_simd32 etc).
# Disable the SIMD variant resamplers — soxr falls back to scalar paths
# which still produce a valid libsoxr.0 ABI. ffmpeg consumers don't depend
# on these.
soxr_simd_flags=()
if [[ "${PLATFORM:-}" == "macos-arm64" ]] || [[ "$(uname -s)" == "Darwin" ]]; then
  soxr_simd_flags=(-DWITH_CR32S=NO -DWITH_CR64S=NO -DWITH_VR32S=NO)
fi

# soxr 0.1.3 ships pre-C99 code (implicit declarations of UNINTERLEAVE2 /
# INTERLEAVE2 macros in util-simd.c paths). clang 16+ promoted
# -Wimplicit-function-declaration from warning to error by default, so the
# Apple toolchain hard-fails. The actual symbol resolution is fine at link
# time — these are SIMD helper macros expanded conditionally. Downgrade to
# warning so the build succeeds; behaviour is unchanged.
soxr_cflags="${CFLAGS} -Wno-error=implicit-function-declaration -Wno-implicit-function-declaration"

log "configuring (cmake)"
cd "${build}"
CFLAGS="${soxr_cflags}" cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_C_FLAGS="${soxr_cflags}" \
  "${soxr_simd_flags[@]}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DWITH_LSR_BINDINGS=OFF \
  -DWITH_OPENMP=OFF

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libsoxr.so.0"
log "done"
