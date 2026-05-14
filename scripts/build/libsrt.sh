#!/usr/bin/env bash
# libsrt 1.5.4 — cmake. MPL-2.0. Secure Reliable Transport (UDP-based).
# Depends on gnutls (Wave 0 base layer). We pick the gnutls crypto backend
# rather than openssl since libcommon ships gnutls but not openssl.
LIB_NAME="libsrt"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

need_tool cmake

src="$(source_dir libsrt)"
build="$(prepare_build_dir libsrt)"

log "configuring (cmake, USE_ENCLIB=gnutls)"
cd "${build}"
cmake "${src}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_SHARED=ON \
  -DENABLE_STATIC=OFF \
  -DENABLE_APPS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_TESTING=OFF \
  -DUSE_ENCLIB=gnutls

log "building"
cmake --build . -- -j"${NPROC}"

log "installing"
cmake --install .

log "post-processing"
post_process_install

assert_soname "libsrt.so.1.5"
log "done"
