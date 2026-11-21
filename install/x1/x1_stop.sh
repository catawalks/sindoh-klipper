#!/bin/sh
# 3DWOX 1X: stop Sindoh's motion program and take the UPC cores, with the
# heater outputs OFF. Run on the printer's own Linux (BusyBox), as root.
#   sh x1_stop.sh /path/to/upctool
# The stock firmware keeps nozzle and bed warm at idle, its microcode goes
# on heating when the Linux program is gone, and holding the cores freezes
# every PWM output as it is. So: stop the program, hold the cores, then
# stop the three heater-type PWM blocks (5, 25, 28: period 1000) and check.
# Only a reboot brings the stock firmware back.
UPCTOOL=${1:?usage: x1_stop.sh /path/to/upctool}
ELF=marvell_lspsdk_3dp_granite2-debug_stripped.elf
HEATERS="0xf9304500 0xf9305900 0xf9305c00"
[ -f /sys/kernel/board_name ] || { echo "x1_stop: not a 1X/2X board"; exit 1; }
[ "$(cat /sys/kernel/watchdog_reason 2>/dev/null)" = 1 ] && { echo "x1_stop: recovery boot is pending, not touching anything"; exit 1; }
pid=$(pidof $ELF)
if [ -n "$pid" ]; then
    kill -TERM $pid
    n=0
    while [ -n "$(pidof $ELF)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done
    [ -n "$(pidof $ELF)" ] && { echo "x1_stop: the stock program did not stop"; exit 1; }
fi
# (the stopped program stays as a zombie under UIManager, hence --force)
$UPCTOOL --passive --force stop || { echo "x1_stop: could not hold the UPC cores"; exit 1; }
rc=0
for a in $HEATERS; do
    v=$(devmem $a)
    devmem $a 32 $(( v & ~5 ))
    r=$(devmem $a)
    echo "x1_stop: PWM $a $v -> $r"
    [ $(( r & 5 )) -eq 0 ] || rc=1
done
[ $rc -eq 0 ] && echo "x1_stop: cores held, heater outputs off" || echo "x1_stop: A HEATER OUTPUT IS STILL ON - reboot or power off"
exit $rc
