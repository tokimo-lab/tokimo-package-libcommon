#!/usr/bin/env bash
# nettle 3.10 — autotools. Depends on gmp (must build after gmp in deps.toml).
# Produces libnettle.so.8 + libhogweed.so.6 (hogweed is the GMP-linked half).
LIB_NAME="nettle"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  # nettle 3.10's bundled getopt.c uses K&R-style declarations that
  # C23 (gcc 16 default) rejects. msys2 ships mingw-w64-x86_64-nettle
  # built with their patched toolchain — copy DLL + import lib + headers
  # + pkg-config, same pattern as gmp.sh.
  prefix="${MSYSTEM_PREFIX:-/mingw64}"
  mkdir -p "${INSTALL_DIR}/bin" "${INSTALL_DIR}/lib" \
           "${INSTALL_DIR}/include/nettle" "${INSTALL_DIR}/lib/pkgconfig"
  for dll in libnettle-8.dll libhogweed-6.dll; do
    src="${prefix}/bin/${dll}"
    [[ -f "${src}" ]] || fatal "${src} not found (mingw-w64-x86_64-nettle?)"
    cp -f "${src}" "${INSTALL_DIR}/bin/${dll}"
    chmod 0755 "${INSTALL_DIR}/bin/${dll}"
  done
  for imp in libnettle.dll.a libhogweed.dll.a; do
    if [[ -f "${prefix}/lib/${imp}" ]]; then
      cp -f "${prefix}/lib/${imp}" "${INSTALL_DIR}/lib/${imp}"
    fi
  done
  if [[ -d "${prefix}/include/nettle" ]]; then
    cp -rf "${prefix}/include/nettle/." "${INSTALL_DIR}/include/nettle/"
  fi
  for pc in nettle hogweed; do
    if [[ -f "${prefix}/lib/pkgconfig/${pc}.pc" ]]; then
      sed -e "s|^prefix=.*|prefix=${INSTALL_DIR}|" \
          -e "s|^exec_prefix=.*|exec_prefix=${INSTALL_DIR}|" \
          "${prefix}/lib/pkgconfig/${pc}.pc" \
          > "${INSTALL_DIR}/lib/pkgconfig/${pc}.pc"
    fi
  done
  log "shipped mingw-w64 prebuilt nettle"
  WINDOWS_DLL_OVERRIDE="libnettle-8.dll" assert_soname "libnettle.so.8"
  WINDOWS_DLL_OVERRIDE="libhogweed-6.dll" assert_soname "libhogweed.so.6"
  log "done"
  exit 0
fi

src="$(source_dir nettle)"
build="$(prepare_build_dir nettle)"

log "configuring"
cd "${build}"
# nettle's configure picks up GMP from CPPFLAGS/LDFLAGS (already pointing at
# ${INSTALL_DIR}). Make sure --with-include-path/--with-lib-path see it too.
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-documentation \
    --disable-openssl \
    --with-include-path="${INSTALL_DIR}/include" \
    --with-lib-path="${INSTALL_DIR}/lib"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libnettle.so.8"
assert_soname "libhogweed.so.6"
log "done"
