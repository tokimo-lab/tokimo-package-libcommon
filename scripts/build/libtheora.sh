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
#
# Two known bugs in the 1.1.1 release that we patch before autoreconf:
#   1. configure.ac uses AS_AC_EXPAND (defined inline in aclocal.m4) but
#      modern autoconf 2.71+ treats AS_* as a forbidden pattern and aborts
#      with "undefined or overquoted macro". Whitelist it explicitly.
#   2. lib/Makefile.am puts info.c (which defines th_comment_*) only in
#      decoder_sources. apiwrapper.c calls those symbols, so libtheoraenc
#      ends up with unresolved references. ELF linkers tolerate this; ld64
#      (macOS) rejects it. Add info.c to encoder_sources so the encoder
#      shared lib is self-contained on every platform.
if [[ ! -f "${src}/.libcommon-autoreconf-done" ]]; then
  if ! grep -q 'm4_pattern_allow.*AS_AC_EXPAND' "${src}/configure.ac"; then
    log "patching configure.ac: whitelist AS_AC_EXPAND macro"
    sed -i.bak '1i m4_pattern_allow([AS_AC_EXPAND])' "${src}/configure.ac"
  fi
  if ! grep -q '^encoder_sources = info.c' "${src}/lib/Makefile.am"; then
    log "patching lib/Makefile.am: add info.c to encoder_sources"
    sed -i.bak2 's|^encoder_sources = \\$|encoder_sources = info.c \\|' "${src}/lib/Makefile.am"
  fi
  if command -v autoreconf >/dev/null 2>&1; then
    log "autoreconf -fi -I m4"
    (cd "${src}" && autoreconf -fi -I m4)
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
# On mingw, libtheora 1.1.1 builds a combined libtheora-0.dll (decoder+encoder)
# and a decoder-only libtheoradec-1.dll, but no standalone libtheoraenc-1.dll.
# Map the encoder SONAME to the combined DLL.
if is_windows; then
  WINDOWS_DLL_OVERRIDE="libtheora-0.dll" assert_soname "libtheoraenc.so.1"
else
  assert_soname "libtheoraenc.so.1"
fi
log "done"
