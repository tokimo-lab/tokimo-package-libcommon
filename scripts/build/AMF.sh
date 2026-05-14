#!/usr/bin/env bash
# AMF (AMD Advanced Media Framework) headers — header-only.
# License: MIT (per GPUOpen-LibrariesAndSDKs/AMF). Required for
# ffmpeg --enable-amf on Linux + Windows. macOS: skip (AMD GPU AMF
# encoder not supported on Apple Silicon / macOS in general).
LIB_NAME="AMF"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

if is_macos; then
  log "skip: AMF not supported on macOS"
  exit 0
fi

src="$(source_dir AMF)"

log "installing AMF headers into ${INSTALL_DIR}/include/AMF/"
mkdir -p "${INSTALL_DIR}/include/AMF"
# Upstream layout: amf/public/include/{components,core,…}
cp -RfL "${src}/amf/public/include/." "${INSTALL_DIR}/include/AMF/"

log "done"
