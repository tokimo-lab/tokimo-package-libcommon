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
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

# Prevent fetches from hanging forever (msys2 Python's urllib has no
# default socket timeout). 120s is generous enough for slow mirrors
# while still detecting dead connections quickly.
socket.setdefaulttimeout(120)

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

def _tar_strip1(archive: Path, dest: Path) -> None:
    """Native-Python tar extractor with --strip-components=1 semantics.

    Why not just `subprocess.run(['tar', '--strip-components=1', ...])`?
    On msys2 (Windows runner) the external tar.exe + xz.exe pipeline forks
    once per archived file thanks to msys2's POSIX emulation, which can
    stretch a sub-second extract to tens of minutes on a 5 MB tarball.
    Python's stdlib tarfile module reads the archive natively in-process,
    so it scales linearly with archive size on all three platforms.
    """
    import tarfile
    name = archive.name
    if name.endswith(".tar.gz") or name.endswith(".tgz"):
        mode = "r:gz"
    elif name.endswith(".tar.xz"):
        mode = "r:xz"
    elif name.endswith(".tar.bz2"):
        mode = "r:bz2"
    elif name.endswith(".tar.zst") or name.endswith(".tar.zstd"):
        mode = "r:*"  # fallback to external for zstd (none in our deps.toml)
    else:
        raise RuntimeError(f"unknown archive type: {name}")
    with tarfile.open(archive, mode) as tf:
        members = []
        for m in tf.getmembers():
            parts = m.name.replace("\\", "/").split("/", 1)
            if len(parts) < 2 or not parts[1]:
                continue  # strip the top-level dir itself
            m.name = parts[1]
            members.append(m)
        # Use filter='data' (py3.12+) for safer extraction when available.
        try:
            tf.extractall(dest, members=members, filter="data")
        except TypeError:
            tf.extractall(dest, members=members)

def extract(archive: Path, dest: Path) -> None:
    """Extract archive into dest/, stripping the top-level directory."""
    dest.mkdir(parents=True, exist_ok=True)
    name = archive.name
    if name.endswith(".tar.zst") or name.endswith(".tar.zstd"):
        # zstd needs --zstd on tar < 1.31 or a recent libarchive; safest
        # is to delegate to system tar which both Linux/macOS handle and
        # msys2 has via mingw-w64-x86_64-zstd shipped with our toolchain.
        cmd = ["tar", "--zstd", "-xf", str(archive), "-C", str(dest), "--strip-components=1"]
        subprocess.run(cmd, check=True)
        return
    _tar_strip1(archive, dest)

for entry in data.get("source", []):
    name = entry["name"]
    if filter_name and filter_name != name:
        continue
    if filter_layer and filter_layer != entry.get("layer"):
        continue

    version = entry["version"]
    url = entry["url"]
    mirrors = entry.get("mirrors", []) or []
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
        tmp = archive.with_suffix(archive.suffix + ".part")
        if tmp.exists():
            tmp.unlink()
        uas = [
            "Python-urllib/3.x",
            "Wget/1.21",
            "curl/8.0",
            "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
        ]
        # Try primary URL then any mirrors; for each URL rotate UAs across
        # attempts. A 4xx ban tends to be IP+UA scoped, so a different UA
        # may slip through; if every UA on a given host still 4xxs (host-
        # level ban / CDN block) we fall through to the next mirror.
        candidate_urls = [url, *mirrors]
        delays = [3, 6, 12, 24]  # per-URL: 4 attempts ~45s, then move on
        last_err = None
        downloaded = False
        for ui, candidate in enumerate(candidate_urls):
            label = "primary" if ui == 0 else f"mirror {ui}"
            print(f"[fetch]   downloading {candidate}  ({label})", flush=True)
            for attempt in range(len(delays)):
                ua = uas[attempt % len(uas)]
                req = urllib.request.Request(candidate, headers={"User-Agent": ua})
                try:
                    with urllib.request.urlopen(req) as resp, open(tmp, "wb") as out:
                        shutil.copyfileobj(resp, out)
                    last_err = None
                    downloaded = True
                    break
                except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, ConnectionError, OSError) as e:
                    last_err = e
                    if tmp.exists():
                        tmp.unlink()
                    wait = delays[attempt]
                    print(f"[fetch]   attempt {attempt+1}/{len(delays)} (UA={ua!r}) failed: {e}; retrying in {wait}s", flush=True)
                    time.sleep(wait)
            if downloaded:
                break
            print(f"[fetch]   {label} exhausted, trying next URL", flush=True)
        if not downloaded:
            raise SystemExit(f"download failed for {name} after exhausting {len(candidate_urls)} URL(s): {last_err}")
        actual = sha256_file(tmp)
        if actual != want_sha:
            tmp.unlink()
            raise SystemExit(f"sha256 mismatch for {name}: want {want_sha}, got {actual}")
        tmp.rename(archive)
        print(f"[fetch]   sha256 OK", flush=True)

    marker = target / ".fetch.sha256"
    if target.exists() and marker.exists() and marker.read_text().strip() == want_sha:
        print(f"[fetch]   source dir up to date, skipping extract")
        continue

    if target.exists():
        shutil.rmtree(target)
    print(f"[fetch]   extracting → {target}", flush=True)
    extract(archive, target)
    marker.write_text(want_sha + "\n")

print("[fetch] all done.")
PY
