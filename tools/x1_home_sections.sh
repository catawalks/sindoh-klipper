#!/bin/sh
# 3DWOX 1X bring-up: home one manual_stepper in 20 mm sections, checking
# the home sensor between sections, so a failed sensor costs 20 mm at most.
# Run on the printer while install/x1/x1_stage4.sh has Klipper up with a
# config that has the stepper (with endstop_pin) and a gcode_button on the
# same sensor.   sh x1_home_sections.sh STEPPER BUTTON SIGN
#   e.g.  x_test x_home +     (X homes left = positive)
#         y_test y_home -     (Y homes to the back = negative)
# It refuses to start unless the sensor reads released.
K=/home/klipper
g() { a=""; for x in "$@"; do a="$a '$x'"; done
  chroot /tmp/sd su -s /bin/sh klipper -c "$K/klippy-env/bin/python $K/x1_gcode.py $K/printer_data/comms/klippy.sock $a"; }
S=$1; B=$2; SG=$3; n=0
st() { sh /tmp/sd/stage/x1_stage4.sh status | grep "gcode_button $B " | awk '{print $3}'; }
[ "$(st)" = RELEASED ] || { echo "HOME $S: sensor not released at start, not moving"; exit 1; }
while [ $n -lt 9 ]; do
  g "MANUAL_STEPPER STEPPER=$S SET_POSITION=0" "MANUAL_STEPPER STEPPER=$S MOVE=${SG}20 SPEED=15 STOP_ON_ENDSTOP=2" > /dev/null
  n=$((n+1)); s=$(st); echo "HOME $S section $n sensor $s"
  [ "$s" = PRESSED ] && { echo "HOME $S: stopped at the sensor after $n sections"; exit 0; }
done
echo "HOME $S: sensor never tripped in 180 mm, stopping"; g "MANUAL_STEPPER STEPPER=$S ENABLE=0" > /dev/null; exit 1
