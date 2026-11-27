#!/bin/sh
# 3DWOX 1X: start our system at boot ("warm takeover", docs/1x_install_plan.md).
# Started in the background by /etc/init.d/S99klipper (install/x1/S99klipper).
# Stock boots as always; once its motion program is up, this does what is
# done by hand today: x1_stage4.sh start (stops the motion program, holds
# the UPC cores, checks the heaters, loads our firmware) and x1_web.sh
# start (Moonraker, Mainsail, camera, screen app, power button).
#
# It does NOTHING, and the printer stays a stock printer, when:
#   - $BASE/BOOT_STOCK exists (the way back to stock),
#   - a Sindoh update is unfinished (/updating_usb, /updating_network),
#   - a USB stick with _update_rodin_1x is in (Sindoh is updating),
#   - our root or scripts are missing,
#   - the motion program does not come up within 3 minutes.
#   sh x1_boot.sh [dry]      dry: only say what it would do
BASE=${X1_BASE:-/userdata/klipper}
ROOT=${X1_ROOT:-$BASE/root}     # the SD card when x1_hook.sh found no installed root
ST=$ROOT/stage
ELF=marvell_lspsdk_3dp_granite2-debug_stripped.elf
LOG=/tmp/x1_boot.log
DRY=$1
say() { echo "x1_boot: $*"; echo "x1_boot: $*" >> $LOG; }
skip() { say "not starting: $*"; exit 0; }

: > $LOG
say "$(date) uptime $(cut -d' ' -f1 /proc/uptime)"
[ "$(cat /sys/kernel/board_name 2>/dev/null)" = 1X_r1 ] || skip "not a 1X_r1 board"
[ -e $BASE/BOOT_STOCK ] && skip "$BASE/BOOT_STOCK is set (stock boot chosen)"
for f in /updating_usb /updating_network; do [ -e $f ] && skip "Sindoh update unfinished ($f)"; done
for f in x1_stage4.sh x1_web.sh x1_stop.sh bin/upctool; do
    [ -e $ST/$f ] || skip "$ST/$f missing"
done
[ -x $ROOT/usr/bin/python3 ] || skip "no Debian root at $ROOT"

if [ -e /tmp/x1_cold ]; then
    # cold start (x1_hook.sh covered /run.sh): Sindoh's programs were
    # never started, so there is nothing to wait for; x1_stage4.sh sets
    # up the pins and the motor drivers itself
    say "cold start"
else
# wait for stock's motion program and its start-up ("IO Ready" on the
# console; the program then switches the heaters on): up to 3 min
n=0
while [ -z "$(pidof $ELF)" ]; do
    n=$((n+1)); [ $n -gt 180 ] && skip "the motion program did not start in 3 min"
    sleep 1
done
say "motion program up after $n s"
sleep 20
fi
# a Sindoh update stick: stock's own programs handle it
for m in /mnt/sda1 /mnt/sdb1 /mnt/sd; do
    [ -d $m/_update_rodin_1x ] && skip "Sindoh update stick in ($m)"
done
[ -n "$DRY" ] && skip "dry run: would start x1_stage4.sh and x1_web.sh from $ROOT"

export X1_ROOT=$ROOT
say "starting Klipper"
if ! sh $ST/x1_stage4.sh start printer.cfg >> $LOG 2>&1; then
    # a cold start that fails is not tried again at the next boot
    [ -e /tmp/x1_cold ] && { touch $BASE/COLD_FAILED; sync; }
    skip "x1_stage4.sh failed (see above); stock's programs are not running: reboot for stock"
fi
say "starting the web side"
sh $ST/x1_web.sh start >> $LOG 2>&1
say "done"
