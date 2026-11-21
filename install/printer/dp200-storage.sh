# Optional G-code storage on a microSD card or USB stick (stick install on
# the stock kernel). Sourced by dp200-start.sh; needs $ROOT.
#
# Opt-in: the card or stick has a folder named "dp200_storage" at its top
# level. At boot its "gcodes" folder is mounted over Klipper's G-code
# folder; without such a card or stick nothing changes and G-code stays on
# the internal flash. The stock system mounts the SD card at /mnt/sd and a
# USB stick at /mnt/sda1 (/usr/sbin/media.connect); the card is tried first.
#
# Only at boot: a card or stick put in later is not used until the next
# start, and one that is in use must stay in while the printer is on.
#
# The mount sits inside /klipper, and removing Klipper deletes /klipper:
# dp200_storage_release (run by "dp200-start.sh stop", which the installer
# and the remover call first) must have unmounted it before that.
STORAGE_MARK=dp200_storage
PM=${DP200_PROC_MOUNTS:-/proc/mounts}
STORAGE_DIRS=${DP200_STORAGE_DIRS:-/mnt/sd /mnt/sda1}

dp200_storage_gcodes() { echo $ROOT/home/klipper/printer_data/gcodes; }

# "mountpoint device fstype" of the first card or stick that opted in
dp200_storage_pick() {
    for _mp in $STORAGE_DIRS; do
        _l=`awk -v m=$_mp '$2 == m {d = $1; t = $3} END {if (d != "") print d, t}' $PM`
        [ -n "$_l" ] || continue
        [ -d $_mp/$STORAGE_MARK ] || continue
        echo "$_mp $_l"
        return 0
    done
    return 1
}

dp200_storage_setup() {
    _g=`dp200_storage_gcodes`
    grep -q " $_g " $PM && { echo "storage: already mounted"; return 0; }
    # a card or stick that is present may still be on its way to a mount
    _i=0
    while [ $_i -lt 5 ]; do
        ls /sys/block 2>/dev/null | grep -q -e '^sd[a-z]$' -e '^mmcblk0$' || break
        dp200_storage_pick >/dev/null && break
        sleep 1
        _i=$((_i + 1))
    done
    set -- `dp200_storage_pick`
    [ $# = 3 ] || { echo "storage: internal flash (no card or stick with a $STORAGE_MARK folder)"; return 0; }
    _mp=$1; _dev=$2; _fs=$3
    _ids=`grep '^klipper:' $ROOT/etc/passwd | cut -d: -f3,4`
    _uid=${_ids%:*}; _gid=${_ids#*:}
    [ -n "$_uid" ] && [ -n "$_gid" ] || { echo "storage: no klipper user"; return 0; }
    case $_fs in
    vfat|msdos)
        # the stock mount is writable by root only: mount it for klipper
        umount $_mp || { echo "storage: $_mp is busy, not used"; return 0; }
        if ! mount -t vfat -o uid=$_uid,gid=$_gid,umask=002,iocharset=utf8 $_dev $_mp; then
            mount -t vfat -o iocharset=utf8 $_dev $_mp
            echo "storage: could not mount $_dev for klipper, not used"
            return 0
        fi
        mkdir -p $_mp/$STORAGE_MARK/gcodes
        ;;
    *)
        mkdir -p $_mp/$STORAGE_MARK/gcodes
        chown $_uid:$_gid $_mp/$STORAGE_MARK $_mp/$STORAGE_MARK/gcodes
        ;;
    esac
    # really writable? (a card with its lock switch on mounts read-only)
    if ! ( : > $_mp/$STORAGE_MARK/gcodes/.dp200_write_test ) 2>/dev/null; then
        echo "storage: $_mp is not writable, not used"
        return 0
    fi
    rm -f $_mp/$STORAGE_MARK/gcodes/.dp200_write_test
    if mount --bind $_mp/$STORAGE_MARK/gcodes $_g; then
        echo "storage: G-code on $_mp ($_dev, $_fs), `df -k $_mp | awk 'END {print int($4 / 1024)}'` MB free"
    else
        echo "storage: bind mount failed, internal flash"
    fi
    return 0
}

# Unmount the G-code folder again. Returns 1 if it is still mounted: the
# caller must then not delete anything under $ROOT.
dp200_storage_release() {
    _g=`dp200_storage_gcodes`
    grep -q " $_g " $PM || return 0
    umount $_g 2>/dev/null || umount -l $_g 2>/dev/null
    grep -q " $_g " $PM && return 1
    return 0
}
