#!/usr/bin/env bash
# p11-kit 0.25.5 — meson. Needs libffi (L0), libtasn1 (L0).
# Produces libp11-kit.so.0. p11-kit-proxy is installed under lib/pkcs11/ as a
# PKCS#11 module (not a normal SONAME) and so does not trigger verify.sh.
LIB_NAME="p11-kit"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool meson
need_tool ninja

src="$(source_dir p11-kit)"
build="$(prepare_build_dir p11-kit)"

# p11-kit's build invokes ${INSTALL_DIR}/bin/asn1Parser (from libtasn1, L0)
# at compile time to codegen ASN.1 headers. asn1Parser dlopens libtasn1.so.6
# from ${INSTALL_DIR}/lib, but patchelf 0.17.2 (the version pinned in the
# manylinux_2_28 dev image) corrupts ELF load alignment after ~2 idempotent
# rebuild passes. Each successful L3 build above (libxcb, fontconfig) has
# already run post_process_install which re-patchelfs every .so in
# install/lib — by the time we get here, libtasn1.so.6 is no longer
# loadable. Rebuild libtasn1 fresh so its single subsequent patchelf pass
# (during our own post_process_install) lands in the still-loadable
# iter-1 state.
log "refreshing libtasn1 (patchelf 0.17.2 idempotency workaround)"
bash "$(dirname "${BASH_SOURCE[0]}")/libtasn1.sh"

log "configuring (meson)"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS} -Wl,-z,noseparate-code" \
  meson setup "${build}" "${src}" \
    --prefix="${INSTALL_DIR}" \
    --libdir=lib \
    --buildtype=release \
    -Dman=false \
    -Dgtk_doc=false \
    -Dnls=false \
    -Dtrust_paths=/etc/pki/tls/certs/ca-bundle.crt \
    -Dsystemd=disabled \
    -Dbash_completion=disabled

log "building"
# asn1Parser RUNPATH normalization: post_process_install only touches files
# in install/lib (not install/bin), so the binary's RUNPATH is still the
# absolute build-host path baked in by libtasn1.sh — fine inside this
# container, but make it relocatable for robustness.
if [[ -x "${INSTALL_DIR}/bin/asn1Parser" ]] && command -v patchelf >/dev/null 2>&1; then
  patchelf --remove-rpath "${INSTALL_DIR}/bin/asn1Parser" 2>/dev/null || true
  patchelf --set-rpath '$ORIGIN/../lib' "${INSTALL_DIR}/bin/asn1Parser" \
    || log "warn: failed to patch asn1Parser RUNPATH"
fi
meson compile -C "${build}" -j "${NPROC}"

log "installing"
meson install -C "${build}"

log "post-processing"
post_process_install

assert_soname "libp11-kit.so.0"
log "done"
