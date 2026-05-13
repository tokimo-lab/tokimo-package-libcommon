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
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
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
# libxcb-xfixes, …). L4 promotes libxcb-render.so.0 and libxcb-shm.so.0 to
# "built" (cairo at L6 needs them); every other extension is still "planned"
# in registry.toml and verify.sh would reject any that ship. Keep render+shm,
# delete the rest.
shopt -s nullglob
KEEP_RE='libxcb-(render|shm)\.'
for f in "${INSTALL_DIR}/lib"/libxcb-*.so* \
         "${INSTALL_DIR}/lib"/libxcb-*.dylib; do
  base="$(basename "${f}")"
  if [[ "${base}" =~ ${KEEP_RE} ]]; then
    continue
  fi
  rm -f "${f}"
done
# pkg-config files: keep xcb-render.pc and xcb-shm.pc, drop the rest so
# downstream configures don't pick up half-installed deps.
for pc in "${INSTALL_DIR}/lib/pkgconfig"/xcb-*.pc; do
  base="$(basename "${pc}")"
  case "${base}" in
    xcb-render.pc|xcb-shm.pc) continue ;;
    *) rm -f "${pc}" ;;
  esac
done
shopt -u nullglob

log "post-processing"
post_process_install

assert_soname "libxcb.so.1"
assert_soname "libxcb-render.so.0"
assert_soname "libxcb-shm.so.0"
log "done"
