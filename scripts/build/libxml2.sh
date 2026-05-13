#!/usr/bin/env bash
# libxml2 2.13.5 — autotools. Uses xz/lzma (L0), zlib (L0).
# NOTE: ICU support disabled here. libcommon's icu.sh drops libicui18n.so
# (not in our registry), so linking libxml2 against ICU would fail at link
# time with "cannot find -licui18n". libxml2 only needs ICU for an optional
# encoding code path; we don't ship that codepath.
LIB_NAME="libxml2"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libxml2)"
build="$(prepare_build_dir libxml2)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --without-python \
    --without-readline \
    --without-iconv \
    --without-icu \
    --with-lzma \
    --with-zlib \
    --with-history=no \
    --with-modules=no \
    --with-debug=no

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libxml2.so.2"
log "done"
