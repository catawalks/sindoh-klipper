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
# the Debian root: the installed copy when there is one, else the SD card
ROOT=$X1_ROOT
[ -n "$ROOT" ] || { ROOT=/tmp/sd; [ -x /userdata/klipper/root/usr/bin/python3 ] && ROOT=/userdata/klipper/root; }
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
# Cold start only (no Sindoh program has run since power-on): the output
# pins. Sindoh's motion program makes these SoC GPIOs outputs at its
# start; our firmware only sets levels (src/upc/gpio.c), so without this
# the motor drivers are never enabled and nothing moves (found on the
# first cold start, 2026-11-27: "No trigger after full movement" with
# the head standing still). The table is the difference between a cold
# start and the normal takeover, both idle under Klipper with the same
# config, read from the GPIO block on the owner's 1X that day: per bank,
# the new outputs and their level. They are the driver enables (high =
# off), step and direction lines, the microstep pins, and (names from
# Sindoh's motion program and microcode, sindoh docs/1x.md):
#   127 PSU fan enable, 112 back left exhaust fan, 188 hot end fan,
#   153 level sensor enable (all four are in x1_printer.cfg);
#   69  "nozzle voltage on" (high whenever stock runs);
#   148, 191 the press clutch;  107 the motion program's test pin;
#   53, 96  driver enables of two motor slots a 1X does not have;
#   225 the second hot end fan (2X);  174, 177 made outputs, never
#   written;  156 set high once at start, use not known.
# Level, direction, level again.
#        bank  outputs     high        low
COLD_PINS="1 0x073c71c0 0x05345140 0x02082080
2 0x00000020 0x00000020 0x00000000
3 0x80010831 0x80000021 0x00010810
4 0x12100000 0x10000000 0x02100000
5 0x90025c70 0x10001450 0x80024820
6 0x000033de 0x00002294 0x0000114a
7 0x00000002 0x00000002 0x00000000"
cold_pins() {
    echo "$COLD_PINS" | while read b out hi lo; do
        base=$((0xd4019000 + b * 256))
        reg() { printf "0x%x" $((base + $1)); }
        devmem $(reg 0x08) 32 $hi; devmem $(reg 0x0c) 32 $lo
        devmem $(reg 0x1c) 32 $out
        devmem $(reg 0x08) 32 $hi; devmem $(reg 0x0c) 32 $lo
        dir=$(devmem $(reg 0x04)); lvl=$(devmem $(reg 0x00))
        [ $(( dir & out )) -eq $(( out )) ] && [ $(( lvl & out )) -eq $(( hi )) ] ||
            echo "x1_stage4: bank $b pins not as set (direction $dir, levels $lvl)"
    done
}
case "$1" in
start)
    # (the card is a mount of its own; an installed root is a folder on /userdata)
    [ -x $ROOT/usr/bin/python3 ] || { echo "no Debian root at $ROOT (card not mounted?)"; exit 1; }
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
    # Motor drivers: set up by the stock program at boot (look only), or
    # by us on a start without it.
    # (the stock system has no Python: the card's, with the UART node)
    [ -e $ROOT/dev/ttyS2 ] || cp -a /dev/ttyS2 $ROOT/dev/
    if [ -e /tmp/x1_cold ]; then        # cold start (x1_hook.sh): we write the set-up
        cold_pins
        inroot /usr/bin/python3 /stage/x1_tmc.py setup --yes > /tmp/x1_tmc.log 2>&1
        rc=$?
        cat /tmp/x1_tmc.log
        [ $rc -eq 0 ] || { echo "x1_stage4: motor driver set-up failed, not starting"; exit 1; }
    else
        [ -f $ST/x1_tmc.py ] && inroot /usr/bin/python3 /stage/x1_tmc.py check | tail -1
    fi
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
