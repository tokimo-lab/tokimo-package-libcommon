#!/usr/bin/env bash
# gmp 6.3.0 — autotools, no C++ bindings.
LIB_NAME="gmp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  # GMP 6.3.0's configure runs a "long long reliability test" that
  # miscompiles under gcc 16 (current msys2 toolchain), so source-build
  # is non-viable here. msys2 ships a patched mingw-w64-x86_64-gmp
  # package built against the exact same runtime — copy that DLL.
  prefix="${MSYSTEM_PREFIX:-/mingw64}"
  src="${prefix}/bin/libgmp-10.dll"
  [[ -f "${src}" ]] || fatal "${src} not found (mingw-w64-x86_64-gmp not installed?)"
  log "shipping mingw-w64 prebuilt: ${src}"
  bindir="${INSTALL_DIR}/bin"
  mkdir -p "${bindir}"
  cp -f "${src}" "${bindir}/libgmp-10.dll"
  chmod 0755 "${bindir}/libgmp-10.dll"
  # Also copy headers + import library so downstream libs (nettle, gnutls,
  # p11-kit) can link against it.
  if [[ -f "${prefix}/include/gmp.h" ]]; then
    mkdir -p "${INSTALL_DIR}/include"
    cp -f "${prefix}/include/gmp.h" "${INSTALL_DIR}/include/gmp.h"
  fi
  if [[ -f "${prefix}/lib/libgmp.dll.a" ]]; then
    mkdir -p "${INSTALL_DIR}/lib"
    cp -f "${prefix}/lib/libgmp.dll.a" "${INSTALL_DIR}/lib/libgmp.dll.a"
  fi
  WINDOWS_DLL_OVERRIDE="libgmp-10.dll" assert_soname "libgmp.so.10"
  log "done"
  exit 0
fi

src="$(source_dir gmp)"
build="$(prepare_build_dir gmp)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --enable-cxx=no

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libgmp.so.10"
log "done"
