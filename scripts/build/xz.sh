#!/usr/bin/env bash
# xz 5.6.3 — autotools. Produces liblzma.so.5.
# Avoid 5.6.0 / 5.6.1 (CVE-2024-3094 backdoor). 5.6.2+ is clean.
LIB_NAME="xz"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir xz)"
build="$(prepare_build_dir xz)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --disable-static \
    --enable-shared \
    --disable-doc \
    --disable-nls \
    --disable-xz \
    --disable-xzdec \
    --disable-lzmadec \
    --disable-lzmainfo \
    --disable-lzma-links \
    --disable-scripts

log "building"
make -j"${NPROC}"

log "installing"
make install

# Drop installed binaries and docs we explicitly didn't want.
rm -rf "${INSTALL_DIR}/bin/xz"* "${INSTALL_DIR}/bin/lzma"* "${INSTALL_DIR}/share/doc/xz" 2>/dev/null || true

log "post-processing"
post_process_install

assert_soname "liblzma.so.5"
log "done"
