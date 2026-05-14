#!/usr/bin/env bash
# package.sh — emit install-<platform>.tar.zst from install/ tree.
# Also writes META.txt with platform / version / SONAME inventory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
case "${HOST_OS}" in
  mingw64_nt*|mingw32_nt*|msys_nt*) HOST_OS="mingw64" ;;
esac
case "${HOST_OS}-${HOST_ARCH}" in
  linux-x86_64)   PLATFORM="linux-x86_64"; SHLIB_GLOB='install/lib/*.so*';  INSPECT="objdump_soname" ;;
  darwin-arm64)   PLATFORM="macos-arm64";  SHLIB_GLOB='install/lib/*.dylib'; INSPECT="otool_id" ;;
  mingw64-x86_64) PLATFORM="windows-x86_64"; SHLIB_GLOB='install/bin/*.dll'; INSPECT="dll_basename" ;;
  *) echo "FATAL: platform ${HOST_OS}-${HOST_ARCH} not supported" >&2; exit 1 ;;
esac

[[ -d install ]] || { echo "FATAL: install/ does not exist; run build-all.sh first" >&2; exit 1; }

VERSION="${VERSION:-${GITHUB_REF_NAME:-dev}}"
ARTIFACT="install-${PLATFORM}.tar.zst"

inspect_id() {
  local f="$1"
  case "${INSPECT}" in
    objdump_soname)
      objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print $2; exit}' || true
      ;;
    otool_id)
      otool -D "${f}" 2>/dev/null | tail -n +2 | head -1 | tr -d ' ' || true
      ;;
    dll_basename)
      # PE has no SONAME; the basename IS the identity.
      basename "${f}"
      ;;
  esac
}

# Generate META.txt.
{
  echo "tokimo-package-libcommon"
  echo "version: ${VERSION}"
  echo "platform: ${PLATFORM}"
  echo "built_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "git_sha: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo ""
  echo "── shared libs ──"
  shopt -s nullglob
  for f in ${SHLIB_GLOB}; do
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    id="$(inspect_id "${f}")"
    [[ -n "${id}" ]] && echo "${id}    ${f#install/}"
  done
  shopt -u nullglob
  echo ""
  echo "── binaries ──"
  shopt -s nullglob
  for bin_dir in install/bin install/usr/bin; do
    [[ -d "${bin_dir}" ]] || continue
    for f in "${bin_dir}"/ffmpeg "${bin_dir}"/ffmpeg.exe "${bin_dir}"/ffprobe "${bin_dir}"/ffprobe.exe; do
      [[ -f "${f}" ]] && echo "${f#install/}"
    done
  done
  shopt -u nullglob
} > install/META.txt

echo "[package] META.txt:"
cat install/META.txt

echo "[package] creating ${ARTIFACT}"
tar -C install --use-compress-program='zstd -19 -T0' -cf "${ARTIFACT}" .
ls -lh "${ARTIFACT}"
echo "[package] done."
