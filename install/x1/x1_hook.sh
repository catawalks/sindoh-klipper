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
#    /root is not changed. Sessions are never login shells (a login
#    shell runs /etc/profile, and with it Sindoh's /run.sh, again).
# 2. Our system: the Debian root is $BASE/root when installed there,
#    otherwise the SD card (mounted at /tmp/sd). Its stage/x1_boot.sh
#    then waits for stock's motion program and takes over.
#
# It does nothing more when $BASE/BOOT_STOCK exists, when neither root
# is there, or when x1_boot.sh finds a reason not to start (see there):
# the printer stays a stock printer.
#
# Cold start (step B of the install plan, in test since 2026-11-27):
# "sh boot.sh early" is run by S99klipper BEFORE the console logs in
# (the login runs Sindoh's /run.sh, which starts its programs). With
# $BASE/BOOT_COLD_ONCE (removed at once: the next boot is a normal one)
# or $BASE/BOOT_COLD it covers /run.sh with a RAM copy (bind mount; no
# Sindoh file changes) that holds only the hardware set-up from Sindoh's
# own script: pins, upc_6270.ko, USB gadget, mdev, the two clocks.
# UIManager, the motion program, the screen program and the recovery
# checks are not started. The main part then stops after SSH and the
# root, for the steps by hand, unless $BASE/COLD_AUTO exists.
#   sh boot.sh [dry]       dry: x1_boot.sh only says what it would do
# For tests: X1_BASE (default /userdata/klipper), X1_SSH_PORT (2222).
export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH
BASE=${X1_BASE:-/userdata/klipper}
PORT=${X1_SSH_PORT:-2222}
W=/tmp/x1_ssh
LOG=/tmp/x1_hook.log
CARD=/dev/mmcblk1p1
say() { echo "x1_hook: $*"; echo "x1_hook: $*" >> $LOG; }


cold_early() {
    [ -e $BASE/BOOT_STOCK ] && return
    [ -e $BASE/BOOT_COLD_ONCE ] || [ -e $BASE/BOOT_COLD ] || return
    for f in /updating_usb /updating_network; do [ -e $f ] && { say "Sindoh update unfinished ($f): no cold start"; return; }; done
    if [ -e $BASE/BOOT_COLD_ONCE ]; then
        rm -f $BASE/BOOT_COLD_ONCE; sync
    else                            # every boot: only with a root to start
        [ -x $BASE/root/usr/bin/python3 ] || [ -b $CARD ] || { say "no root: no cold start"; return; }
    fi
    R=/tmp/x1_run_cold.sh
    {
        echo '#!/bin/sh'
        echo '# made at boot by x1_hook.sh from the hardware part of /run.sh'
        echo '[ -e /tmp/x1_cold_ready ] && exit 0     # a second login: nothing to do'
        sed -n '1,/^devmem 0xf9080148 /p' /run.sh
        echo 'echo stop_progress_bar > /proc/fb_ctrl'
        echo 'touch /tmp/x1_cold_ready'
        echo 'echo "x1: cold start, Sindoh programs not started (SSH port 2222, log /tmp/x1_hook.log)"'
    } > $R
    grep -q '^insmod /app/upc_6270.ko' $R && grep -q '^devmem 0xf9080148 ' $R && ! grep -q UIManager $R ||
        { say "/run.sh is not as expected: no cold start"; return; }
    chmod 755 $R
    mount --bind $R /run.sh || { say "could not cover /run.sh: no cold start"; return; }
    touch /tmp/x1_cold
    say "cold start: /run.sh covered, Sindoh's programs will not start"
}
if [ "$1" = early ]; then
    : > $LOG
    say "early $(date) uptime $(cut -d' ' -f1 /proc/uptime)"
    [ "$(cat /sys/kernel/board_name 2>/dev/null)" = 1X_r1 ] && cold_early
    exit 0
fi

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
        # Every key gets a forced command, so no SSH session is ever a
        # LOGIN shell: /etc/profile ends with /run.sh, which would start
        # Sindoh's programs a second time.
        cat > $W/shell.sh <<'EOS'
#!/bin/sh
export PATH=/usr/sbin:/sbin:/usr/bin:/bin
[ -n "$SSH_ORIGINAL_COMMAND" ] && exec /bin/sh -c "$SSH_ORIGINAL_COMMAND"
exec /bin/sh -i
EOS
        grep -v '^#' $K/authorized_keys | grep . |
            sed "s|^|command=\"/bin/sh $W/shell.sh\" |" > $W/root/.ssh/authorized_keys
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
say "$(date) uptime $(cut -d' ' -f1 /proc/uptime)"
[ "$(cat /sys/kernel/board_name 2>/dev/null)" = 1X_r1 ] || { say "not a 1X_r1 board"; exit 0; }
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
if [ -e /tmp/x1_cold ]; then
    n=0
    while [ ! -e /tmp/x1_cold_ready ]; do
        n=$((n+1)); [ $n -gt 120 ] && { say "cold start: the covered /run.sh did not finish in 2 min"; exit 0; }
        sleep 1
    done
    say "cold start: hardware set-up done after $n s"
    [ -e $BASE/COLD_AUTO ] || { say "cold start: stopping here for the steps by hand (no $BASE/COLD_AUTO)"; exit 0; }
    say "cold start: the automatic start is not written yet"
    exit 0
fi
X1_BASE=$BASE X1_ROOT=$ROOT sh $ROOT/stage/x1_boot.sh $1 >> $LOG 2>&1
say "x1_boot.sh ended ($?), its log: /tmp/x1_boot.log"
