#!/usr/bin/env bash
# libXau 1.0.11 — autotools. Needs xorg-macros (xorgproto provides aclocal m4
# files like XORG_DEFAULT_OPTIONS). manylinux_2_28 typically has
# xorg-x11-util-macros via system, but to be portable we point ACLOCAL_PATH
# at any installed location and fall back to vendoring a stub if missing.
LIB_NAME="libXau"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  log "skipping on Windows (X11 family not supported)"
  exit 0
fi

src="$(source_dir libXau)"
build="$(prepare_build_dir libXau)"

# If util-macros aclocal files are available system-wide, configure finds them
# automatically. Add common locations to ACLOCAL_PATH defensively.
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

assert_soname "libXau.so.6"
log "done"
