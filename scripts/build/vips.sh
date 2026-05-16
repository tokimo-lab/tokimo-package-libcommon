#!/usr/bin/env bash
# libvips 8.18.2 — meson. LGPL-2.1-or-later. Image processing library.
#
# Mandatory deps (from libcommon base 49 + L12):
#   glib-2.0, gobject-2.0, gio-2.0, gmodule-2.0  (base)
#   expat                                         (base)
#   libjpeg-turbo, libpng, libwebp, libtiff       (base)
#   lcms2                                         (base)
#   fftw3                                         (L12 new)
#   orc-0.4                                       (L12 new)
#
# Optional format deps disabled for v1.2.0 (not in libcommon yet — would
# need a separate wave each):
#   heif, rsvg, cgif, exif, imagequant, jpeg-xl, magick, matio, nifti,
#   openexr, openslide, pdfium, poppler, raw, spng, highway, quantizr,
#   uhdr, archive, cfitsio
#
# Optional deps we DO enable (already in libcommon base 49):
#   zlib, openjpeg, fontconfig/freetype/pango/cairo → pangocairo
#
# Produces:
#   Linux:   libvips.so.42, libvips-cpp.so.42
#   macOS:   libvips.42.dylib, libvips-cpp.42.dylib
#   Windows: libvips-42.dll, libvips-cpp-42.dll
LIB_NAME="vips"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir vips)"
build="$(prepare_build_dir vips)"

# Make sure pkg-config + linker find every libcommon-provided dep.
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
if is_windows; then
  export PKG_CONFIG_LIBDIR="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/share/pkgconfig"
fi

log "configuring (meson)"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dintrospection=disabled \
    -Dexamples=false \
    -Ddeprecated=false \
    -Dmodules=disabled \
    -Dcpp-docs=false \
    -Ddocs=false \
    -Dvapi=false \
    -Dcplusplus=true \
    -Dfftw=enabled \
    -Dlcms=enabled \
    -Dorc=enabled \
    -Djpeg=enabled \
    -Dpng=enabled \
    -Dwebp=enabled \
    -Dtiff=enabled \
    -Dzlib=enabled \
    -Dopenjpeg=enabled \
    -Dpangocairo=disabled \
    -Dfontconfig=disabled \
    -Dheif=disabled \
    -Drsvg=disabled \
    -Dcgif=disabled \
    -Dexif=disabled \
    -Dimagequant=disabled \
    -Djpeg-xl=disabled \
    -Dmagick=disabled \
    -Dmatio=disabled \
    -Dnifti=disabled \
    -Dopenexr=disabled \
    -Dopenslide=disabled \
    -Dpdfium=disabled \
    -Dpoppler=disabled \
    -Dquantizr=disabled \
    -Draw=disabled \
    -Dspng=disabled \
    -Dhighway=disabled \
    -Duhdr=disabled \
    -Darchive=disabled \
    -Dcfitsio=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "post-processing"
post_process_install

if is_windows; then
  WINDOWS_DLL_OVERRIDE="libvips-42.dll"     assert_soname "libvips.so.42"
  WINDOWS_DLL_OVERRIDE="libvips-cpp-42.dll" assert_soname "libvips-cpp.so.42"
else
  assert_soname "libvips.so.42"
  assert_soname "libvips-cpp.so.42"
fi
log "done"
