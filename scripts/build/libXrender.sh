#!/usr/bin/env bash
# libXrender 0.9.11 — autotools. Depends on libX11 (L4) + xorgproto (L4 headers).
# Upstream uses libtool `-version-number 1:3:0` → SONAME libXrender.so.1.
LIB_NAME="libXrender"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libXrender)"
build="$(prepare_build_dir libXrender)"

extra_aclocal=""
for d in /usr/share/aclocal /usr/local/share/aclocal "${INSTALL_DIR}/share/aclocal"; do
  [[ -d "$d" ]] && extra_aclocal="${extra_aclocal}:${d}"
done
export ACLOCAL_PATH="${extra_aclocal#:}${ACLOCAL_PATH:+:${ACLOCAL_PATH}}"

log "configuring (ACLOCAL_PATH=${ACLOCAL_PATH})"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-specs \
    --without-xmlto \
    --without-fop \
    --without-xsltproc

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libXrender.so.1"
log "done"
