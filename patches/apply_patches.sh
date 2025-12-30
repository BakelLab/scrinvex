#!/usr/bin/env bash
set -euo pipefail
git submodule update --init --recursive
( cd rnaseqc/SeqLib/bwa && git apply ../../../patches/bwa-rle.h.patch )
( cd rnaseqc/SeqLib/fermi-lite && git apply ../../../patches/fermi-lite-rle.h.patch )
