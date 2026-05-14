#!/usr/bin/env bash
# libvorbis 1.3.7 — autotools. BSD-3-Clause. Vorbis audio codec.
# Depends on libogg (Wave A).
LIB_NAME="libvorbis"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libvorbis)"
build="$(prepare_build_dir libvorbis)"

# libvorbis 1.3.7's configure injects the obsolete `-force_cpusubtype_ALL`
# ld flag on darwin. Apple's modern ld (Xcode 15+) errors out with
# `unknown options: -force_cpusubtype_ALL`. Strip it from the configure
# script before running it. (Pre-generated configure script in the
# release tarball, so we sed configure directly — no autoreconf needed.)
if is_macos && grep -q 'force_cpusubtype_ALL' "${src}/configure"; then
  log "patching configure: drop obsolete -force_cpusubtype_ALL ld flag (darwin)"
  sed -i.bak 's/-force_cpusubtype_ALL//g' "${src}/configure"
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-docs \
    --disable-examples

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libvorbis.so.0"
assert_soname "libvorbisenc.so.2"
log "done"
