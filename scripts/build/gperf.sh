#!/usr/bin/env bash
# gperf 3.1 — perfect-hash generator. Build-time only; ships no .so. Required
# by fontconfig (and later by glib's gio gschemas if we ever re-enable them).
LIB_NAME="gperf"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir gperf)"
build="$(prepare_build_dir gperf)"

log "configuring"
cd "${build}"
"${src}/configure" \
  --prefix="${INSTALL_DIR}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "done (build-time tool, no SONAME)"
