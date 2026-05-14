#!/usr/bin/env bash
# libtheora 1.1.1 — autotools. BSD-3-Clause. Theora video codec.
# Depends on libogg (Wave A).
LIB_NAME="libtheora"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libtheora)"
build="$(prepare_build_dir libtheora)"

# 1.1.1 ships an autoconf cache file that doesn't recognise newer compilers
# for the html docs path; just disable docs+examples.

theora_extra=()
if is_macos; then
  # Disable Altivec/SSE asm autodetect: ld64 chokes on the gas-syntax .S
  # files when no x86 assembler is present.
  theora_extra+=(--disable-asm)
fi
# libtheora 1.1.1 was released before autoconf 2.70 mandated `AC_CONFIG_MACRO_DIRS`;
# on Apple toolchains (clang 15+) the bundled config.guess is also too old
# to recognise arm64-apple-darwin*. Refresh autotools where possible.
if [[ ! -f "${src}/.libcommon-autoreconf-done" ]]; then
  if command -v autoreconf >/dev/null 2>&1; then
    log "autoreconf -fi (1.1.1 pre-2.70 config.guess too old for arm64-darwin)"
    (cd "${src}" && autoreconf -fi) || log "warn: autoreconf failed; using shipped scripts"
    touch "${src}/.libcommon-autoreconf-done"
  fi
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-examples \
    --disable-spec \
    "${theora_extra[@]}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libtheoradec.so.1"
assert_soname "libtheoraenc.so.1"
log "done"
