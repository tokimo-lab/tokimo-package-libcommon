#!/usr/bin/env bash
# package.sh — emit install-<platform>.tar.zst from install/ tree.
# Also writes META.txt with platform / version / SONAME inventory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
PLATFORM="${HOST_OS}-${HOST_ARCH}"

[[ -d install ]] || { echo "FATAL: install/ does not exist; run build-all.sh first" >&2; exit 1; }

VERSION="${VERSION:-${GITHUB_REF_NAME:-dev}}"
ARTIFACT="install-${PLATFORM}.tar.zst"

# Generate META.txt.
{
  echo "tokimo-package-libcommon"
  echo "version: ${VERSION}"
  echo "platform: ${PLATFORM}"
  echo "built_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "git_sha: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo ""
  echo "── SONAMEs ──"
  shopt -s nullglob
  for f in install/lib/*.so*; do
    [[ -L "${f}" ]] && continue
    [[ -f "${f}" ]] || continue
    s="$(objdump -p "${f}" 2>/dev/null | awk '/SONAME/ {print $2; exit}')" || true
    [[ -n "${s}" ]] && echo "${s}    ${f#install/}"
  done
  shopt -u nullglob
} > install/META.txt

echo "[package] META.txt:"
cat install/META.txt

echo "[package] creating ${ARTIFACT}"
tar -C install --use-compress-program='zstd -19 -T0' -cf "${ARTIFACT}" .
ls -lh "${ARTIFACT}"
echo "[package] done."
