#!/bin/sh
# 1X port, stage 1 (docs/1x_port_plan.md): a Debian (trixie, armhf) root
# with Klipper, Moonraker and Mainsail on the SD card in the 1X's slot.
# Nothing is started and no printer hardware is touched; the 1X's own eMMC
# is not written (the card is mounted in /tmp, logs go to the card).
#
# Run from the 1X's stock root shell, printer online, clock set:
#   mount -t ext4 /dev/mmcblk1p1 /tmp/sd
#   sh build_root_1x.sh /tmp/sd/stage/rootfs.tar.gz
# rootfs.tar.gz: the official Debian trixie arm32v7 base
#   (debuerreotype/docker-debian-artifacts, branch dist-arm32v7,
#   trixie/oci/blobs/rootfs.tar.gz; sha256 checked on the PC).
# Next to this script: inside_1x.sh, FORK, mainsail (nginx site),
# moonraker.conf. Re-running continues where it stopped.
ROOT=${ROOT:-/tmp/sd}
ROOTFS=$1
HERE=$(cd "$(dirname "$0")" && pwd)

[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ "$(date +%Y)" -ge 2025 ] || { echo "set the clock first"; exit 1; }
grep -q " $ROOT ext4 " /proc/mounts || { echo "$ROOT is not a mounted ext4 card"; exit 1; }
case "$(awk -v m=$ROOT '$2 == m {print $1}' /proc/mounts)" in
/dev/mmcblk1*) ;;
*) echo "$ROOT is not the SD card (mmcblk1): refusing"; exit 1 ;;
esac

echo "== 1. Debian base"
if [ ! -x $ROOT/usr/bin/apt-get ]; then
    [ -f "$ROOTFS" ] || { echo "missing $ROOTFS"; exit 1; }
    tar -xzf "$ROOTFS" -C $ROOT || exit 1
fi
[ -x $ROOT/usr/bin/apt-get ] || { echo "extract failed"; exit 1; }

echo "== 2. chroot mounts (its own small /dev: no printer devices in it)"
x1_mounts() {
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
}
x1_umounts() {
    for m in dev/shm dev/pts dev sys proc; do
        grep -q " $ROOT/$m " /proc/mounts && umount $ROOT/$m
    done
}
trap x1_umounts EXIT
x1_mounts
cp /etc/resolv.conf $ROOT/etc/resolv.conf
# no daemon may start from a package's install script (nginx, dbus ...)
printf '#!/bin/sh\nexit 101\n' > $ROOT/usr/sbin/policy-rc.d
chmod 755 $ROOT/usr/sbin/policy-rc.d

mkdir -p $ROOT/usr/src/x1
cp $HERE/inside_1x.sh $HERE/FORK $HERE/mainsail $HERE/moonraker.conf $ROOT/usr/src/x1/

echo "== 3..6 inside the chroot"
chroot $ROOT /usr/bin/env -i HOME=/root TERM=dumb \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 \
    /bin/bash /usr/src/x1/inside_1x.sh
rc=$?
sync
echo "== build_root_1x: exit $rc; card: $(df -k $ROOT | awk 'END {print int($4 / 1024)}') MB free"
exit $rc
