#!/usr/bin/env bash
# libidn2 2.3.7 — autotools. Depends on libunistring (L1).
LIB_NAME="libidn2"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libidn2)"
build="$(prepare_build_dir libidn2)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-gtk-doc \
    --disable-gtk-doc-html \
    --without-libiconv-prefix \
    --without-libintl-prefix

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libidn2.so.0"
log "done"
