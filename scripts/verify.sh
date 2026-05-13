#!/usr/bin/env bash
# verify.sh — confirm every built shared lib SONAME (Linux) or install_name
# (macOS) is declared status="built" in registry.toml, and every
# status="built" entry has been produced.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
case "${HOST_OS}-${HOST_ARCH}" in
  linux-x86_64) PLATFORM="linux-x86_64" ;;
  darwin-arm64) PLATFORM="macos-arm64" ;;
  *) echo "FATAL: platform ${HOST_OS}-${HOST_ARCH} not supported" >&2; exit 1 ;;
esac
export PLATFORM

python3 - <<'PY'
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore

repo_root = Path(os.getcwd())
platform = os.environ["PLATFORM"]
reg = tomllib.loads((repo_root / "registry.toml").read_text())

def soname_to_macos_basename(soname: str) -> str:
    m = re.match(r"^(.+)\.so\.([0-9.]+)$", soname)
    if m:
        return f"{m.group(1)}.{m.group(2)}.dylib"
    if soname.endswith(".so"):
        return soname[:-3] + ".dylib"
    return soname + ".dylib"

# Build the platform-specific expected/planned/skip sets.
expected = {}   # key -> soname  (key = soname on linux, dylib basename on macos)
planned = set()
skipped_sonames = set()
for item in reg["libcommon"]["libs"]:
    soname = item["soname"]
    status = item.get("status", "planned")
    # Per-entry platform override. Examples:
    #   macos = "libfoo.5.dylib"   → explicit basename
    #   macos = "skip"             → skipped on macOS
    mac_field = item.get("macos")
    if platform == "macos-arm64":
        if mac_field == "skip":
            skipped_sonames.add(soname)
            continue
        key = mac_field if isinstance(mac_field, str) else soname_to_macos_basename(soname)
    else:
        key = soname
    if status == "built":
        expected[key] = soname
    else:
        planned.add(key)

excluded = set(reg.get("system_excluded", {}).get("linux", {}).get("sonames", []))

libdir = repo_root / "install" / "lib"
actual = {}  # key -> filename
if libdir.is_dir():
    for f in sorted(libdir.iterdir()):
        if f.is_symlink() or not f.is_file():
            continue
        name = f.name
        if platform == "linux-x86_64":
            if ".so" not in name:
                continue
            try:
                out = subprocess.check_output(["objdump", "-p", str(f)], text=True)
            except subprocess.CalledProcessError:
                continue
            for line in out.splitlines():
                line = line.strip()
                if line.startswith("SONAME"):
                    soname = line.split(None, 1)[1].strip()
                    actual[soname] = name
                    break
        else:  # macos-arm64
            if not name.endswith(".dylib"):
                continue
            try:
                out = subprocess.check_output(["otool", "-D", str(f)], text=True)
            except subprocess.CalledProcessError:
                continue
            lines = [l.strip() for l in out.strip().splitlines() if l.strip()]
            # otool -D output: "path:\n<install_name>"
            install_name = lines[1] if len(lines) >= 2 else ""
            # Key by install_name basename (the SONAME-equivalent symlink
            # name we canonicalize to in post_process_install_macos), not
            # by the real fully-versioned filename. This matches what
            # registry.toml expects (mapped from "libfoo.so.N" →
            # "libfoo.N.dylib").
            if install_name.startswith("@rpath/"):
                key = install_name[len("@rpath/"):]
            else:
                key = name
                if install_name:
                    print(f"⚠ {name}: install_name='{install_name}' (expected @rpath/<name>)")
            actual[key] = name

label = "SONAMEs" if platform == "linux-x86_64" else "dylibs"
print(f"── built {label} in install/lib ──")
for k, fn in sorted(actual.items()):
    print(f"  {k:36s}  {fn}")

errors = []

for k in actual:
    if platform == "linux-x86_64" and k in excluded:
        errors.append(f"{k} is in system_excluded but we shipped it")
    elif k not in expected:
        if k in planned:
            errors.append(f"{k} present but registry says status=planned (bump to 'built')")
        else:
            errors.append(f"{k} not declared in registry.toml for {platform}")

for k, soname in expected.items():
    if k not in actual:
        errors.append(f"{k} (registry soname={soname}) declared status=built but missing from install/lib")

if errors:
    print("\n❌ verify failed:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"\n✅ verify OK: {len(actual)} {label} match registry "
      f"(built={len(expected)}, planned={len(planned)}, skipped-on-{platform}={len(skipped_sonames)})")
PY
