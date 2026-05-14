#!/usr/bin/env bash
# build-all.sh — dispatcher.
#
# Usage:
#   bash scripts/build-all.sh --all                 # build every entry in deps.toml
#   bash scripts/build-all.sh --layer L0            # build all entries with layer="L0"
#   bash scripts/build-all.sh --lib zlib            # build a single named entry

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

mode=""
arg=""
case "${1:-}" in
  --all)   mode=all ;;
  --layer) mode=layer; arg="${2:?missing layer name}" ;;
  --lib)   mode=lib;   arg="${2:?missing lib name}" ;;
  *) echo "Usage: $0 --all | --layer <L0|L1|...> | --lib <name>" >&2; exit 2 ;;
esac

# Generate the build list using Python (deps.toml order preserved).
mapfile -t libs < <(python3 - "${mode}" "${arg}" <<'PY'
import sys
# Disable \n→\r\n translation so msys2 mapfile -t gets clean LF-only output.
sys.stdout.reconfigure(newline="\n")
try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore
from pathlib import Path

mode = sys.argv[1]
arg = sys.argv[2] if len(sys.argv) > 2 else ""
with open("deps.toml", "rb") as f:
    data = tomllib.load(f)
for entry in data.get("source", []):
    # Entries without a `build` field are header-only or vendored deps
    # (e.g. libudfread bundled inside libbluray) — skip them.
    if "build" not in entry:
        continue
    if mode == "all":
        print(entry["build"])
    elif mode == "layer" and entry.get("layer") == arg:
        print(entry["build"])
    elif mode == "lib" and entry["name"] == arg:
        print(entry["build"])
PY
)

if [[ ${#libs[@]} -eq 0 ]]; then
  echo "[build-all] no libs match selection ($mode $arg)" >&2
  exit 1
fi

echo "[build-all] plan: ${libs[*]}"

mkdir -p "${REPO_ROOT}/install" "${REPO_ROOT}/build"

for lib in "${libs[@]}"; do
  script="${REPO_ROOT}/scripts/build/${lib}.sh"
  [[ -f "${script}" ]] || { echo "FATAL: ${script} not found"; exit 1; }
  echo
  echo "════════════════════════════════════════════════════════════════════"
  echo "  building: ${lib}"
  echo "════════════════════════════════════════════════════════════════════"
  bash "${script}"
done

# Only the --all path produces a shippable tree. Prune auxiliary binaries
# from install/bin (brotli, nettle-hash, pcre2test, ...) installed
# transitively by deps; keep only ffmpeg/ffprobe/ffplay. Run AFTER every
# lib so build-time helpers like gperf survive until they are no longer
# needed.
if [[ "${mode}" == "all" ]]; then
  source "${REPO_ROOT}/scripts/build/_common.sh"
  prune_install_bin
fi

echo
echo "[build-all] all done."
