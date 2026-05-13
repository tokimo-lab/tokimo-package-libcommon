#!/usr/bin/env bash
# zlib 1.3.1 — classic configure (custom, not autoconf)
LIB_NAME="zlib"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir zlib)"
build="$(prepare_build_dir zlib)"

log "configuring (out-of-tree)"
cd "${build}"
# zlib's configure must be run from the build dir AGAINST the src dir.
# It supports out-of-tree by SRCDIR env override only since 1.3+.
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --shared

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libz.so.1"
log "done"
