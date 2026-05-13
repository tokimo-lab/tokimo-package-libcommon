#!/usr/bin/env bash
# libbsd 0.12.2 — autotools. Depends on libmd.
LIB_NAME="libbsd"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_macos; then
  log "libbsd not built on macOS (BSD APIs in libSystem; libX11 uses native arc4random_buf)"
  exit 0
fi

if is_windows; then
  log "libbsd not built on Windows (consumers libX11/libxcb skipped on Windows)"
  exit 0
fi

src="$(source_dir libbsd)"
build="$(prepare_build_dir libbsd)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libbsd.so.0"
log "done"
