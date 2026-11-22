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
ROOT=/tmp/sd
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
    cp /tmp/sd/stage/x1_moonraker.conf $ROOT$K/printer_data/config/moonraker.conf
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
    screen_start
    echo "x1_web: started. Page on port $PORT, Moonraker on 7125 (give it about 30 s)"
    ;;
status)
    for p in moonraker.py "nginx: master" dp200_screen.py; do
        [ -n "$(pids "$p")" ] && echo "$p: running" || echo "$p: not running"
    done
    ;;
screen)
    screen_stop; screen_start ;;
stop)
    screen_stop
    inroot /usr/sbin/nginx -c $CONF -s quit 2>/dev/null
    for p in $(pids moonraker.py); do kill $p; done
    for p in $(pidof ustreamer); do kill $p; done
    sleep 2
    echo "x1_web: stopped"
    ;;
*)  echo "usage: $0 start|status|stop|screen"; exit 1 ;;
esac
