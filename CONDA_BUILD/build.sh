#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# 0) Setup
# ---------------------------
git submodule update --init --recursive
bash patches/apply_patches.sh

echo "CC=${CC:-}"
echo "CXX=${CXX:-}"
echo "PREFIX=${PREFIX:-}"
echo "CPU_COUNT=${CPU_COUNT:-}"

# ---------------------------
# Global flags / paths
# ---------------------------
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig:${PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"

# Add include/lib paths + kseq guard everywhere
export CPPFLAGS="-DHTSLIB_KSEQ_H -I${PREFIX}/include ${CPPFLAGS:-}"
export CFLAGS="-DHTSLIB_KSEQ_H -I${PREFIX}/include ${CFLAGS:-}"
export CXXFLAGS="-DHTSLIB_KSEQ_H -I${PREFIX}/include ${CXXFLAGS:-}"
export LDFLAGS="-L${PREFIX}/lib ${LDFLAGS:-}"

# ---------------------------
# 1) Build & install htslib
# ---------------------------
pushd rnaseqc/SeqLib/htslib

# Bootstrap configure if needed
if [ ! -f ./configure ]; then
  if [ -f ./autogen.sh ]; then
    bash ./autogen.sh
  else
    autoreconf -fi
  fi
fi

./configure --prefix="${PREFIX}" \
  CPPFLAGS="${CPPFLAGS}" \
  LDFLAGS="${LDFLAGS}" \
  --with-bzip2 \
  --with-lzma \
  --enable-libcurl

make -j"${CPU_COUNT}"
make install

popd

# ---------------------------
# 2) Build & install SeqLib
# ---------------------------
pushd rnaseqc/SeqLib

./configure --prefix="${PREFIX}" \
  CPPFLAGS="${CPPFLAGS}" \
  LDFLAGS="${LDFLAGS}"

make -j"${CPU_COUNT}" \
  CXX="${CXX}" \
  CXXFLAGS="-std=c++14 -D_GLIBCXX_USE_CXX11_ABI=1 ${CXXFLAGS}" \
  LDFLAGS="${LDFLAGS}"

make install
popd

# ---------------------------
# 3) Build RNA-SeQC static library
# ---------------------------
pushd rnaseqc

# Explicitly override INCLUDE_DIRS and CFLAGS to include the Conda prefix
make lib -j"${CPU_COUNT}" \
  ABI=1 \
  CXX="${CXX}" \
  INCLUDE_DIRS="-I${PREFIX}/include -ISeqLib -ISeqLib/htslib/" \
  CFLAGS="-Wall -std=c++14 -D_GLIBCXX_USE_CXX11_ABI=1 -O3 -I${PREFIX}/include"

popd

# ---------------------------
# 4) Build scrinvex (compile + link explicitly)
# ---------------------------

# Compile scrinvex.cpp with the Boost path
"${CXX}" -c -o src/scrinvex.o src/scrinvex.cpp \
  -std=c++14 -D_GLIBCXX_USE_CXX11_ABI=1 -O3 \
  -DHTSLIB_KSEQ_H \
  -I. \
  -I"${PREFIX}/include" \
  -Irnaseqc -Irnaseqc/src \
  -Irnaseqc/SeqLib -Irnaseqc/SeqLib/htslib

# Link (Use the static libs created in previous steps)
"${CXX}" -o scrinvex src/scrinvex.o \
  rnaseqc/rnaseqc.a \
  rnaseqc/SeqLib/lib/libseqlib.a \
  rnaseqc/SeqLib/htslib/libhts.a \
  -L"${PREFIX}/lib" \
  -lboost_filesystem -lboost_regex -lboost_system \
  -lcurl -lcrypto -ldeflate \
  -lz -llzma -lbz2 \
  -lpthread


# ---------------------------
# Install
# ---------------------------
install -d "${PREFIX}/bin"
install -m 0755 scrinvex "${PREFIX}/bin/scrinvex"
