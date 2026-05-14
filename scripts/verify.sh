#!/usr/bin/env bash
# verify.sh — confirm every built shared lib SONAME (Linux) or install_name
# (macOS) is declared status="built" in registry.toml, and every
# status="built" entry has been produced.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST_ARCH="$(uname -m)"
case "${HOST_OS}" in
  mingw64_nt*|mingw32_nt*|msys_nt*) HOST_OS="mingw64" ;;
esac
case "${HOST_OS}-${HOST_ARCH}" in
  linux-x86_64)   PLATFORM="linux-x86_64" ;;
  darwin-arm64)   PLATFORM="macos-arm64" ;;
  mingw64-x86_64) PLATFORM="windows-x86_64" ;;
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

def canonical_macos_basename(soname: str, libdir: Path) -> str:
    """Resolve an Linux SONAME to its real-file basename on disk.

    Build scripts install lib<X>.<V>.<minor>.dylib as the real file and
    create lib<X>.<V>.dylib / lib<X>.dylib as symlinks. We want to key
    by the real file's basename, since install_name is set to that.

    If the real file is not yet on disk (planning-time call), fall back
    to the naive soname_to_macos_basename.
    """
    m = re.match(r"^(.+)\.so\.([0-9.]+)$", soname)
    if not m or not libdir.is_dir():
        return soname_to_macos_basename(soname)
    prefix = m.group(1)
    major = m.group(2).split(".")[0]
    # Real file must start with lib<X>.<MAJOR> and end with .dylib, and
    # NOT be a symlink. Take the longest match (the fully-versioned real
    # file).
    candidates = []
    for c in libdir.glob(f"{prefix}.{major}*.dylib"):
        if c.is_symlink() or not c.is_file():
            continue
        candidates.append(c.name)
    if candidates:
        return max(candidates, key=len)
    return soname_to_macos_basename(soname)

# Build the platform-specific expected/planned/skip sets.
expected = {}   # key -> soname  (key = soname on linux, dylib basename on macos, dll basename on windows)
planned = set()
skipped_sonames = set()

libdir = repo_root / "install" / "lib"
bindir = repo_root / "install" / "bin"

# Windows DLLs live in install/bin (PE convention). Linux/macOS share install/lib.
inspect_dir = bindir if platform == "windows-x86_64" else libdir

for item in reg["libcommon"]["libs"]:
    soname = item["soname"]
    status = item.get("status", "planned")
    # Per-entry platform override. Examples:
    #   macos   = "libfoo.5.dylib"  → explicit basename
    #   windows = "libfoo-5.dll"    → explicit basename
    #   <plat>  = "skip"            → skipped on that platform
    mac_field = item.get("macos")
    linux_field = item.get("linux")
    win_field = item.get("windows")
    if platform == "macos-arm64":
        if mac_field == "skip":
            skipped_sonames.add(soname)
            continue
        key = mac_field if isinstance(mac_field, str) else canonical_macos_basename(soname, libdir)
    elif platform == "windows-x86_64":
        if win_field == "skip":
            skipped_sonames.add(soname)
            continue
        if not isinstance(win_field, str):
            # Missing windows column for non-skip entry — registry incomplete.
            print(f"⚠ {soname}: missing 'windows' field in registry.toml; defaulting to autotools mapping")
            m = re.match(r"^(.+)\.so\.([0-9]+)", soname)
            key = f"{m.group(1)}-{m.group(2)}.dll" if m else soname + ".dll"
        else:
            key = win_field
    else:
        if linux_field == "skip":
            skipped_sonames.add(soname)
            continue
        key = soname
    if status == "built":
        expected[key] = soname
    else:
        planned.add(key)

excluded = set(reg.get("system_excluded", {}).get("linux", {}).get("sonames", []))

# Windows: allow a list of system DLLs that we'll never ship but may show
# up as deps of our DLLs (Win32 API, CRT, etc.). Anything else must come
# from install/bin.
WINDOWS_SYSTEM_DLLS = {
    # CRT + low-level OS
    "kernel32.dll", "kernelbase.dll", "ntdll.dll", "msvcrt.dll",
    "ucrtbase.dll", "api-ms-win-crt-*.dll",
    # User/system
    "user32.dll", "gdi32.dll", "advapi32.dll", "shell32.dll", "ole32.dll",
    "oleaut32.dll", "shlwapi.dll", "shcore.dll", "comdlg32.dll", "comctl32.dll",
    "imm32.dll", "winmm.dll", "version.dll", "psapi.dll", "msimg32.dll",
    "dwmapi.dll", "uxtheme.dll", "usp10.dll",
    # Networking / security
    "ws2_32.dll", "wsock32.dll", "iphlpapi.dll", "crypt32.dll", "secur32.dll",
    "bcrypt.dll", "ncrypt.dll", "wininet.dll", "winhttp.dll", "dnsapi.dll",
    "userenv.dll", "rpcrt4.dll",
}

