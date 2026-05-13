#!/usr/bin/env bash
# libgomp — copied from the toolchain (GCC runtime). No upstream tarball.
# macOS: skipped (Apple Clang doesn't ship libgomp; ffmpeg/libvips on macOS
# are built without GCC OpenMP). Registry treats it as platform-conditional.
LIB_NAME="libgomp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_macos; then
  log "skipping on macOS (no GCC OpenMP runtime; consumers use libomp if needed)"
  exit 0
fi

if is_windows; then
  # Windows: ship the entire mingw-w64 toolchain runtime quartet
  # (libgcc_s_seh-1, libstdc++-6, libwinpthread-1, libgomp-1) from
  # ${MSYSTEM_PREFIX}/bin/. These DLLs are linked into every other
  # libcommon DLL by the mingw GCC frontend, so they MUST be co-shipped.
  log "shipping mingw toolchain runtime DLLs (incl. libgomp-1.dll)"
  ship_mingw_runtime
  WINDOWS_DLL_OVERRIDE="libgomp-1.dll" assert_soname "libgomp.so.1"
  log "done"
  exit 0
fi

log "locating libgomp from system gcc"
sysgomp=""
for cand in \
  /usr/lib64/libgomp.so.1 \
  /usr/lib/x86_64-linux-gnu/libgomp.so.1 \
  /usr/lib/gcc/x86_64-redhat-linux/14/libgomp.so.1 \
  /opt/rh/gcc-toolset-14/root/usr/lib/gcc/x86_64-redhat-linux/14/libgomp.so.1
do
  if [[ -e "$cand" ]]; then
    sysgomp="$cand"
    break
  fi
done
if [[ -z "$sysgomp" ]]; then
  # Last-resort dynamic resolution: ask gcc where it gets libgomp from.
  if command -v gcc >/dev/null 2>&1; then
    sysgomp="$(gcc -print-file-name=libgomp.so.1 2>/dev/null || true)"
    [[ -e "$sysgomp" ]] || sysgomp=""
  fi
fi
[[ -n "$sysgomp" ]] || fatal "libgomp.so.1 not found on this system"

log "copying $sysgomp"
mkdir -p "${INSTALL_DIR}/lib"
cp -L "$sysgomp" "${INSTALL_DIR}/lib/libgomp.so.1"
chmod 0755 "${INSTALL_DIR}/lib/libgomp.so.1"

log "post-processing"
post_process_install

assert_soname "libgomp.so.1"
log "done"
