#!/usr/bin/env bash
# freetype 2.13.3 — autotools. Depends on zlib (L0), libpng (L1), brotli (L0).
# harfbuzz disabled here (harfbuzz lives in L4 and depends on freetype).
LIB_NAME="freetype"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir freetype)"
build="$(prepare_build_dir freetype)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --with-zlib=yes \
    --with-bzip2=no \
    --with-png=yes \
    --with-brotli=yes \
    --with-harfbuzz=no

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libfreetype.so.6"
log "done"
