#!/usr/bin/env bash
# jellyfin-ffmpeg 7.0.2-7 — autotools-ish (custom configure). GPL-3.0
# when --enable-gpl --enable-version3, with non-free if fdk-aac enabled.
#
# We DO NOT enable --enable-libfdk-aac here (non-free). We DO enable
# --enable-gpl --enable-version3 since libx264/libx265/libvpx are linked.
#
# Patches: jellyfin-ffmpeg ships debian/patches/series with ~96 patches.
# Some are Debian-build-env-specific; we attempt them all with patch -p1
# and warn on failures rather than abort, so a single missing prereq
# (e.g. a packaging metadata patch) doesn't sink the whole build.
LIB_NAME="ffmpeg"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir jellyfin-ffmpeg)"
# ffmpeg requires an in-tree (not out-of-tree) configure on some hosts but
# supports out-of-tree — use out-of-tree to keep the source dir clean across
# patch applications.
build="$(prepare_build_dir ffmpeg)"

# ─── patch series application ──────────────────────────────────────────────
patch_series="${src}/debian/patches/series"
if [[ -f "${patch_series}" ]] && [[ ! -f "${src}/.libcommon-patches-applied" ]]; then
  log "applying jellyfin-ffmpeg debian patch series"
  pushd "${src}" >/dev/null
  applied=0
  skipped=0
  while IFS= read -r p; do
    # skip blank / comment lines
    [[ -z "$p" || "$p" =~ ^# ]] && continue
    patch_path="debian/patches/$p"
    if [[ ! -f "$patch_path" ]]; then
      log "  ✗ missing patch: $p (skip)"
      skipped=$((skipped + 1))
      continue
    fi
    if patch -p1 --dry-run --silent < "$patch_path" >/dev/null 2>&1; then
      patch -p1 --silent < "$patch_path"
      applied=$((applied + 1))
    else
      log "  ⚠ patch did not apply cleanly: $p (skip)"
      skipped=$((skipped + 1))
    fi
  done < "${patch_series}"
  log "patches applied=${applied} skipped=${skipped}"
  popd >/dev/null
  touch "${src}/.libcommon-patches-applied"
fi

# ─── pkg-config plumbing ───────────────────────────────────────────────────
# ffmpeg's configure uses pkg-config to discover deps. Point it at our
# install dir so it picks up L0…L10.
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export PKG_CONFIG_LIBDIR="${INSTALL_DIR}/lib/pkgconfig:${INSTALL_DIR}/lib64/pkgconfig"

# Help configure find our headers & libs even when pkg-config metadata is
# absent (nv-codec-headers / AMF).
extra_cflags="-I${INSTALL_DIR}/include"
extra_ldflags="-L${INSTALL_DIR}/lib"
if is_linux; then
  extra_ldflags="${extra_ldflags} -Wl,-rpath,\$ORIGIN"
fi

# ─── per-platform configure flags ──────────────────────────────────────────
common_flags=(
  --prefix="${INSTALL_DIR}"
  --libdir="${INSTALL_DIR}/lib"
  --enable-shared
  --disable-static
  --disable-doc
  --disable-htmlpages
  --disable-manpages
  --disable-podpages
  --disable-txtpages
  --enable-gpl
  --enable-version3
  --enable-pic
  # codecs / muxers via our L8/L9 libs
  --enable-libx264
  --enable-libx265
  --enable-libsvtav1
  --enable-libvpx
  --enable-libaom
  --enable-libtheora
  --enable-libdav1d
  --enable-libopus
  --enable-libmp3lame
  --enable-libvorbis
  --enable-libass
  --enable-libsrt
  --enable-libsoxr
  --enable-libzimg
  --enable-libbluray
  --extra-cflags="${extra_cflags}"
  --extra-ldflags="${extra_ldflags}"
)

linux_extras=(
  --shlibdir="${INSTALL_DIR}/lib"
  --enable-pthreads
  --enable-nvenc
  --enable-ffnvcodec
)

macos_extras=(
  --shlibdir="${INSTALL_DIR}/lib"
  --enable-pthreads
  --enable-videotoolbox
  --enable-audiotoolbox
  # vf_transpose_vt source is referenced by allfilters.c but its .o is
  # built only with the full jellyfin-ffmpeg metal/videotoolbox patches +
  # SDK setup that we don't replicate verbatim. Disable the filter so the
  # libavfilter linker step stops complaining about _ff_vf_transpose_vt.
  --disable-filter=transpose_vt
)

windows_extras=(
  # On Windows we want .dll files in install/bin alongside all deps so the
  # consumer's PATH resolves them. (Unix puts .so in lib; Windows puts .dll
  # in bin per ffmpeg/libtool/mingw convention.)
  --shlibdir="${INSTALL_DIR}/bin"
  --enable-w32threads
  --enable-d3d11va
  --enable-dxva2
  --enable-nvenc
  --enable-ffnvcodec
  --enable-amf
  --target-os=mingw32
  --arch=x86_64
)

log "configuring (jellyfin-ffmpeg 7.0.2-7)"
cd "${build}"
configure_rc=0
if is_linux; then
  "${src}/configure" "${common_flags[@]}" "${linux_extras[@]}" || configure_rc=$?
elif is_macos; then
  "${src}/configure" "${common_flags[@]}" "${macos_extras[@]}" || configure_rc=$?
elif is_windows; then
  "${src}/configure" "${common_flags[@]}" "${windows_extras[@]}" || configure_rc=$?
fi
if [[ ${configure_rc} -ne 0 ]]; then
  log "configure failed (rc=${configure_rc})"
  if [[ -f "${build}/ffbuild/config.log" ]]; then
    log "===== grep ERROR (with context) from ffbuild/config.log ====="
    grep -n -B3 -A10 -E "^ERROR:|cannot find|undefined reference|not found" "${build}/ffbuild/config.log" || true
    log "===== tail -n 400 of ffbuild/config.log ====="
    tail -n 400 "${build}/ffbuild/config.log" || true
  else
    log "ffbuild/config.log not found"
  fi
  exit "${configure_rc}"
fi

log "building (this is slow — ~10-20min)"
make -j"${NPROC}"

log "installing"
make install

log "post-processing"
post_process_install

# ─── SONAME assertions ─────────────────────────────────────────────────────
# These match what jellyfin-ffmpeg 7.0.2 (= ffmpeg n7.0.x) emits.
# On mingw, ffmpeg drops the "lib" prefix: libavcodec.so.61 → avcodec-61.dll.
if is_windows; then
  WINDOWS_DLL_OVERRIDE="avcodec-61.dll"    assert_soname "libavcodec.so.61"
  WINDOWS_DLL_OVERRIDE="avformat-61.dll"   assert_soname "libavformat.so.61"
  WINDOWS_DLL_OVERRIDE="avutil-59.dll"     assert_soname "libavutil.so.59"
  WINDOWS_DLL_OVERRIDE="avfilter-10.dll"   assert_soname "libavfilter.so.10"
  WINDOWS_DLL_OVERRIDE="swscale-8.dll"     assert_soname "libswscale.so.8"
  WINDOWS_DLL_OVERRIDE="swresample-5.dll"  assert_soname "libswresample.so.5"
  WINDOWS_DLL_OVERRIDE="postproc-58.dll"   assert_soname "libpostproc.so.58"
  WINDOWS_DLL_OVERRIDE="avdevice-61.dll"   assert_soname "libavdevice.so.61"
else
  assert_soname "libavcodec.so.61"
  assert_soname "libavformat.so.61"
  assert_soname "libavutil.so.59"
  assert_soname "libavfilter.so.10"
  assert_soname "libswscale.so.8"
  assert_soname "libswresample.so.5"
  assert_soname "libpostproc.so.58"
  assert_soname "libavdevice.so.61"
fi

log "done"
