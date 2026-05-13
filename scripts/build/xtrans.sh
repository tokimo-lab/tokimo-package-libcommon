#!/usr/bin/env bash
# xtrans 1.5.2 — X11 transport macros, header/pkg-config only. No .so output;
# consumed by libX11 at build time. Pattern mirrors xcb-proto.sh.
LIB_NAME="xtrans"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  log "skipping on Windows (X11 family not supported)"
  exit 0
fi

src="$(source_dir xtrans)"
build="$(prepare_build_dir xtrans)"

log "configuring"
cd "${build}"
"${src}/configure" --prefix="${INSTALL_DIR}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "done (headers + pkg-config only, no SONAME)"
