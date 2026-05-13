#!/usr/bin/env bash
# fontconfig 2.15.0 — autotools. Needs expat (L0), freetype (L2).
LIB_NAME="fontconfig"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir fontconfig)"
build="$(prepare_build_dir fontconfig)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS} -Wl,-z,noseparate-code" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-docs \
    --disable-cache-build

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libfontconfig.so.1"
log "done"
