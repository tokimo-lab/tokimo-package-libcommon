# Architecture

> Excerpted from the tokimo libcommon design plan. See parent project for full background.

## Single-Source-of-Truth contract

Every SONAME (Linux) / `LC_ID_DYLIB` (macOS) / DLL filename (Windows) used by tokimo's native packages has **exactly one** official provider. The provider is recorded in [`registry.toml`](../registry.toml). Moving ownership requires a major-version bump of libcommon and a synchronous rebuild of every consumer.

### Invariants (CI-enforced)

1. **Disjointness across non-libcommon packages.** For any two consumer packages A and B:
   `SONAMEs(A/install/lib) ∩ SONAMEs(B/install/lib) = ∅`
2. **Upstream packages never re-vendor libcommon entries.**
   `SONAMEs(consumer/install/lib) ∩ SONAMEs(libcommon/install/lib) = ∅`
3. **No transitive runpath between consumers.** A consumer's `.so` may only `RUNPATH` to its own dir and libcommon, never to another consumer.

`tools/check-no-overlap.sh` (P1.B) downloads each release artifact and asserts these.

## Layout & loader semantics

```
bin/
├── libcommon/lib/   ← the only shared pool
├── ffmpeg/lib/      ← ffmpeg-exclusive sonames
├── libvips/lib/     ← libvips-exclusive sonames
└── ...

LD_LIBRARY_PATH = bin/libcommon/lib : bin/ffmpeg/lib : bin/libvips/lib : ...
```

Per-`.so` `RUNPATH`:

| Package | RUNPATH (Linux) | rpath (macOS) |
|---|---|---|
| `libcommon/lib/*.so` | `$ORIGIN` | `@loader_path` |
| `<consumer>/lib/*.so` | `$ORIGIN:$ORIGIN/../../libcommon/lib` | `@loader_path:@loader_path/../../libcommon/lib` |
| Between consumers | **forbidden** | **forbidden** |

`$ORIGIN` is force-overwritten via `patchelf --force-rpath --set-rpath '$ORIGIN'` in `scripts/build/_common.sh::post_process_install` so individual autoconf/cmake decisions cannot leak host paths into the artifact.

## Three-platform deltas

| Aspect | Linux | macOS arm64 | Windows x86_64 |
|---|---|---|---|
| Extension | `.so` | `.dylib` | `.dll` |
| Identity | `SONAME` field (embedded at link time) | `LC_ID_DYLIB` | **filename only** |
| Search | `DT_RUNPATH` + `LD_LIBRARY_PATH` | `LC_RPATH` + `DYLD_LIBRARY_PATH` (SIP-restricted) | DLL search order |
| Relative origin | `$ORIGIN` | `@loader_path` / `@rpath` | none |
| Mutator | `patchelf --set-rpath` | `install_name_tool -id / -add_rpath` | n/a |
| Inspector | `objdump -p`, `ldd` | `otool -L`, `otool -l` | `dumpbin /dependents` |
| ABI fault zone | glibc (versioned symbols) | clang/Mach-O | MSVC vs MinGW |

Only Linux is implemented in P1.A. macOS and Windows scaffolding will be added in P1.C/D using the same orchestrator but with platform-specific `_common.sh` branches.

## Build orchestration

We deliberately use `bash + per-library scripts` instead of Meson subprojects:

- Library build systems are too heterogeneous to wrap uniformly (autoconf, cmake, plain make, meson). Forcing every dependency into Meson subprojects would mean upstream patches and ongoing maintenance.
- Per-script granularity matches the natural mental model: when zlib breaks, you read `scripts/build/zlib.sh`, not a generated subproject wrapper.
- `_common.sh` provides the cross-cutting concerns (RUNPATH normalization, SONAME assertion, env propagation).

`PKG_CONFIG_PATH` is set to `$INSTALL_DIR/lib/pkgconfig:$INSTALL_DIR/lib64/pkgconfig` so upper layers see the lower-layer `.pc` files.

## Version coupling (future)

When libcommon's `version` major-bumps (any SONAME change), every consumer's `deps.toml` `requires.libcommon = "^X"` constraint is re-validated and consumers must be rebuilt before re-release. See parent project `scripts/dev/deps/fetch.ts` (TBD) for the runtime check.
