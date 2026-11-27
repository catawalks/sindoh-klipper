#!/bin/sh
# 3DWOX 1X: what runs at every boot once the hook is installed
# (docs/1x_install_plan.md). Installed as /userdata/klipper/boot.sh and
# started in the background by /etc/init.d/S99klipper.
#
# 1. SSH, always (also when stock is chosen with BOOT_STOCK, so there is
#    a way in without the serial cable): the printer's own dropbear on
#    port 2222, key login only. The host key is kept in
#    $BASE/ssh/host_ecdsa, so it stays the same across boots; the public
#    key allowed in is $BASE/ssh/authorized_keys (no file, no SSH).
#    Root's home is covered by a RAM copy that holds the key; the real
#    /root is not changed.
# 2. Our system: the Debian root is $BASE/root when installed there,
#    otherwise the SD card (mounted at /tmp/sd). Its stage/x1_boot.sh
#    then waits for stock's motion program and takes over.
#
# It does nothing more when $BASE/BOOT_STOCK exists, when neither root
# is there, or when x1_boot.sh finds a reason not to start (see there):
# the printer stays a stock printer.
#   sh boot.sh [dry]       dry: x1_boot.sh only says what it would do
# For tests: X1_BASE (default /userdata/klipper), X1_SSH_PORT (2222).
export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH
BASE=${X1_BASE:-/userdata/klipper}
PORT=${X1_SSH_PORT:-2222}
W=/tmp/x1_ssh
LOG=/tmp/x1_hook.log
CARD=/dev/mmcblk1p1
say() { echo "x1_hook: $*"; echo "x1_hook: $*" >> $LOG; }

: > $LOG
say "$(date) uptime $(cut -d' ' -f1 /proc/uptime)"
[ "$(cat /sys/kernel/board_name 2>/dev/null)" = 1X_r1 ] || { say "not a 1X_r1 board"; exit 0; }

ssh_start() {
    K=$BASE/ssh
    [ -s $K/authorized_keys ] || { say "no $K/authorized_keys: SSH not started"; return; }
    [ -x /usr/sbin/dropbear ] || { say "no dropbear on this printer"; return; }
    mkdir -p $W
    if [ -f $W/dropbear.pid ] && kill -0 "$(cat $W/dropbear.pid)" 2>/dev/null; then
        say "SSH already running"; return
    fi
    [ -f $K/host_ecdsa ] || dropbearkey -t ecdsa -s 256 -f $K/host_ecdsa >> $LOG 2>&1
    if ! grep -q " /root " /proc/mounts; then
        rm -rf $W/root; mkdir -p $W/root
        cp -a /root/. $W/root/ 2>/dev/null
        mkdir -p $W/root/.ssh
        cp $K/authorized_keys $W/root/.ssh/authorized_keys
        chmod 700 $W/root $W/root/.ssh; chmod 600 $W/root/.ssh/authorized_keys
        mount --bind $W/root /root || { say "could not cover /root"; return; }
    fi
    setsid dropbear -r $K/host_ecdsa -p $PORT -s -P $W/dropbear.pid < /dev/null > /dev/null 2>&1 &
    sleep 2
    if [ -f $W/dropbear.pid ] && kill -0 "$(cat $W/dropbear.pid)" 2>/dev/null; then
        say "SSH on port $PORT"
    else
        say "dropbear did not start"
    fi
}
ssh_start

[ -e $BASE/BOOT_STOCK ] && { say "$BASE/BOOT_STOCK is set: stock boot"; exit 0; }
if [ -x $BASE/root/usr/bin/python3 ]; then
    ROOT=$BASE/root
else
    ROOT=/tmp/sd
    n=0
    while [ ! -b $CARD ]; do
        n=$((n+1)); [ $n -gt 60 ] && { say "no installed root and no SD card: stock boot"; exit 0; }
        sleep 1
    done
    mkdir -p $ROOT
    grep -q " $ROOT ext4 " /proc/mounts || mount -t ext4 $CARD $ROOT >> $LOG 2>&1 ||
        { say "could not mount $CARD: stock boot"; exit 0; }
fi
[ -f $ROOT/stage/x1_boot.sh ] || { say "no stage/x1_boot.sh in $ROOT: stock boot"; exit 0; }
say "root: $ROOT"
X1_BASE=$BASE X1_ROOT=$ROOT sh $ROOT/stage/x1_boot.sh $1 >> $LOG 2>&1
say "x1_boot.sh ended ($?), its log: /tmp/x1_boot.log"
