# P2-NEW · ffmpeg integration · status

**Branch**: `ffmpeg-port`
**Base**: v1.0.0 main (49 SONAMEs + 3 Windows toolchain runtime DLLs, 3-platform green)
**Goal**: ship v1.1.0 = base + ffmpeg L7 layer (~20 encoder deps + 8 ffmpeg DLLs/so/dylib)
**Do NOT**: merge to main, push tag — manager review required first.

## Wave plan vs. progress

| Wave | Scope | Status |
|------|-------|--------|
| **A** | 5 BSD/LGPL leaf encoders (libogg, opus, lame, soxr, dav1d) | ✅ **GREEN on all 3 platforms** (run 25859811868 @ 6fadf65) |
| B | GPL video encoders: x264, x265, svt-av1, vpx, aom, theora | ⏸ awaiting manager review of Wave A |
| C | subs/container/net/img: libass, libbluray, srt, zvbi, zimg, openmpt, jxl, chromaprint, fdk-aac, libvorbis | ⏳ |
| D | GPU headers-only: nv-codec-headers, AMF | ⏳ (linux/windows only) |
| E | ffmpeg from jellyfin-ffmpeg + 96-patch series apply | ⏳ — Wave A+B+E are the must-haves; C/D may slip to v1.1.x |
| F | verify.sh ffmpeg dep-closure check | ⏳ |

## Wave A details — what was committed

Commits on `ffmpeg-port`:

1. `d08f84d ci: trigger build workflow on ffmpeg-port branch`
2. `ff9b011 build(L7): add Wave A — 5 BSD/LGPL leaf encoders for ffmpeg`

Added files:

```
scripts/build/libogg.sh      autotools  libogg.so.0          (BSD-3-Clause)
scripts/build/opus.sh        autotools  libopus.so.0         (BSD-3-Clause)
scripts/build/lame.sh        autotools  libmp3lame.so.0      (LGPL-2.0+)
scripts/build/soxr.sh        cmake      libsoxr.so.0         (LGPL-2.1+)
scripts/build/dav1d.sh       meson      libdav1d.so.7        (BSD-2-Clause)
```

deps.toml: new `L7` block appended (5 entries).
registry.toml: new `[[libcommon.libs]]` entries appended (5 entries, all `status = "built"`).

## Wave A risk register (likely CI hits)

