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
# cairo's util/cairo-script-interpreter unconditionally requires lzo
# headers. On macOS the only available lzo is brew's, whose pkg-config
# advertises a broken include path (".../include/lzo") so the build
# fails on `#include <lzo/lzo2a.h>`. We don't ship the script
# interpreter anyway (drop_lib below), so strip its subdir before
# meson sees it.
if is_macos; then
  util_meson="${src}/util/meson.build"
  if grep -q "cairo-script" "${util_meson}"; then
    sed -i.bak "/cairo-script/d" "${util_meson}"
  fi
fi

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
drop_lib libcairo-script-interpreter
drop_lib libcairo-gobject
drop_pc cairo-script-interpreter
drop_pc cairo-gobject

log "post-processing"
post_process_install

assert_soname "libcairo.so.2"
log "done"
