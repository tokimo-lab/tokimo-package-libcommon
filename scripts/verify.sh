#!/usr/bin/env bash
# verify.sh — confirm every built .so SONAME is declared status="built" in
# registry.toml, and every status="built" entry has been produced.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
PLATFORM="${HOST_OS}-${HOST_ARCH}"

python3 - <<'PY'
import os
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ImportError:
    import tomli as tomllib  # type: ignore

repo_root = Path(os.getcwd())
reg = tomllib.loads((repo_root / "registry.toml").read_text())

built_expected = {
    item["soname"] for item in reg["libcommon"]["libs"]
    if item.get("status") == "built"
}
planned = {
    item["soname"] for item in reg["libcommon"]["libs"]
    if item.get("status") == "planned"
}
excluded = set(reg.get("system_excluded", {}).get("linux", {}).get("sonames", []))

libdir = repo_root / "install" / "lib"
actual = {}
if libdir.is_dir():
    for f in sorted(libdir.iterdir()):
        if f.is_symlink() or not f.is_file():
            continue
        if ".so" not in f.name:
            continue
        try:
            out = subprocess.check_output(["objdump", "-p", str(f)], text=True)
        except subprocess.CalledProcessError:
            continue
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("SONAME"):
                soname = line.split(None, 1)[1].strip()
                actual[soname] = f.name
                break

print("── built SONAMEs in install/lib ──")
for s, fn in sorted(actual.items()):
    print(f"  {s:32s}  {fn}")

errors = []

# Every actual SONAME must be in registry as built; not in planned; not excluded.
for s in actual:
    if s in excluded:
        errors.append(f"SONAME {s} is in system_excluded but we shipped it")
    elif s not in built_expected:
        if s in planned:
            errors.append(f"SONAME {s} present but registry says status=planned (bump to 'built')")
        else:
            errors.append(f"SONAME {s} not declared in registry.toml at all")

# Every expected built SONAME must appear in install/lib.
for s in built_expected:
    if s not in actual:
        errors.append(f"SONAME {s} declared status=built but missing from install/lib")

if errors:
    print("\n❌ verify failed:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"\n✅ verify OK: {len(actual)} SONAMEs match registry (built={len(built_expected)}, planned={len(planned)})")
PY
