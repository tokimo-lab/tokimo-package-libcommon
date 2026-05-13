#!/usr/bin/env bash
# libtasn1 4.20.0 — autotools.
#
# Linker workaround: pass so binutils 2.41 emits a
# segment layout that patchelf 0.17.2 can later modify without producing
# unaligned LOAD entries. Without this, post_process_install's patchelf pass
# breaks the file (objdump still reports SONAME, but glibc refuses to load
# it: "ELF load command address/offset not properly aligned"), which in turn
# prevents binaries that link libtasn1 (e.g. asn1Parser, used by p11-kit's
# build) from running. Same workaround is applied in all L3+ build scripts.
LIB_NAME="libtasn1"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libtasn1)"
build="$(prepare_build_dir libtasn1)"

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-doc

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libtasn1.so.6"
log "done"
