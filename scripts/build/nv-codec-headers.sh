#!/usr/bin/env bash
# nv-codec-headers (FFmpeg/nv-codec-headers n12.2.72.0) — header-only.
# License: MIT (stub headers that satisfy NVENC/NVDEC link-time API; the
# actual runtime resolves nvcuda.dll / libcuda.so.1 from the host system).
#
# Built on all three platforms (yes, including macOS and Windows — they
# install only headers so they're a no-op at runtime). ffmpeg's configure
# uses ffnvcodec.pc to find them.
LIB_NAME="nv-codec-headers"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir nv-codec-headers)"

log "installing headers (PREFIX=${INSTALL_DIR})"
make -C "${src}" install PREFIX="${INSTALL_DIR}"

# No SONAME / DLL to assert: header-only package. registry.toml does NOT
# declare any soname for this entry.
log "done"
