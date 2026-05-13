#!/usr/bin/env bash
# pcre2 10.44 — autotools, 8-bit variant only (glib's default).
LIB_NAME="pcre2"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir pcre2)"
build="$(prepare_build_dir pcre2)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-pcre2-8 \
    --disable-pcre2-16 \
    --disable-pcre2-32 \
    --enable-shared \
    --disable-static

log "building"
make -j"${NPROC}"

log "installing"
make install

# pcre2 always builds the POSIX wrapper libpcre2-posix when --enable-pcre2-8
# is set. It's not in libcommon registry — drop it.
drop_lib libpcre2-posix
drop_pc libpcre2-posix

log "post-processing"
post_process_install

assert_soname "libpcre2-8.so.0"
log "done"