| Risk | Affected | Fix path |
|------|----------|----------|
| dav1d meson `libdav1d.dll` name on mingw — may actually be `libdav1d-7.dll` (libtool soversion) | windows | flip `windows =` in registry.toml + re-run |
| lame `--disable-decoder` not honored by `--enable-shared` on macOS (libmp3lame still pulls mpglib) | macos | drop `--disable-decoder` if soname check fails |
| dav1d 1.5.1 may need nasm 2.14+ (Apple Silicon already brews nasm; ok) | macos | n/a, brew nasm present in build.yml |
| soxr CMake on Windows produces `libsoxr.dll` not `libsoxr-0.dll` (CMake doesn't generate libtool versioning) | windows | `windows = "libsoxr.dll"` flip |
| sourceforge mirror occasionally 403s; lame + soxr both pull from sf.net | all | fetch-sources.sh retry logic handles UA rotation; if persistent, add `mirrors = [...]` |
| opus 1.5.2 ships meson primary, autotools secondary — autotools `--disable-extra-programs` flag may not exist | all | flip to meson-based script if configure errors |

Plan: when CI lands, address per-platform failures with `fix(<lib>): …` commits at same granularity as base layer (see git log post v0.3.0 for the established pattern).

## Wave E (ffmpeg itself) — design notes

Reference: `tokimo.io/packages/tokimo-package-ffmpeg/` (jellyfin-ffmpeg fork w/ 96 debian patches).

Build script outline (`scripts/build/ffmpeg.sh`):

```
LIB_NAME="ffmpeg"
source _common.sh

# 1. Clone jellyfin-ffmpeg @ branch=jellyfin to sources/ffmpeg-src
#    (fetch-sources.sh special-case: not a tarball, git clone instead)
# 2. Apply debian/patches/series IN ORDER (use gpatch on macOS for fuzz)
# 3. configure with flags 1:1 from packages/tokimo-package-ffmpeg/scripts/build-ffmpeg.sh
#    (Linux: full GPU set; macOS: drop vaapi/amf/vpl/mfx/vulkan/nv/cuda, add videotoolbox;
#     Windows: full set, native msys2 paths)
# 4. make -j$NPROC; make install
# 5. post_process_install rewrites @rpath / RUNPATH / etc — base infra handles it
# 6. assert_soname for all 8 majors: libavcodec.so.61, libavformat.so.61,
#    libavutil.so.59, libswscale.so.8, libswresample.so.5, libavfilter.so.10,
#    libpostproc.so.58, libavdevice.so.61
```

Special handling needed in `fetch-sources.sh` for **git source** (vs tarball):
- Add optional `git_url` + `git_ref` to deps.toml schema
- When `git_url` set, clone instead of curl; `sha256` can be a commit SHA pin
- Or: keep current tarball logic, just download a tagged tarball from github.com/jellyfin/jellyfin-ffmpeg/archive/...

GPU SDK headers (Wave D) need a similar git-based fetch (header-only repos, no tarball):
- https://github.com/FFmpeg/nv-codec-headers (tag `n12.1.14.0`)
- https://github.com/GPUOpen-LibrariesAndSDKs/AMF (master, copy `amf/public/include/` only)

## Main repo (P5) consumption plan

Once v1.1.0 lands, in `packages/rust-server/`:

```rust
// build.rs
fn main() {
    let libcommon = env::var("LIBCOMMON_PREFIX")
        .unwrap_or_else(|_| "/opt/tokimo-natives/install".into());
    println!("cargo:rustc-link-search=native={}/lib", libcommon);
    println!("cargo:rustc-link-arg=-Wl,-rpath,$ORIGIN/../natives/lib");
    // ffmpeg libs available transparently
}
```

Runtime: ship `install/lib/` next to the binary; tokimo-server adds
`$ORIGIN/../natives/lib` rpath at link time. No `LD_LIBRARY_PATH` needed.

Sidecar workers (`tokimo-perception-worker`): same pattern, they inherit
the natives tree.

## Budget

CI runs spent so far: **1 / 50** (this initial Wave A push).
Estimated burn for full v1.1.0:
- Wave A iterate: 3-5 runs (DLL name fixups)
- Wave B (6 GPL encoders): 6-10 runs (x265 cmake quirks, vpx/aom asm)
- Wave C (10 libs): 10-15 runs (libass freetype/fc detection; jxl new toolchain)
- Wave D (headers): 1-2 runs
- Wave E (ffmpeg): 5-10 runs (patches series fuzz, configure flag bugs)
- Wave F (verify): 1-2 runs

Total estimate: **26-44 / 50** — fits budget if Waves C/D stay simple.
If budget pressure, drop fdk-aac (non-free) + jxl + openmpt + chromaprint
from Wave C, defer to v1.1.x. Wave A+B+E = ~14-25 runs is the safe core.

## Next session pick-up

1. Wave A is green — manager review the diff on `ffmpeg-port` (commits `d08f84d`..`6fadf65`).
2. If approved → start Wave B: x264, x265, svt-av1, vpx, aom, theora.
3. Once v1.1.0 ready: bump `registry.toml` `[libcommon].version = "1.1.0"`,
   tag locally, **stop** and hand to manager for tag-push approval.

## Wave A — landed fixes (run-by-run)

| Run | SHA | Failure | Fix commit |
|-----|-----|---------|------------|
| 25849768721 | 911cda1 | linux: soxr CMake <3.5; macos+win: lame undefined `hip_*` | `c8ce79a` drop --disable-decoder, `05144ad` CMAKE_POLICY_VERSION_MINIMUM=3.5 |
| 25852292086 | 05144ad | linux: dav1d `-Wshorten-64-to-32`; macos+win: lame stale `lame_init_old` in .sym | `d123030` sed-strip lame_init_old, `3d5e8cb` sed-strip -Wshorten flag |
| 25854912954 | 3d5e8cb | linux: dav1d `nasm not found`; macos: soxr clang-16 implicit-decl; win: soxr DLL name | `acb3f7c` install nasm, `0cc3944` libsoxr.dll, `845b3cb` -Wno-error=implicit-decl |
| 25857379235 | 845b3cb | macos only: soxr SIMD32 undefined symbols on arm64 | `6fadf65` disable WITH_CR32S/CR64S/VR32S on macOS |
| **25859811868** | **6fadf65** | — | ✅ **all 3 platforms green** |

## CI budget

5 runs × 3 jobs = 15 jobs consumed of 50.

Remaining: 35 jobs ≈ 11 more iterations across Waves B/E. Wave C/D should be deferred if they consume more than 3 runs each.
