#!/usr/bin/env bash
# libgomp — copied from the toolchain (GCC runtime). No upstream tarball.
# We resolve symlinks (cp -L) so we ship a single concrete .so.1 with
# RUNPATH=$ORIGIN, free of any toolchain-specific RPATH baggage.
LIB_NAME="libgomp"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

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