def is_windows_system_dll(name: str) -> bool:
    name = name.lower()
    if name in WINDOWS_SYSTEM_DLLS:
        return True
    # Wildcard api-ms-win-crt-*.dll family.
    if name.startswith("api-ms-win-"):
        return True
    return False

actual = {}  # key -> filename
if inspect_dir.is_dir():
    for f in sorted(inspect_dir.iterdir()):
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
        elif platform == "macos-arm64":
            if not name.endswith(".dylib"):
                continue
            try:
                out = subprocess.check_output(["otool", "-D", str(f)], text=True)
            except subprocess.CalledProcessError:
                out = ""
            lines = [l.strip() for l in out.strip().splitlines() if l.strip()]
            install_name = lines[1] if len(lines) >= 2 else ""
            if install_name and not install_name.startswith("@rpath/"):
                print(f"⚠ {name}: install_name='{install_name}' (expected @rpath/<name>)")
            actual[name] = name
        else:  # windows-x86_64
            if not name.lower().endswith(".dll"):
                continue
            actual[name] = name

if platform == "linux-x86_64":
    label = "SONAMEs"
elif platform == "macos-arm64":
    label = "dylibs"
else:
    label = "DLLs"
print(f"── built {label} in install/{'bin' if platform == 'windows-x86_64' else 'lib'} ──")
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
        errors.append(f"{k} (registry soname={soname}) declared status=built but missing from install/{'bin' if platform == 'windows-x86_64' else 'lib'}")

# Windows: walk each DLL's `objdump -p` output and ensure every "DLL Name:"
# dependency is either a system DLL or also present in install/bin.
if platform == "windows-x86_64":
    actual_lower = {n.lower() for n in actual}
    for f in sorted(inspect_dir.iterdir()):
        if f.is_symlink() or not f.is_file():
            continue
        if not f.name.lower().endswith(".dll"):
            continue
        try:
            out = subprocess.check_output(["objdump", "-p", str(f)], text=True, stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        for line in out.splitlines():
            line = line.strip()
            if not line.startswith("DLL Name:"):
                continue
            dep = line.split(":", 1)[1].strip()
            if is_windows_system_dll(dep):
                continue
            if dep.lower() in actual_lower:
                continue
            errors.append(f"{f.name}: depends on '{dep}' but it is not in install/bin and not a system DLL")

if errors:
    print("\n❌ verify failed:")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

# Linux/macOS binary closure: also check shipped binaries (bin/ffmpeg etc.).
if platform == "linux-x86_64" and bindir.is_dir():
    actual_sonames = set(actual.keys())
    for f in sorted(bindir.iterdir()):
        if f.is_symlink() or not f.is_file() or not os.access(f, os.X_OK):
            continue
        try:
            out = subprocess.check_output(["objdump", "-p", str(f)], text=True, stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        for line in out.splitlines():
            line = line.strip()
            if not line.startswith("NEEDED"):
                continue
            dep = line.split(None, 1)[1].strip()
            if dep in excluded or dep in actual_sonames:
                continue
            errors.append(f"bin/{f.name}: depends on '{dep}' missing from install/lib and system_excluded allowlist")
elif platform == "macos-arm64" and bindir.is_dir():
    # Build a set of every dylib filename present in install/lib, including
    # symlinks (e.g. libavcodec.61.dylib → libavcodec.61.3.100.dylib). The
    # closure check resolves a dep like @rpath/libavcodec.61.dylib against
    # this set rather than against the registry SONAME map.
    installed_dylibs = set()
    for f in inspect_dir.iterdir():
        if f.name.endswith(".dylib") and (f.is_file() or f.is_symlink()):
            installed_dylibs.add(f.name)
    for f in sorted(bindir.iterdir()):
        if f.is_symlink() or not f.is_file() or not os.access(f, os.X_OK):
            continue
        try:
            out = subprocess.check_output(["otool", "-L", str(f)], text=True, stderr=subprocess.DEVNULL)
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        for line in out.splitlines()[1:]:
            dep = line.strip().split(" ", 1)[0].strip()
            if not dep:
                continue
            # System dylibs live in /usr/lib or /System/Library — accept.
            if dep.startswith("/usr/lib/") or dep.startswith("/System/"):
                continue
            base = dep.rsplit("/", 1)[-1]
            if dep.startswith("@rpath/") or dep.startswith("@loader_path/") or dep.startswith("@executable_path/"):
                if base in installed_dylibs:
                    continue
                errors.append(f"bin/{f.name}: {dep} not present in install/lib")
            else:
                errors.append(f"bin/{f.name}: absolute path dep '{dep}' (must be @rpath)")

if errors:
    print("\n❌ verify failed (binary closure):")
    for e in errors:
        print(f"  - {e}")
    sys.exit(1)

print(f"\n✅ verify OK: {len(actual)} {label} match registry "
      f"(built={len(expected)}, planned={len(planned)}, skipped-on-{platform}={len(skipped_sonames)})")
PY
