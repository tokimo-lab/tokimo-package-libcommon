#!/usr/bin/env bash
# xcb-proto 1.17.0 — XML protocol descriptions + Python codegen consumed by
# libxcb at build time. Installs headers + Python modules under
# ${INSTALL_DIR}; produces NO .so files (no SONAME, no assert_soname).
LIB_NAME="xcb-proto"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_windows; then
  log "skipping on Windows (X11 family not supported)"
  exit 0
fi

need_tool python3

src="$(source_dir xcb-proto)"
build="$(prepare_build_dir xcb-proto)"

log "configuring"
cd "${build}"
PYTHON=python3 "${src}/configure" \
  --prefix="${INSTALL_DIR}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "done (headers + python only, no SONAME)"
