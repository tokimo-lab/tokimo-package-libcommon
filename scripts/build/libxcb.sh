#!/usr/bin/env bash
# libxcb 1.17.0 — autotools. Needs xcb-proto (codegen, this layer),
# libXau (L0), libXdmcp (L2). Same ACLOCAL_PATH defense as libXau/libXdmcp
# so xorg-macros (XORG_DEFAULT_OPTIONS) is found.
LIB_NAME="libxcb"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool python3

src="$(source_dir libxcb)"
build="$(prepare_build_dir libxcb)"

extra_aclocal=""
for d in /usr/share/aclocal /usr/local/share/aclocal "${INSTALL_DIR}/share/aclocal"; do
  [[ -d "$d" ]] && extra_aclocal="${extra_aclocal}:${d}"
done
export ACLOCAL_PATH="${extra_aclocal#:}${ACLOCAL_PATH:+:${ACLOCAL_PATH}}"

log "configuring (ACLOCAL_PATH=${ACLOCAL_PATH})"
cd "${build}"
PYTHON=python3 \
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS} -Wl,-z,noseparate-code" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-devel-docs \
    --without-doxygen

log "building"
make -j"${NPROC}"

log "installing"
make install

# libxcb ships many extension shims (libxcb-render, libxcb-shm, libxcb-randr,
# libxcb-xfixes, …). Registry currently only tracks libxcb.so.1 as built for
# L3; the *named* extensions (libxcb-render/-shm) are still "planned" and any
# unlisted extension would fail verify.sh. Drop everything except the core
# library — extensions will be re-enabled in a later layer when cairo needs
# them and the registry flips them to built.
shopt -s nullglob
for f in "${INSTALL_DIR}/lib"/libxcb-*.so*; do
  rm -f "${f}"
done
# pkg-config files for the disabled extensions point at missing libs;
# drop them too so downstream configures don't pick up half-installed deps.
for pc in "${INSTALL_DIR}/lib/pkgconfig"/xcb-*.pc; do
  rm -f "${pc}"
done
shopt -u nullglob

log "post-processing"
post_process_install

assert_soname "libxcb.so.1"
log "done"
