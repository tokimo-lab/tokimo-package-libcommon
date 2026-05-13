#!/usr/bin/env bash
# libXdmcp 1.1.5 — autotools. Needs xorg util-macros (same pattern as libXau).
LIB_NAME="libXdmcp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  log "skipping on Windows (X11 family not supported)"
  exit 0
fi

src="$(source_dir libXdmcp)"
build="$(prepare_build_dir libXdmcp)"

extra_aclocal=""
for d in /usr/share/aclocal /usr/local/share/aclocal "${INSTALL_DIR}/share/aclocal"; do
  [[ -d "$d" ]] && extra_aclocal="${extra_aclocal}:${d}"
done
export ACLOCAL_PATH="${extra_aclocal#:}${ACLOCAL_PATH:+:${ACLOCAL_PATH}}"

log "configuring (ACLOCAL_PATH=${ACLOCAL_PATH})"
cd "${build}"
CFLAGS="${CFLAGS}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

assert_soname "libXdmcp.so.6"
log "done"
