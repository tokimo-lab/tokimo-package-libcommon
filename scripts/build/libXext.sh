#!/usr/bin/env bash
# libXext 1.3.6 — autotools. Depends on libX11 (L4) + xorgproto (L4 headers).
# Produces libXext.so.6.
LIB_NAME="libXext"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  log "skipping on Windows (X11 family not supported)"
  exit 0
fi

src="$(source_dir libXext)"
build="$(prepare_build_dir libXext)"

# xorg-macros aclocal path (same trick as libX11).
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
    --disable-malloc0returnsnull \
    --without-xmlto \
    --without-fop \
    --without-xsltproc

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libXext.so.6"
log "done"
