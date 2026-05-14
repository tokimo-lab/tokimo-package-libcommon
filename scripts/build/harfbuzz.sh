#!/usr/bin/env bash
# harfbuzz 9.0.0 — meson. Needs freetype (L2), glib (L1), icu (L0),
# graphite2 (L2). Cairo deliberately disabled (cairo is L6, would create a
# build cycle). Produces libharfbuzz.so.0.
LIB_NAME="harfbuzz"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir harfbuzz)"
build="$(prepare_build_dir harfbuzz)"

log "configuring (meson)"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    -Dintrospection=disabled \
    -Ddocs=disabled \
    -Dtests=disabled \
    -Dbenchmark=disabled \
    -Dicu_builtin=false \
    -Dcoretext=disabled \
    -Dfreetype=enabled \
    -Dglib=enabled \
    -Dicu=enabled \
    -Dgraphite2=enabled \
    -Dcairo=disabled

log "building"
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

# harfbuzz ships several siblings (libharfbuzz-subset.so.0, libharfbuzz-icu.so.0,
# libharfbuzz-gobject.so.0) depending on options. Registry only tracks
# libharfbuzz.so.0 — drop the rest so verify.sh stays happy.
shopt -s nullglob
for f in "${INSTALL_DIR}/lib"/libharfbuzz-*.so* \
         "${INSTALL_DIR}/lib"/libharfbuzz-*.dylib \
         "${INSTALL_DIR}/bin"/libharfbuzz-*-*.dll \
         "${INSTALL_DIR}/lib"/libharfbuzz-*.dll.a; do
  rm -f "${f}"
done
for pc in "${INSTALL_DIR}/lib/pkgconfig"/harfbuzz-*.pc; do rm -f "${pc}"; done
shopt -u nullglob

log "post-processing"
post_process_install

assert_soname "libharfbuzz.so.0"
log "done"
