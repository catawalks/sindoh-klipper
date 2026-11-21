#!/bin/bash
# Run INSIDE the Debian chroot on the 1X's SD card by build_root_1x.sh.
# Installs the host side only: Klipper (our fork), Moonraker, Mainsail.
# Nothing is started. Small on purpose: the card has 1.7 GB.
set -uo pipefail
SRC=/usr/src/x1
KUSER=klipper
KHOME=/home/$KUSER
as_user() { su -s /bin/bash $KUSER -c "$1"; }
step() { echo "== $* ($(date +%H:%M:%S), $(df -k / | awk 'END {print int($4 / 1024)}') MB free)"; }

step "3. packages"
dpkg --configure -a
apt-get update -q || exit 1
apt-get install -y -q -o Dpkg::Progress-Fancy=0 --no-install-recommends \
    python3 python3-venv python3-dev python3-pip gcc make libc6-dev \
    libffi-dev libncurses-dev git curl unzip nginx ca-certificates \
    libjpeg62-turbo-dev zlib1g-dev liblmdb-dev libsodium-dev \
    procps iproute2 less python3-pil fonts-dejavu-core || exit 1
apt-get clean
rm -rf /var/lib/apt/lists/*

step "4. klipper user"
id $KUSER >/dev/null 2>&1 || useradd -m -s /bin/bash -G dialout,video,tty $KUSER
chmod 755 $KHOME

step "5. Klipper (fork, pinned commit) and Moonraker"
. $SRC/FORK
if [ ! -d $KHOME/klipper/.git ]; then
    as_user "git clone -q --depth 50 -b $BRANCH $REPO ~/klipper" || exit 1
fi
as_user "cd ~/klipper && git checkout -q --detach $COMMIT && git rev-parse HEAD" || exit 1
[ -d $KHOME/moonraker/.git ] || as_user "git clone -q --depth 1 https://github.com/Arksine/moonraker ~/moonraker" || exit 1
[ -x $KHOME/klippy-env/bin/python ] || as_user "python3 -m venv ~/klippy-env"
as_user "TMPDIR=~/.cache/tmp; mkdir -p \$TMPDIR; export TMPDIR; ~/klippy-env/bin/pip install -q --no-cache-dir -r ~/klipper/scripts/klippy-requirements.txt" || exit 1
[ -x $KHOME/moonraker-env/bin/python ] || as_user "python3 -m venv ~/moonraker-env"
as_user "TMPDIR=~/.cache/tmp; export TMPDIR SKIP_CYTHON=1; ~/moonraker-env/bin/pip install -q --no-cache-dir -r ~/moonraker/scripts/moonraker-requirements.txt" || exit 1
as_user "cd ~/klipper/klippy && ~/klippy-env/bin/python -c 'import chelper; chelper.get_ffi(); print(\"CHELPER_OK\")'" || exit 1
rm -rf $KHOME/.cache

step "6. Mainsail"
if [ ! -f $KHOME/mainsail/index.html ]; then
    as_user "mkdir -p ~/mainsail && cd ~/mainsail && \
        curl -fsSL -o mainsail.zip https://github.com/mainsail-crew/mainsail/releases/latest/download/mainsail.zip && \
        unzip -q mainsail.zip && rm mainsail.zip" || exit 1
fi
install -m 644 $SRC/mainsail /etc/nginx/sites-available/mainsail
rm -f /etc/nginx/sites-enabled/default
ln -sf ../sites-available/mainsail /etc/nginx/sites-enabled/mainsail
install -d -o $KUSER -g $KUSER $KHOME/printer_data $KHOME/printer_data/config \
    $KHOME/printer_data/gcodes $KHOME/printer_data/logs
[ -f $KHOME/printer_data/config/moonraker.conf ] || \
    install -m 644 -o $KUSER -g $KUSER $SRC/moonraker.conf $KHOME/printer_data/config/
echo "x1-klipper" > /etc/hostname

step "checks"
python3 --version
$KHOME/klippy-env/bin/python -c "import sys; sys.path.insert(0, '$KHOME/klipper/klippy'); import klippy, configfile, mcu; print('KLIPPY_IMPORT_OK')" || exit 1
$KHOME/moonraker-env/bin/python -c "import sys; sys.path.insert(0, '$KHOME/moonraker'); import moonraker.server; print('MOONRAKER_IMPORT_OK')" || exit 1
nginx -t 2>&1 | tail -1
du -sh /usr /home /var 2>/dev/null | tr '\n' ' '
echo
echo "INSIDE_DONE"
