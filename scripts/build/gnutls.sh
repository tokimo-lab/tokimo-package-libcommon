#!/usr/bin/env bash
# gnutls 3.8.6 — autotools. Needs nettle (L0), gmp (L0), libtasn1 (L0),
# libunistring (L1), libidn2 (L2), p11-kit (L3). Produces libgnutls.so.30.
LIB_NAME="gnutls"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir gnutls)"
build="$(prepare_build_dir gnutls)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-tests \
    --disable-tools \
    --disable-guile \
    --disable-gtk-doc \
    --disable-full-test-suite \
    --with-included-libtasn1=no \
    --with-included-unistring=no \
    --with-p11-kit \
    --with-libidn2 \
    --without-tpm \
    --without-tpm2 \
    --with-default-trust-store-file=/etc/pki/tls/certs/ca-bundle.crt

log "building"
make -j"${NPROC}"

log "installing"
make install

# gnutls also ships libgnutls-dane.so.0, libgnutlsxx.so.30 depending on flags.
# Registry tracks libgnutls.so.30 only — drop siblings so verify.sh passes.
drop_lib libgnutls-dane
drop_lib libgnutlsxx
drop_pc gnutls-dane
drop_pc gnutlsxx

log "post-processing"
post_process_install

assert_soname "libgnutls.so.30"
log "done"
