#!/usr/bin/env bash
# libX11 1.8.10 — autotools. Needs xtrans (L4 headers), xorgproto (L4 headers),
# libxcb (L3, with render+shm shipped). Produces libX11.so.6 (+ XCB transport
# helper libX11-xcb.so.1 — not in registry, so we drop it post-install).
LIB_NAME="libX11"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libX11)"
build="$(prepare_build_dir libX11)"

# xorg-macros ships its aclocal .m4 under ${INSTALL_DIR}/share/aclocal —
# make sure libX11's autoconf can find XORG_DEFAULT_OPTIONS et al.
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

# Registry tracks libX11.so.6 only. libX11-xcb.so.1 is an optional XCB-bridge
# helper not (yet) listed in registry.toml — drop it and its .pc so verify.sh
# doesn't flag an unregistered SONAME.
drop_lib libX11-xcb
drop_pc x11-xcb

log "post-processing"
post_process_install

assert_soname "libX11.so.6"
log "done"
