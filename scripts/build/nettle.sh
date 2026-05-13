#!/usr/bin/env bash
# nettle 3.10 — autotools. Depends on gmp (must build after gmp in deps.toml).
# Produces libnettle.so.8 + libhogweed.so.6 (hogweed is the GMP-linked half).
LIB_NAME="nettle"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

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
