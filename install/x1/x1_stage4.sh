#!/bin/sh
# 3DWOX 1X, stage 4 of the port: our Klipper firmware on both UPC cores,
# LOOK ONLY (klipper/config/x1/x1_stage4.cfg defines no output).
# Run on the printer's own Linux as root, from the SD card:
#   sh /tmp/sd/stage/x1_stage4.sh start|status|stop
# "start" stops Sindoh's motion program (x1_stop.sh); only a reboot
# brings the stock firmware back. Nothing is written to the eMMC.
ROOT=/tmp/sd
ST=$ROOT/stage
U=$ST/bin/upctool
K=/home/klipper
inroot() { chroot $ROOT /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }
mounts() {
    grep -q " $ROOT/proc " /proc/mounts || mount -t proc proc $ROOT/proc
    grep -q " $ROOT/sys " /proc/mounts || mount -t sysfs sysfs $ROOT/sys
    if ! grep -q " $ROOT/dev " /proc/mounts; then
        mount -t tmpfs -o mode=755,size=512k dev $ROOT/dev
        mknod -m 666 $ROOT/dev/null c 1 3
        mknod -m 666 $ROOT/dev/zero c 1 5
        mknod -m 666 $ROOT/dev/full c 1 7
        mknod -m 666 $ROOT/dev/random c 1 8
        mknod -m 666 $ROOT/dev/urandom c 1 9
        mknod -m 666 $ROOT/dev/tty c 5 0
        mknod -m 666 $ROOT/dev/ptmx c 5 2
        mkdir -p $ROOT/dev/pts $ROOT/dev/shm
        ln -s /proc/self/fd $ROOT/dev/fd
    fi
    grep -q " $ROOT/dev/pts " /proc/mounts || mount -t devpts devpts $ROOT/dev/pts
    grep -q " $ROOT/dev/shm " /proc/mounts || mount -t tmpfs -o size=64m shm $ROOT/dev/shm
    # root-only devices for upctool (UPC cores, DTCM through /dev/mem)
    for d in upc0 upc1 mem; do [ -e $ROOT/dev/$d ] || cp -a /dev/$d $ROOT/dev/; done
}
case "$1" in
start)
    grep -q " $ROOT ext4 " /proc/mounts || { echo "mount the card at $ROOT first"; exit 1; }
    sh $ST/x1_stop.sh $U || exit 1
    mounts
    install -m 755 $U $ROOT/usr/local/bin/upctool
    mkdir -p $ROOT$K/printer_data/config $ROOT$K/printer_data/logs $ROOT$K/printer_data/comms
    cp $ST/x1_stage4.cfg $ROOT$K/printer_data/config/printer.cfg
    cp $ST/x1_query.py $ROOT$K/x1_query.py
    inroot chown -R klipper:klipper $K/printer_data $K/x1_query.py
    $U --force --dtcm 0xf9880000 load $ST/fw/klipper_x1_io.bin $ST/fw/klipper_x1_fm.bin || exit 1
    rm -f $ROOT/tmp/klipper_upc_fm $ROOT/tmp/klipper_upc_io
    inroot /usr/local/bin/upctool --force --dtcm 0xf9880000 bridge \
        -f /tmp/klipper_upc_fm -i /tmp/klipper_upc_io > $ROOT/tmp/bridge.log 2>&1 &
    sleep 2
    inroot su -s /bin/sh klipper -c "cd $K && exec $K/klippy-env/bin/python $K/klipper/klippy/klippy.py \
        $K/printer_data/config/printer.cfg -l $K/printer_data/logs/klippy.log \
        -a $K/printer_data/comms/klippy.sock" > $ROOT/tmp/klippy.out 2>&1 &
    echo "x1_stage4: started (give Klipper about 20 s, then: $0 status)"
    ;;
status)
    $U --dtcm 0xf9880000 info
    inroot su -s /bin/sh klipper -c "$K/klippy-env/bin/python $K/x1_query.py $K/printer_data/comms/klippy.sock"
    ;;
stop)
    for p in klippy.py "upctool --force --dtcm 0xf9880000 bridge"; do
        pid=$(ps | grep "$p" | grep -v grep | awk '{print $1}'); [ -n "$pid" ] && kill $pid
    done
    sleep 1
    $U --passive --force stop
    echo "x1_stage4: stopped, cores held. Reboot to get the stock firmware back."
    ;;
*)  echo "usage: $0 start|status|stop"; exit 1 ;;
esac
