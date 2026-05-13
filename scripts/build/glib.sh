#!/usr/bin/env bash
# glib 2.80.5 — meson. Produces five SONAMEs:
#   libglib-2.0.so.0, libgobject-2.0.so.0, libgmodule-2.0.so.0,
#   libgthread-2.0.so.0, libgio-2.0.so.0
# Deps from earlier layers: pcre2 (L0), libffi (L0), zlib (L0).
LIB_NAME="glib"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir glib)"
build="$(prepare_build_dir glib)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dintrospection=disabled \
    -Dman-pages=disabled \
    -Dgtk_doc=false \
    -Dtests=false \
    -Dnls=disabled \
    -Dlibmount=disabled \
    -Dselinux=disabled \
    -Dxattr=false \
    -Dsysprof=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

# Drop installed CLI tools (not part of our shipped runtime).
rm -rf "${INSTALL_DIR}/bin/glib-"* \
       "${INSTALL_DIR}/bin/gio"* \
       "${INSTALL_DIR}/bin/gobject-"* \
       "${INSTALL_DIR}/bin/gdbus"* \
       "${INSTALL_DIR}/bin/gsettings"* \
       "${INSTALL_DIR}/bin/gresource"* \
       "${INSTALL_DIR}/share/glib-2.0/codegen" 2>/dev/null || true

# glib 2.80 unconditionally ships libgirepository-2.0 (split out from the
# gobject-introspection project upstream). It is NOT in libcommon's registry
# and would fail verify.sh. Drop the library + its pkg-config + headers.
rm -f "${INSTALL_DIR}/lib"/libgirepository-2.0.so* 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib"/libgirepository-2.0.* 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib/pkgconfig/girepository-2.0.pc" 2>/dev/null || true
rm -rf "${INSTALL_DIR}/include/girepository-2.0" 2>/dev/null || true

log "post-processing"
post_process_install

assert_soname "libglib-2.0.so.0"
assert_soname "libgobject-2.0.so.0"
assert_soname "libgmodule-2.0.so.0"
assert_soname "libgthread-2.0.so.0"
assert_soname "libgio-2.0.so.0"
log "done"
