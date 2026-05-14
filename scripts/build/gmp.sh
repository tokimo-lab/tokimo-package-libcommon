#!/usr/bin/env bash
# gmp 6.3.0 — autotools, no C++ bindings.
LIB_NAME="gmp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir gmp)"
build="$(prepare_build_dir gmp)"

log "configuring"
cd "${build}"
# On mingw, GMP's `try.c` compiler probe uses printf("%lld",...) which
# requires the ANSI stdio shim — without it the probe prints the wrong
# value and configure aborts with "long long reliability test 1".
extra_cflags=""
if is_windows; then
  extra_cflags="-D__USE_MINGW_ANSI_STDIO=1"
fi
CFLAGS="${CFLAGS} ${extra_cflags}" LDFLAGS="${LDFLAGS}" \
  "${src}/configure" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --enable-cxx=no

log "building"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

# Mingw libtool produces libgmp-10.dll (hyphen, not dot).
WINDOWS_DLL_OVERRIDE="libgmp-10.dll" assert_soname "libgmp.so.10"
log "done"
