#!/bin/sh
# 3DWOX 1X bring-up: Moonraker and the Mainsail web page next to the
# Klipper that install/x1/x1_stage4.sh started (same Debian root on the SD
# card). Run on the printer's own Linux as root:
#   sh /tmp/sd/stage/x1_web.sh start|status|stop|screen   (screen: restart the touch app)
# The page is on port 80 (owner 11-22): Sindoh's own web server
# (lighttpd, started once at boot by /test/run.sh) is stopped first; only
# a reboot brings it back. Its camera server is replaced too (webcam_start).
# Moonraker is on 7125.
# It also puts our touch screen app (install/display/dp200_screen.py,
# copied to the card's /usr/local/bin) on the panel. Sindoh's screen
# program is not killed, only frozen (SIGSTOP), so nothing restarts it
# and it keeps its state; "stop" lets it run again. Restarting it by
# hand left it stuck at "Booting" on 2026-11-20: never do that.
# Nothing is written to the eMMC; logs go to the card and /tmp.
# It also starts the power helper (powerd, below) for the touch screen's
# SHUT DOWN and REBOOT, and writes what SYSTEM -> INFO shows about the
# stock side. By hand: sh /tmp/sd/stage/x1_web.sh power reboot|poweroff [dry]
ROOT=/tmp/sd
ST=$ROOT/stage
RUN=$ROOT/run/dp200                # the screen app's /run/dp200 (on the card)
K=/home/klipper
PORT=80
CONF=/tmp/x1_nginx.conf            # inside the Debian root
inroot() { chroot $ROOT /usr/bin/env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root "$@"; }
pids() { ps | grep "$1" | grep -v grep | awk '{print $1}'; }
screen_start() {
    [ -f $ROOT/usr/local/bin/dp200_screen.py ] || { echo "no screen app on the card"; return; }
    [ -n "$(pids dp200_screen.py)" ] && return
    for p in $(pids /app/appBrowser); do kill -STOP $p; done
    mkdir -p $ROOT/dev/input $ROOT/etc/dp200
    [ -e $ROOT/dev/fb0 ] || cp -a /dev/fb0 $ROOT/dev/
    [ -e $ROOT/dev/input/event0 ] || cp -a /dev/input/event0 $ROOT/dev/input/
    inroot /bin/sh -c "while :; do /usr/bin/python3 /usr/local/bin/dp200_screen.py; sleep 3; done"         >> $ROOT/tmp/x1_screen.log 2>&1 &
    echo $! > /tmp/x1_screen.pid
}
# Camera: Sindoh's mjpg_streamer (YUYV, 5 fps, re-encoded on the CPU, and
# it only delivers frames while Sindoh's engine runs) is stopped and
# ustreamer passes the camera's own MJPEG through: 1280x720, up to 30 fps,
# about 0 % CPU. Same camera and same time32 shim as the DP200
# (install/camera/v4l2_time32_shim.c, built on the card). The flag file
# keeps Sindoh's /test/restart.sh from starting its server again.
webcam_start() {
    [ -x $ROOT/usr/bin/ustreamer ] && [ -f $ROOT/usr/local/lib/v4l2_time32_shim.so ] || { echo "no ustreamer or shim on the card: camera left as it is"; return; }
    [ -n "$(pidof ustreamer)" ] && return
    touch /tmp/mjpg_flag.txt
    for p in $(pidof mjpg_streamer); do kill -2 $p; done
    sleep 2
    [ -e $ROOT/dev/video0 ] || cp -a /dev/video0 $ROOT/dev/
    inroot chgrp video /dev/video0; chmod 660 $ROOT/dev/video0
    inroot su -s /bin/sh klipper -c "LD_PRELOAD=/usr/local/lib/v4l2_time32_shim.so exec /usr/bin/ustreamer         --device=/dev/video0 --format=MJPEG --encoder=HW --resolution=1280x720 --desired-fps=30         --device-timeout=5 --persistent --host=127.0.0.1 --port=8080" > /dev/null 2>&1 &
}
# Time zone: the one set on the stock screen. Stock links /etc/localtime
# to its zone file at every boot (from its database); the Debian root gets
# a copy of that file, so the touch screen's clock and the logs show the
# same local time as stock did. No zone names involved.
time_zone() {
    [ -e /etc/localtime ] || return
    rm -f $ROOT/etc/localtime
    cp -L /etc/localtime $ROOT/etc/localtime
}
# SYSTEM -> INFO: the stock side's part. /snapshot_version.sh is read as
# text, NEVER run (it writes the boot loader's settings). The database is
# only read.
stock_info() {
    mkdir -p $RUN
    fw=$(sed -n "s/.*echo '\(ROD[^']*\)'.*/\1/p" /snapshot_version.sh 2>/dev/null | head -n 1)
    tli=$(sqlite3 /app/nvram/karas.db 'select MachineTLI from INST_MACHINE' 2>/dev/null | head -n 1)
    sn=$(sqlite3 /app/nvram/karas.db 'select MachineSerialNo from INST_MACHINE' 2>/dev/null | head -n 1)
    { echo "kernel=$(uname -r)"; echo "firmware=$fw"; echo "model=$tli"; echo "serial=$sn"; } > $RUN/stock_info
}
# SHUT DOWN / REBOOT (touch screen, SYSTEM -> POWER). The screen app turns
# heaters and motors off through Klipper, draws its progress frames and
# writes "poweroff" or "reboot" to $RUN/power. powerd (this script, run
# from a copy in /tmp because the card gets unmounted) then stops our
# programs, holds the cores, checks the heater outputs (x1_stop.sh),
# unmounts the card and
#   reboot:   runs "reboot", as Sindoh's own tools do. The printer starts
#             Sindoh's firmware; Klipper has to be started again.
#   poweroff: does what Sindoh's power key program (/app/powerkeyd) does
#             on a button press: sync, remount read-only, 1 s, power
#             control output (GPIO 158) to 1, power off. Read from that
#             program 2026-11-22; NOT YET TRIED on a printer.
# "dry" as third word stops before that last step (the stack stays down).
POWER_GPIO=/sys/class/gpio/gpio158/value
power_do() {
    what=$1; dry=$2
    cd /
    say() { echo "x1_power: $*"; echo "x1_power: $*" > /dev/console 2>/dev/null; }
    frame() { [ -f /tmp/x1_shut/$1.fb ] && cat /tmp/x1_shut/$1.fb > /dev/fb0 2>/dev/null; }
    say "$what requested${dry:+ (dry run)}"
    n=0                             # the screen app's frames (in the card's /tmp)
    while [ ! -f $ROOT/tmp/dp200-shutdown/done.fb ] && [ $n -lt 5 ]; do sleep 1; n=$((n+1)); done
    rm -rf /tmp/x1_shut; mkdir -p /tmp/x1_shut
    cp $ROOT/tmp/dp200-shutdown/*.fb /tmp/x1_shut/ 2>/dev/null
    # the screen app goes first, so the frames stay up; Sindoh's screen
    # program stays frozen (its motion program is gone anyway)
    [ -f /tmp/x1_screen.pid ] && kill $(cat /tmp/x1_screen.pid) 2>/dev/null
    rm -f /tmp/x1_screen.pid
    for p in $(pids dp200_screen.py); do kill $p; done
    frame 1; say "web page and camera"
    inroot /usr/sbin/nginx -c $CONF -s quit 2>/dev/null
    for p in $(pidof ustreamer); do kill $p; done
    frame 2; say "Moonraker"
    for p in $(pids moonraker.py); do kill $p; done
    sleep 2
    frame 3; say "Klipper"
    sh $ST/x1_stage4.sh stop
    frame 4; say "heaters and motors"
    sh $ST/x1_stop.sh $ST/bin/upctool || say "HEATER CHECK FAILED - going on, the $what ends it"
    frame 5; say "saving files"
    rm -f $RUN/power.ok $RUN/power
    sync
    for m in dev/pts dev/shm dev sys proc; do umount $ROOT/$m 2>/dev/null; done
    umount $ROOT 2>/dev/null || { sleep 2; umount $ROOT 2>/dev/null; } || {
        # e.g. a console shell standing in a folder of the card
        mount -o remount,ro $ROOT 2>/dev/null
        grep -q " $ROOT ext4 ro" /proc/mounts && say "card busy: set read-only instead"             || say "card busy and still writable (synced; the $what remounts it)"
    }
    sync
    frame done
    if [ -n "$dry" ]; then say "dry run: stopping before the $what"; return 0; fi
    if [ "$what" = reboot ]; then
        say "reboot"
        reboot
        return 0
    fi
    say "power off"
    echo s > /proc/sysrq-trigger
    echo u > /proc/sysrq-trigger
    sleep 1
    echo 1 > $POWER_GPIO
    sleep 3
    poweroff -f                     # still here: the output did not cut the power
}
powerd_start() {
    [ -f /tmp/x1_powerd.pid ] && kill $(cat /tmp/x1_powerd.pid) 2>/dev/null
    cp $ST/x1_web.sh /tmp/x1_power.sh
    sh /tmp/x1_power.sh powerd > /tmp/x1_power.log 2>&1 &
}
powerd_stop() {
    [ -f /tmp/x1_powerd.pid ] && kill $(cat /tmp/x1_powerd.pid) 2>/dev/null
    rm -f /tmp/x1_powerd.pid $RUN/power.ok
}
screen_stop() {
    [ -f /tmp/x1_screen.pid ] && kill $(cat /tmp/x1_screen.pid) 2>/dev/null
    rm -f /tmp/x1_screen.pid
    for p in $(pids dp200_screen.py); do kill $p; done
    for p in $(pids /app/appBrowser); do kill -CONT $p; done
}
case "$1" in
start)
    grep -q " $ROOT/proc " /proc/mounts || { echo "start Klipper first (x1_stage4.sh start)"; exit 1; }
    [ -n "$(pids moonraker.py)" ] && { echo "already running"; exit 0; }
    for p in $(pids /sbin/lighttpd); do kill $p; done
    sleep 1
    mkdir -p $ROOT/var/log/nginx $ROOT/var/lib/nginx $ROOT/run
    time_zone
    stock_info
    cp /tmp/sd/stage/x1_moonraker.conf $ROOT$K/printer_data/config/moonraker.conf
    # Klipper (our fork) and Moonraker stay at the commits on the card:
    # Moonraker's updater only offers the web page (Mainsail)
    for r in klipper moonraker; do
        c=$(inroot su -s /bin/sh klipper -c "git -C $K/$r rev-parse HEAD" 2>/dev/null)
        [ ${#c} -eq 40 ] && printf '\n[update_manager %s]\npinned_commit: %s\n' $r $c >> $ROOT$K/printer_data/config/moonraker.conf
    done
    mkdir -p $ROOT$K/printer_data/gcodes
    inroot chown -R klipper:klipper $K/printer_data
    cat > $ROOT$CONF <<EOF
user www-data;
worker_processes 1;
pid /run/x1_nginx.pid;
error_log /var/log/nginx/error.log;
events { worker_connections 64; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log off;
    sendfile on;
    map \$http_upgrade \$connection_upgrade { default upgrade; '' close; }
    upstream moonraker { server 127.0.0.1:7125; }
    server {
        listen $PORT default_server;
        root $K/mainsail;
        index index.html;
        server_name _;
        client_max_body_size 0;
        location / { try_files \$uri \$uri/ /index.html; }
        location = /index.html { add_header Cache-Control "no-store, no-cache, must-revalidate"; }
        location /websocket {
            proxy_pass http://moonraker/websocket;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection \$connection_upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_read_timeout 86400;
        }
        location ~ ^/(printer|api|access|machine|server)/ {
            proxy_pass http://moonraker\$request_uri;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Scheme \$scheme;
        }
        location /webcam/ { proxy_pass http://127.0.0.1:8080/; proxy_buffering off; }
    }
}
EOF
    inroot su -s /bin/sh klipper -c "cd $K && exec $K/moonraker-env/bin/python \
        $K/moonraker/moonraker/moonraker.py -d $K/printer_data" > $ROOT/tmp/moonraker.out 2>&1 &
    inroot /usr/sbin/nginx -c $CONF
    webcam_start
    powerd_start
    screen_start
    echo "x1_web: started. Page on port $PORT, Moonraker on 7125 (give it about 30 s)"
    ;;
status)
    for p in moonraker.py "nginx: master" dp200_screen.py "x1_power.sh powerd"; do
        [ -n "$(pids "$p")" ] && echo "$p: running" || echo "$p: not running"
    done
    ;;
screen)
    screen_stop; time_zone; stock_info; screen_start ;;
powerd)                             # the loop behind SHUT DOWN / REBOOT (started by "start")
    cd /
    mkdir -p $RUN
    rm -f $RUN/power                # a request left on the card by an earlier run
    echo $$ > /tmp/x1_powerd.pid
    : > $RUN/power.ok
    while :; do
        if [ -f $RUN/power ]; then
            w=$(cat $RUN/power); rm -f $RUN/power
            case "$w" in poweroff|reboot) power_do $w; exit 0 ;; esac
        fi
        sleep 1
    done
    ;;
power)
    case "$2" in poweroff|reboot) power_do $2 $3 ;; *) echo "usage: $0 power reboot|poweroff [dry]"; exit 1 ;; esac
    ;;
stop)
    powerd_stop
    screen_stop
    inroot /usr/sbin/nginx -c $CONF -s quit 2>/dev/null
    for p in $(pids moonraker.py); do kill $p; done
    for p in $(pidof ustreamer); do kill $p; done
    sleep 2
    echo "x1_web: stopped"
    ;;
*)  echo "usage: $0 start|status|stop|screen|power reboot|poweroff [dry]"; exit 1 ;;
esac
