# tokimo-package-libcommon

Shared native-library substrate for the [tokimo](https://github.com/tokimo-lab/tokimo) project. Provides one canonical build of foundational shared libraries (zlib, glib, freetype, cairo, …) consumed by every downstream native package (`tokimo-package-ffmpeg`, `tokimo-package-libvips`, …) so each SONAME is loaded **exactly once** at runtime.

> **Status**: `v0.1.0-alpha` — proof-of-concept. Linux x86_64 only. Currently produces 3 L0 leaf libraries (zlib, xz, zstd). Remaining 46 SONAMEs are scaffolded as `status="planned"` in [`registry.toml`](./registry.toml).

## Why

If three native packages each ship their own `libz.so.1`, the linker order at process startup decides which one wins. Different libraries inside the same process may end up calling into *different* zlib instances → silent ABI mismatches, double frees, "impossible" stack traces.

libcommon owns every shared lib used by ≥2 packages, so downstream packages can never accidentally re-vendor the same SONAME. CI enforces:

- Every downstream package's `install/lib/` ∩ libcommon's `install/lib/` = ∅
- Any two downstream packages' `install/lib/` ∩ each other = ∅
- Each `install/lib/*.so*` SONAME appears in [`registry.toml`](./registry.toml) with `status="built"`

See [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) for the full contract.

## Layout

```
.
├── registry.toml          # SoT: 49 SONAMEs owned by libcommon (built|planned)
├── deps.toml              # upstream tarballs (url + sha256 + version)
├── scripts/
│   ├── fetch-sources.sh   # download + sha256-verify + extract → sources/
│   ├── build-all.sh       # dispatcher: --all | --layer L0 | --lib zlib
│   ├── package.sh         # → install-<platform>.tar.zst
│   ├── verify.sh          # cross-check install/lib SONAMEs vs registry.toml
│   └── build/
│       ├── _common.sh     # shared helpers (RUNPATH, strip, assert_soname)
│       ├── zlib.sh
│       ├── xz.sh
│       └── zstd.sh
├── .github/workflows/
│   ├── build.yml          # CI: build + verify + package + release on tag
│   └── check-overlap.yml  # TODO P1.B: cross-repo SONAME overlap check
└── docs/ARCHITECTURE.md
```

After running the pipeline:

```
install/                   # final tree, packaged as install-linux-x86_64.tar.zst
├── lib/
│   ├── libz.so.1.3.1
│   ├── libz.so.1          → libz.so.1.3.1
│   ├── liblzma.so.5.X.Y
│   ├── libzstd.so.1.5.7
│   └── pkgconfig/
├── include/
└── META.txt
```

Every `lib/*.so*` has `RUNPATH = $ORIGIN` (verified via `patchelf` post-process).

## Local build

Requirements: `build-essential`, `pkg-config`, `cmake`, `autoconf automake libtool`, `patchelf`, `zstd`, `python3 ≥ 3.11`.

```bash
bash scripts/fetch-sources.sh              # → sources/zlib, sources/xz, sources/zstd
bash scripts/build-all.sh --layer L0       # → install/lib/libz.so.1 + liblzma.so.5 + libzstd.so.1
bash scripts/verify.sh                     # cross-check SONAMEs vs registry.toml
bash scripts/package.sh                    # → install-linux-x86_64.tar.zst
```

Or build a single library:

```bash
bash scripts/build-all.sh --lib zlib
```

## CI

Pushes to `main` and PRs build all `layer="L0"` entries, verify SONAMEs, and upload `install-linux-x86_64.tar.zst` as a workflow artifact.

Tag pushes (`v*`) additionally publish a GitHub Release with the same tarball attached.

## Roadmap

| Phase | Scope |
|---|---|
| **P1.A** (this release) | Linux x86_64; 3 L0 leaves (zlib / xz / zstd); CI green; release pipeline |
| P1.B | Remaining 46 libs across L1-L6 (Linux x86_64) |
| P1.C | macOS arm64 + x86_64 |
| P1.D | Windows x86_64 |
| P1.E | cross-repo `check-overlap.yml` once ffmpeg / libvips repos are migrated |

## License

[MPL-2.0](./LICENSE). Each bundled upstream library retains its own license; see the corresponding subdir under `sources/`.
