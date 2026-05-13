#!/usr/bin/env bash
# fetch-sources.sh
#
# Reads deps.toml, downloads each [[source]] entry to sources/<name>-<version>.<ext>,
# verifies sha256, and extracts into sources/<name>/ (stripping the top-level
# tarball directory).
#
# Idempotent: skips download if file exists & checksum matches; skips extract
# if target dir exists & .sha256-marker matches.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES_DIR="${REPO_ROOT}/sources"
DEPS_FILE="${REPO_ROOT}/deps.toml"

mkdir -p "${SOURCES_DIR}"

log()   { printf '\033[1;36m[fetch]\033[0m %s\n' "$*"; }
fatal() { printf '\033[1;31m[fetch] FATAL:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "${DEPS_FILE}" ]] || fatal "deps.toml not found at ${DEPS_FILE}"

export REPO_ROOT

# Parse deps.toml via Python (TOML support since 3.11 via tomllib).
python3 - "$@" <<'PY'
import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

try:
    import tomllib  # py3.11+
except ImportError:
    import tomli as tomllib  # type: ignore

repo_root_env = os.environ.get("REPO_ROOT")
if not repo_root_env:
    raise SystemExit("REPO_ROOT env not set")
repo_root = Path(repo_root_env)
deps_file = repo_root / "deps.toml"
sources_dir = repo_root / "sources"

with open(deps_file, "rb") as f:
    data = tomllib.load(f)

filter_layer = None
filter_name = None
args = sys.argv[1:]
i = 0
while i < len(args):
    a = args[i]
    if a == "--layer":
        filter_layer = args[i + 1]
        i += 2
    elif a == "--name":
        filter_name = args[i + 1]
        i += 2
    else:
        i += 1

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def extract(archive: Path, dest: Path) -> None:
    """Extract archive into dest/, stripping the top-level directory."""
    dest.mkdir(parents=True, exist_ok=True)
    name = archive.name
    if name.endswith(".tar.gz") or name.endswith(".tgz"):
        opt = "xzf"
    elif name.endswith(".tar.xz"):
        opt = "xJf"
    elif name.endswith(".tar.bz2"):
        opt = "xjf"
    elif name.endswith(".tar.zst") or name.endswith(".tar.zstd"):
        opt = "x --zstd -f"
    else:
        raise RuntimeError(f"unknown archive type: {name}")
    cmd = ["tar"] + opt.split() + [str(archive), "-C", str(dest), "--strip-components=1"]
    subprocess.run(cmd, check=True)

for entry in data.get("source", []):
    name = entry["name"]
    if filter_name and filter_name != name:
        continue
    if filter_layer and filter_layer != entry.get("layer"):
        continue

    version = entry["version"]
    url = entry["url"]
    want_sha = entry["sha256"]
    layer = entry.get("layer", "?")

    # Entries with empty url have no upstream tarball (e.g. libgomp, copied
    # from the system GCC runtime). Skip the fetch/extract phase entirely.
    if not url:
        print(f"[fetch] {name} {version}  ({layer})  → no url, skipping")
        continue

    ext = ".tar.gz"
    for cand in (".tar.xz", ".tar.gz", ".tgz", ".tar.bz2", ".tar.zst"):
        if url.endswith(cand):
            ext = cand
            break
    archive = sources_dir / f"{name}-{version}{ext}"
    target = sources_dir / name

    print(f"[fetch] {name} {version}  ({layer})  → {archive.name}")

    need_download = True
    if archive.exists():
        actual = sha256_file(archive)
        if actual == want_sha:
            print(f"[fetch]   cached, sha256 OK")
            need_download = False
        else:
            print(f"[fetch]   cached file sha256 mismatch ({actual}); redownloading")
            archive.unlink()

    if need_download:
        print(f"[fetch]   downloading {url}")
        tmp = archive.with_suffix(archive.suffix + ".part")
        if tmp.exists():
            tmp.unlink()
        urllib.request.urlretrieve(url, tmp)
        actual = sha256_file(tmp)
        if actual != want_sha:
            tmp.unlink()
            raise SystemExit(f"sha256 mismatch for {name}: want {want_sha}, got {actual}")
        tmp.rename(archive)
        print(f"[fetch]   sha256 OK")

    marker = target / ".fetch.sha256"
    if target.exists() and marker.exists() and marker.read_text().strip() == want_sha:
        print(f"[fetch]   source dir up to date, skipping extract")
        continue

    if target.exists():
        shutil.rmtree(target)
    print(f"[fetch]   extracting → {target}")
    extract(archive, target)
    marker.write_text(want_sha + "\n")

print("[fetch] all done.")
PY
