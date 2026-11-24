#!/bin/sh
# 3DWOX 1X: write x1_machine.cfg, this printer's own motor currents, from
# Sindoh's settings database (read only). For the 1X installer; by hand:
#   sh x1_machine_cfg.sh OUTFILE [DATABASE]
# Runs on the printer's stock Linux (BusyBox sh, awk, sqlite3).
#
# karas.db CONF_ENGINE_PWM row NO=4 (the row the stock program reads):
# MOTOR_PWM_X2OFFSET (the 1X's head is the "X2" carriage), _YOFFSET,
# _ZOFFSET, _EOFFSET and _COFFSET (cartridge feed), each -99..99. The
# stock program sets each motor's reference PWM to a high count of
# 100 + offset in a period of 200; Klipper's output_pin value is
# (high + 0.5) / 200 (sindoh docs/1x.md, "Motor currents"). The printer's
# own printer.cfg can still override what this file sets. Anything
# missing or out of range: no file is written and x1_printer.cfg's
# defaults stay.
OUT=${1:?usage: x1_machine_cfg.sh OUTFILE [DATABASE]}
DB=${2:-/app/nvram/karas.db}
[ -f "$DB" ] || { echo "x1_machine_cfg: no $DB"; exit 1; }
OFFS=$(sqlite3 "$DB" "select MOTOR_PWM_X2OFFSET, MOTOR_PWM_YOFFSET, MOTOR_PWM_ZOFFSET, MOTOR_PWM_EOFFSET, MOTOR_PWM_COFFSET from CONF_ENGINE_PWM where NO=4" 2>/dev/null)
FW=$(sed -n "s/.*echo '\(ROD[^']*\)'.*/\1/p" /snapshot_version.sh 2>/dev/null | head -n 1)
echo "x1_machine_cfg: motor offsets X|Y|Z|E|C = $OFFS"
echo "$OFFS" | awk -F'|' -v fw="${FW:-?}" '
    NF != 5 { exit 1 }
    { for (i = 1; i <= 5; i++) if ($i !~ /^-?[0-9]+$/ || $i < -99 || $i > 99) exit 1 }
    { split("x y z e c", ax, " ")
      split("X2 Y Z E C", col, " ")
      print "# Generated from this printer'"'"'s stock database (karas.db"
      print "# CONF_ENGINE_PWM NO=4, firmware " fw ") by install/x1/x1_machine_cfg.sh."
      print "# Replaced on every install or upgrade: put your own overrides in"
      print "# printer.cfg."
      for (i = 1; i <= 5; i++) {
          v = (100 + $i + 0.5) / 200
          printf "\n[output_pin motor_current_%s]\n# MOTOR_PWM_%sOFFSET %d\nvalue: %.4f\nshutdown_value: %.4f\n", ax[i], col[i], $i, v, v
      } }' > "$OUT.new" || { echo "x1_machine_cfg: offsets not usable, defaults kept"; rm -f "$OUT.new"; exit 1; }
mv "$OUT.new" "$OUT"
echo "x1_machine_cfg: wrote $OUT"
