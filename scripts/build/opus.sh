#!/usr/bin/env bash
# opus 1.5.2 — autotools. BSD-3-Clause. RFC 6716 audio codec. No internal deps.
LIB_NAME="opus"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir opus)"
build="$(prepare_build_dir opus)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-extra-programs

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libopus.so.0"
log "done"
