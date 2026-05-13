#!/usr/bin/env bash
# icu 74.2 — tarball extracts to icu/source/. configure must run from source/
# (in-source build; ICU does not officially support out-of-tree). We then
# drop libicui18n (not in libcommon registry) and any non-lib outputs.
LIB_NAME="icu"
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

src="$(source_dir icu)"

# ICU's tarball top-level after our --strip-components=1 is `source/` directly.
src_root="${src}/source"
[[ -d "${src_root}" ]] || fatal "expected ICU source at ${src_root}"

log "configuring (in-source — ICU does not support out-of-tree)"
cd "${src_root}"
# Reset any prior state in case of re-runs.
make distclean 2>/dev/null || true

icu_platform="Linux"
if is_macos; then
  icu_platform="MacOSX"
elif is_windows; then
  icu_platform="MinGW"
fi

CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" LDFLAGS="${LDFLAGS}" \
  ./runConfigureICU "${icu_platform}" \
    --prefix="${INSTALL_DIR}" \
    --libdir="${INSTALL_DIR}/lib" \
    --enable-shared \
    --disable-static \
    --disable-tests \
    --disable-samples \
    --disable-extras

log "building (this takes a few minutes)"
make -j"${NPROC}"

log "installing"
make install

# Drop libicui18n: not in libcommon registry; would trigger 'extra soname' in
# verify.sh. Also delete the related pkg-config & cmake bits.
rm -f "${INSTALL_DIR}/lib"/libicui18n.* 2>/dev/null || true
drop_lib libicui18n
drop_pc icu-i18n
drop_pc icu-io 2>/dev/null || true
rm -f "${INSTALL_DIR}/lib/pkgconfig/icu-io.pc" 2>/dev/null || true
# Drop libicuio / libicutest / libicutu — not in registry.
drop_lib libicuio
drop_lib libicutest
drop_lib libicutu
# Keep registry-listed icudata + icuuc only. Drop ICU's bin/sbin tools.
rm -rf "${INSTALL_DIR}/sbin" 2>/dev/null || true
for tool in icuinfo icuexportdata makeconv genccode genbrk gencfu gencnval \
            gendict genrb genuca makeconv pkgdata uconv derb; do
  rm -f "${INSTALL_DIR}/bin/${tool}" 2>/dev/null || true
done

log "post-processing"
post_process_install

assert_soname "libicudata.so.74"
assert_soname "libicuuc.so.74"
log "done"
