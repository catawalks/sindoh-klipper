#!/bin/sh
# Dev printers only: turn on SSH (dropbear, port 2222, key login) in the
# Debian root that runs our stack. Run inside that root (on mainline it is
# the root; on the stock kernel: chroot /mnt/sd or chroot /klipper first):
#
#   wget -q -O /tmp/s.sh http://PC:8099/deploy/usb/t/dev_ssh_setup.sh
#   sh /tmp/s.sh http://PC:8099/deploy/usb/t
#
# It fetches from that URL: rc.dp200 (the version with start_ssh) and
# dev_ssh.pub (the PC's public key; the private key stays on the PC,
# D:\DP200\backup\keys\sindoh_dp200_ecdsa). Then it installs dropbear-bin
# with apt if dropbear is missing, and starts SSH. Undo: delete
# /root/.ssh/authorized_keys (rc.dp200 then no longer starts it) and
# "kill $(cat /run/dp200/ssh.pid)".
#
# Release payloads never carry the key or the host key (runtime.exclude,
# make_payload.sh refuses a payload that has any).
set -e
URL=${1:?usage: dev_ssh_setup.sh http://PC:8099/deploy/usb/t}
RC=/etc/dp200/rc.dp200

echo "== rc.dp200"
wget -q -T 10 -O $RC.new "$URL/rc.dp200"
sh -n $RC.new
grep -q '^start_ssh()' $RC.new || { echo "that rc.dp200 has no start_ssh"; exit 1; }
[ -f $RC ] && cp -p $RC $RC.prev
mv $RC.new $RC; chmod 755 $RC

echo "== key"
mkdir -p /root/.ssh; chmod 700 /root/.ssh
wget -q -T 10 -O /root/.ssh/authorized_keys.new "$URL/dev_ssh.pub"
grep -q '^ecdsa-sha2-nistp256 ' /root/.ssh/authorized_keys.new || { echo "not a public key"; rm -f /root/.ssh/authorized_keys.new; exit 1; }
mv /root/.ssh/authorized_keys.new /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys

echo "== dropbear"
if [ ! -x /usr/sbin/dropbear ]; then
    if command -v apt-get >/dev/null; then
        apt-get install -y -q --no-install-recommends dropbear-bin
        apt-get clean
    else
        echo "no dropbear and no apt here (a NAND runtime root): install"
        echo "dropbear-bin in the SD card's build root and make a new payload"
        exit 1
    fi
fi

echo "== start"
# what rc.dp200's start_ssh does at every start
RUN=/run/dp200; mkdir -p $RUN
SSH_KEYS=/root/.ssh/authorized_keys; SSH_HOSTKEY=/etc/dp200/ssh_host_ecdsa_key
[ -s $SSH_HOSTKEY ] || /usr/bin/dropbearkey -t ecdsa -s 256 -f $SSH_HOSTKEY | grep -i fingerprint || true
if [ -f $RUN/ssh.pid ] && kill -0 "$(cat $RUN/ssh.pid)" 2>/dev/null; then
    echo "already running"
else
    /usr/sbin/dropbear -s -g -p 2222 -r $SSH_HOSTKEY -P $RUN/ssh.pid
fi
/usr/bin/dropbearkey -y -f $SSH_HOSTKEY | grep -i fingerprint || true
echo "ssh -i D:/DP200/backup/keys/sindoh_dp200_ecdsa -p 2222 root@$(ip -4 -o addr show 2>/dev/null | awk '$2 != "lo" {sub("/.*", "", $4); print $4; exit}')"
