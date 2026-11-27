#!/bin/sh
# 3DWOX 1X: WiFi on a cold start (x1_hook.sh; docs/1x_install_plan.md).
# On a normal boot Sindoh's screen program starts wpa_supplicant and
# gives it the network from its database; on a cold start that program
# never runs, so this does the same with our own copy of the settings.
#   sh x1_wifi.sh start     seed (below), start wpa_supplicant, wait for
#                           the connection, then "ifup mlan0" (address as
#                           set on Sindoh's screen: /etc/network/interfaces)
#   sh x1_wifi.sh seed      write $W/wpa_supplicant.conf from the network
#                           selected on Sindoh's screen (karas.db, table
#                           RECD_SSIDBOOK, read only)
#   sh x1_wifi.sh status
# The copy is made again at every start, so a network changed on
# Sindoh's screen is followed; with $W/own present it is left alone (for
# a WiFi set-up of our own later). The file holds the key as a hash and
# is readable by root only. Nothing here prints a network name or key.
export PATH=/usr/sbin:/sbin:/usr/bin:/bin:$PATH
BASE=${X1_BASE:-/userdata/klipper}
W=$BASE/wifi
CONF=$W/wpa_supplicant.conf
DB=/app/nvram/karas.db
IF=mlan0
INFO=/proc/mwlan/$IF/info
say() { echo "x1_wifi: $*"; }
q() { sqlite3 $DB "SELECT $1 FROM RECD_SSIDBOOK WHERE ifSelected=1 LIMIT 1;" 2>/dev/null; }

seed() {
    [ -e $W/own ] && return 0
    ssid=$(q SSID)
    [ -n "$ssid" ] || { say "no network selected on Sindoh's screen"; return 1; }
    key=$(q Passkey1)
    hidden=$(q ifHidden)
    mkdir -p $W; chmod 700 $W
    umask 077
    {
        echo "ctrl_interface=/var/run/wpa_supplicant"
        echo "ap_scan=1"
        n=${#key}
        if [ $n -ge 8 ] && [ $n -le 63 ]; then
            wpa_passphrase "$ssid" "$key" | grep -v '^[[:space:]]*#psk='
        elif [ $n -eq 64 ]; then
            printf 'network={\n\tssid="%s"\n\tpsk=%s\n}\n' "$ssid" "$key"
        elif [ $n -eq 0 ]; then
            printf 'network={\n\tssid="%s"\n\tkey_mgmt=NONE\n}\n' "$ssid"
        else
            echo "# key of $n characters: not a WPA key, nothing written"
        fi
    } > $CONF.new
    grep -q '^network={' $CONF.new || { rm -f $CONF.new; say "the saved key is not a WPA key (WEP is not handled)"; return 1; }
    [ "$hidden" = 1 ] && sed -i 's/^}$/\tscan_ssid=1\n}/' $CONF.new
    mv $CONF.new $CONF
    sync
    say "settings copied from Sindoh's database"
}

case "$1" in
start)
    [ -d /proc/mwlan/$IF ] || { say "no WiFi module ($IF)"; exit 1; }
    [ -n "$(pidof wpa_supplicant)" ] && { say "wpa_supplicant is already running"; exit 0; }
    seed
    [ -f $CONF ] || { say "no settings: WiFi stays off"; exit 1; }
    rm -f /var/run/wpa_supplicant/$IF
    wpa_supplicant -Dwext -P /var/run/wpa_supplicant.$IF.pid -O /var/run/wpa_supplicant \
        -i$IF -c$CONF -B > /dev/null 2>&1 || { say "wpa_supplicant did not start"; exit 1; }
    n=0
    until grep -q 'media_state="Connected"' $INFO 2>/dev/null; do
        n=$((n+1)); [ $n -gt 40 ] && { say "not connected after 40 s (wpa_supplicant keeps trying)"; exit 1; }
        sleep 1
    done
    say "connected after $n s"
    ifup $IF -f > /dev/null 2>&1
    ip -4 addr show $IF | grep -q "inet " && say "address set" || say "no address yet"
    ;;
seed)
    seed
    ;;
status)
    grep media_state $INFO 2>/dev/null
    [ -n "$(pidof wpa_supplicant)" ] && say "wpa_supplicant running" || say "wpa_supplicant not running"
    [ -f $CONF ] && say "settings file present" || say "no settings file"
    ip -4 addr show $IF | grep -q "inet " && say "address set" || say "no address"
    ;;
*)  echo "usage: $0 start|seed|status"; exit 1 ;;
esac
