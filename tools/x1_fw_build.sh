#!/bin/sh
# Build the 1X firmware (fm, io) from a fork commit in WSL.
#   sh x1_fw_build.sh COMMIT OUTDIR
set -e
C=${1:?commit}; OUT=${2:?outdir}
export PATH=$HOME/armtc/arm-gnu-toolchain-14.2.rel1-x86_64-arm-none-eabi/bin:$PATH
B=$(mktemp -d /tmp/kfwx.XXXXXX)
git clone -q --no-checkout /mnt/c/Users/temp.DESKTOP-L41KPL5/klipper $B/k
cd $B/k
git -c advice.detachedHead=false checkout -q $C
git fetch -q --tags /mnt/c/Users/temp.DESKTOP-L41KPL5/klipper 2>/dev/null || true
mkdir -p $OUT
for core in fm io; do
    make clean >/dev/null
    cp config/x1_$core.config .config
    make olddefconfig >/dev/null
    make >/dev/null
    cp out/klipper.bin $OUT/klipper_x1_$core.bin
    echo "$core: $(grep -a -o 'v[0-9][^ ]*sindoh[^ ]*\|sindoh-[^ ]*' out/klipper.bin | head -1) $(wc -c < out/klipper.bin) bytes"
done
md5sum $OUT/*.bin
echo "build dir left in $B"
