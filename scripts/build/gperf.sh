#!/usr/bin/env bash
# gperf 3.1 — perfect-hash generator. Build-time only; ships no .so. Required
# by fontconfig (and later by glib's gio gschemas if we ever re-enable them).
LIB_NAME="gperf"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir gperf)"
build="$(prepare_build_dir gperf)"

log "configuring"
cd "${build}"
# gperf 3.1's bundled lib/getopt.c uses K&R declarations rejected by C23
# (gcc 16 default on msys2). Fall back to gnu17 there.
gperf_cflags="${CFLAGS}"
gperf_cxxflags="${CXXFLAGS}"
if is_windows; then
  gperf_cflags="${gperf_cflags} -std=gnu17"
  gperf_cxxflags="${gperf_cxxflags} -std=gnu++17"
fi
CFLAGS="${gperf_cflags}" CXXFLAGS="${gperf_cxxflags}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}"

log "building"
make -j"${NPROC}"

log "installing"
make install

log "done (build-time tool, no SONAME)"
