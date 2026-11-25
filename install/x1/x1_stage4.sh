#!/bin/sh
# 3DWOX 1X, stage 4 of the port: our Klipper firmware on both UPC cores,
# LOOK ONLY (klipper/config/x1/bringup/x1_stage4.cfg defines no output).
# Run on the printer's own Linux as root, from the SD card:
#   sh /tmp/sd/stage/x1_stage4.sh start [CONFIG]|status|stop
# With X1_PC=<the PC's address> in the environment, "start" also keeps a
# route to it so the PC can send the emergency stop:
#   curl -m 3 http://PRINTER:7126/
# CONFIG is a file next to this script (default x1_stage4.cfg, look only).
# The real config: "start printer.cfg" (with x1_printer.cfg and
# x1_macros.cfg next to it; klipper/config/x1/ in the repo).
# "start" stops Sindoh's motion program (x1_stop.sh); only a reboot
# brings the stock firmware back. Nothing is written to the eMMC.
# A shell over SSH (dropbear) has only /usr/bin:/bin: chroot, ip and
# killall are in the sbin folders (1X 2026-11-24).
export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH
ROOT=${X1_ROOT:-/tmp/sd}      # the Debian root: the SD card, or the installed copy
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
    CFG=${2:-x1_stage4.cfg}
    [ -f $ST/$CFG ] || { echo "no $ST/$CFG"; exit 1; }
    C=$ROOT$K/printer_data/config
    # The real config is three files, as on the DP200: printer.cfg (the
    # owner's: kept once it is there, SAVE_CONFIG writes into it) and the
    # two includes, replaced at every start. Any other CONFIG is a test
    # config and replaces printer.cfg.
    for f in x1_printer.cfg x1_macros.cfg; do [ -f $ST/$f ] && cp $ST/$f $C/; done
    if [ "$CFG" = printer.cfg ] && grep -q "include x1_printer.cfg" $C/printer.cfg 2>/dev/null; then
        echo "x1_stage4: keeping the printer.cfg already there"
    else
        [ -f $C/printer.cfg ] && grep -q "include x1_printer.cfg" $C/printer.cfg && cp $C/printer.cfg $C/printer.cfg.kept
        cp $ST/$CFG $C/printer.cfg
    fi
    # Motor drivers: set up by the stock program at boot. Look only; on a
    # start without it: chroot $ROOT /usr/bin/python3 /stage/x1_tmc.py setup --yes
    # (the stock system has no Python: the card's, with the UART node)
    [ -e $ROOT/dev/ttyS2 ] || cp -a /dev/ttyS2 $ROOT/dev/
    [ -f $ST/x1_tmc.py ] && inroot /usr/bin/python3 /stage/x1_tmc.py check | tail -1
    cp $ST/x1_query.py $ST/x1_gcode.py $ST/x1_estopd.py $ROOT$K/
    inroot chown -R klipper:klipper $K/printer_data $K/x1_query.py $K/x1_gcode.py $K/x1_estopd.py
    $U --force --dtcm 0xf9880000 load $ST/fw/klipper_x1_io.bin $ST/fw/klipper_x1_fm.bin || exit 1
    rm -f $ROOT/tmp/klipper_upc_fm $ROOT/tmp/klipper_upc_io
    inroot /usr/local/bin/upctool --force --dtcm 0xf9880000 bridge \
        -f /tmp/klipper_upc_fm -i /tmp/klipper_upc_io > $ROOT/tmp/bridge.log 2>&1 &
    sleep 2
    inroot su -s /bin/sh klipper -c "cd $K && exec $K/klippy-env/bin/python $K/klipper/klippy/klippy.py \
        $K/printer_data/config/printer.cfg -l $K/printer_data/logs/klippy.log \
        -a $K/printer_data/comms/klippy.sock" > $ROOT/tmp/klippy.out 2>&1 &
    # Emergency stop over the network: any connection to port 7126 shuts
    # Klipper down (motors stop, heaters off). X1_PC is the dev PC; the
    # printer has two ports on one network, so answers to it are pinned
    # to the wired one while Klipper runs.
    if [ -n "$X1_PC" ]; then
        ETH=$(ip -4 addr show eth0 | awk '/inet /{sub("/.*","",$2); print $2}')
        [ -n "$ETH" ] && ip route replace $X1_PC/32 dev eth0 src $ETH
    fi
    inroot su -s /bin/sh klipper -c "exec $K/klippy-env/bin/python $K/x1_estopd.py         $K/printer_data/comms/klippy.sock 7126" > $ROOT/tmp/estopd.log 2>&1 &
    echo "x1_stage4: started (give Klipper about 20 s, then: $0 status)"
    ;;
status)
    $U --dtcm 0xf9880000 info
    inroot su -s /bin/sh klipper -c "$K/klippy-env/bin/python $K/x1_query.py $K/printer_data/comms/klippy.sock"
    ;;
stop)
    [ -n "$X1_PC" ] && ip route del $X1_PC/32 2>/dev/null
    for p in klippy.py x1_estopd.py "upctool --force --dtcm 0xf9880000 bridge"; do
        pid=$(ps | grep "$p" | grep -v grep | awk '{print $1}'); [ -n "$pid" ] && kill $pid
    done
    sleep 1
    $U --passive --force stop
    echo "x1_stage4: stopped, cores held. Reboot to get the stock firmware back."
    ;;
*)  echo "usage: $0 start|status|stop"; exit 1 ;;
esac
