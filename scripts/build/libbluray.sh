#!/usr/bin/env bash
# libbluray 1.3.4 — autotools. LGPL-2.1-or-later. Blu-ray disc playback API.
# We disable BDJ (Blu-ray Java) entirely so we don't need a JDK at build
# time. Depends on base libxml2 + freetype + fontconfig.
LIB_NAME="libbluray"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir libbluray)"
build="$(prepare_build_dir libbluray)"

# libbluray's release tarball ships a `contrib/libudfread` git-submodule
# placeholder (empty). configure.ac aborts with "libudfread source tree not
# found" unless either external pkg-config libudfread is present or the
# bundled tree contains src/udfread.h. We ship libudfread inline via
# deps.toml (no separate SONAME, no extra packaging) by copying its source
# tree into contrib/libudfread/ before configure runs.
udfread_src="$(source_dir libudfread)"
if [[ ! -f "${src}/contrib/libudfread/src/udfread.h" ]]; then
  log "vendoring libudfread into contrib/libudfread"
  mkdir -p "${src}/contrib/libudfread"
  # cp -a may fail on cross-device or msys2; use cp -R + dotglob safe form.
  (cd "${udfread_src}" && tar -cf - .) | (cd "${src}/contrib/libudfread" && tar -xf -)
fi

# Gitlab archive ships without autotools artifacts — regenerate.
if [[ ! -f "${src}/configure" ]] || [[ ! -f "${src}/.libcommon-autoreconf-done" ]]; then
  log "running autoreconf -fi"
  (cd "${src}" && autoreconf -fi)
  touch "${src}/.libcommon-autoreconf-done"
fi

log "configuring"
cd "${build}"
CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-bdjava-jar \
    --disable-doxygen-doc \
    --disable-examples \
    --without-libxml2 \
    --without-freetype \
    --without-fontconfig

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libbluray.so.2"
log "done"
