#!/usr/bin/env bash
# cairo 1.18.2 — meson. Full 2D rendering stack:
#   pixman (L0), freetype (L2), fontconfig (L3), libpng (L1), zlib (L0),
#   libX11 (L4), libXext (L5), libXrender (L5),
#   libxcb (L3) + libxcb-render (L4) + libxcb-shm (L4).
# Produces libcairo.so.2. The sibling libcairo-script-interpreter.so.2 and
# libcairo-gobject (only built if glib bindings enabled) are not in
# registry.toml and are dropped post-install.
LIB_NAME="cairo"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir cairo)"
build="$(prepare_build_dir cairo)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dtests=disabled \
    -Dspectre=disabled \
    -Dgtk_doc=false \
    -Dfreetype=enabled \
    -Dfontconfig=enabled \
    -Dpng=enabled \
    -Dxlib=enabled \
    -Dxcb=enabled \
    -Dquartz=disabled \
    -Dsymbol-lookup=disabled \
    -Dglib=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

# Drop sibling libs not tracked in registry.
shopt -s nullglob
for f in "${INSTALL_DIR}/lib"/libcairo-script-interpreter.so*; do rm -f "${f}"; done
for f in "${INSTALL_DIR}/lib"/libcairo-gobject.so*; do rm -f "${f}"; done
rm -f "${INSTALL_DIR}/lib/pkgconfig/cairo-script-interpreter.pc"
rm -f "${INSTALL_DIR}/lib/pkgconfig/cairo-gobject.pc"
shopt -u nullglob

log "post-processing"
post_process_install

assert_soname "libcairo.so.2"
log "done"
