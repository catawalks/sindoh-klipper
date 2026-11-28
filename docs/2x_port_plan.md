# 2X: port plan

**Status (2026-11-28): the stock 2X has been read (no motion, no heat,
nothing written to it); Klipper has not run on it.** What was found is
in sindoh [`docs/2x.md`](https://github.com/catawalks/sindoh/blob/main/docs/2x.md).
This page is the plan that follows from it. The 1X pages it builds on:
[1x_port_plan.md](1x_port_plan.md), [1x_install_plan.md](1x_install_plan.md).

## What the 2X is

- The owner's 2X is the older board of the family (stock calls it
  "Prime_r1"; `/sys/kernel/board_name` says `TOC`): the 1X's hardware
  with a NAND chip where the 1X has its eMMC. Its live device tree is
  the 1X's node for node except for the NAND.
- It boots from NAND (UBIFS root, 42 MB free) like a DP200. There is
  no eMMC and no `/userdata`. Sindoh's factory SD card sits in the
  card socket, unmounted.
- Its engine settings (speeds, temperatures, routines) are the 1X's.
  It has two heads: X1 homes on the right, X2 on the left (the 1X's
  only head is the X2 one).

## What carries over from the 1X unchanged

- The firmware (`klipper_x1_fm.bin`, `klipper_x1_io.bin`, fork
  `sindoh-dp200`): same SoC blocks. It already keeps all eight motor
  slots and both nozzle heater channels.
- `upctool`, the TMC set-up (`tools/x1_tmc.py`: one UART, select on
  146/147/149, gate 152), the thermistor tables, the motion limits,
  the bed, Y and Z sections, the lamp, beeper, level sensor and
  probe.
- The screen app, Moonraker, Mainsail, the camera, the sound helper,
  the network scripts.

## What differs (config and scripts)

| Item | 1X | 2X (this board) | State |
|---|---|---|---|
| Back left exhaust fan enable | GPIO 112 | GPIO 126 | from stock's table, not switched yet |
| Its lock input | 114 | 128 | same |
| Extruder entry filament sensors | 120, 121 | 134, 135 | same |
| Power button line | 116 | 130 (answer still 158) | same; the screen app already uses 130 on this board |
| GPIO 69 "nozzle voltage" | held high | not there: must not be defined | 2X engine has no such pin |
| Board check in our scripts | `1X_r1` | `TOC` | `x1_boot.sh`, `x1_hook.sh` refuse this board today (safe) |
| `/userdata/klipper` (root, flags, keys) | eMMC | does not exist | see "Where it lives" |
| Stock power-off | plain | remounts `/` read-only, drops GPIO 111 ("write-protect") | to be copied by our power-off helper |

**Stock's watcher (read 2026-11-28, sindoh `docs/2x.md`).** On this
board `/recovery/recovery.check.sh --post-process-integrity` checks
every 60 s that the motion program, `UIManager` and `appBrowser` run.
When one is gone it writes a stamp to the NAND root, and the next
start is a long file check; with `/` read-only it asks for a recovery
boot from Sindoh's SD card. The 1X scripts freeze the 1X's watchdog
(`recovery_watchdog.sh`), which does not run here. **The 2X takeover
must stop this watcher first**, and our power-off helper must not
leave `/` read-only while it is alive. `x1_stop.sh` does this since
2026-11-28: on any board but `1X_r1` it freezes the watcher
(`kill -STOP`), checks that it is frozen, and stops nothing
otherwise. The freeze alone was tried on the 2X the same night
(state S, T after the freeze, S again after `kill -CONT`; no stamp
written); the rest of the script has not run there.

Second head, expected from the 1X work and the 2X's live registers;
each line needs its own test with the owner at the printer:

| Item | Expected | Why |
|---|---|---|
| Nozzle 2 heater | PWM block 25 | period 1000 like 5 and 28; idle on the 1X, running at 11 % on the idle 2X next to block 5 |
| Nozzle 2 thermistor | ADC select 4 | "open on the 1X" |
| Head 2 fans | PWM blocks 14 and 22, GPIO 225 (`gp_En_NozzleFan[0]`) | did nothing on the 1X; configured and off on the idle 2X |
| Driver enables | X1 GPIO 56, extruder 1 GPIO 53, cartridge feed 1 GPIO 96 | the engine's hold masks pair 56 with the axes, 53 with 96, and 44 with 50 (the 1X's pair) |
| Motor current references | PWM blocks 13 and 23 | run on the 1X without a motor; both at 100 on the idle 2X |
| TMC numbers | 1, 5, 7 | empty on the 1X |
| X1 step engine, X1 home sensor | not known | |
| Head 1 filament sensors | cartridge bay GPIO 76, extruder entry GPIO 135 (head 2: 80 and 134) | the 2X's FM program picks them by the enabled driver |
| Head 1 feed encoders | not known | |
| Step generators | X1 its own (block 5, the one the 1X leaves unused); the two extruders share block 3 and the two feeds block 4, picked by the enable | six blocks, eight drivers; the engine always enables one head's extruder and feed together. To be shown by a test |

Stock's X current setting on this printer is `MOTOR_PWM_XOFFSET` -15
(X1) and `X2OFFSET` 0; Z is +30 (1X: +40).

## Klipper side

- Kinematics: `cartesian` with `[dual_carriage]` on X. X2 (left,
  `stepper_x` of the 1X config) and X1 (right) share the rail.
- `T0`/`T1` macros with stock's sequence: park the idle head at its
  end, clean and prime the new one (stock: a full cleaning on the
  first change, a shorter one after, 14.5 or 12 mm of filament and 2
  or 1 mm of "injection"). The cleaning, load and unload macros take
  the head as a parameter (they were written that way for the 1X).
- Second nozzle offsets: X, Y from the XY calibration, Z from the two
  nozzles' own touch heights. Stock stores them in its database
  (`X2_AXIS_COMPENSATION`, `Y_AXIS_COMPENSATION`, `HomeZOffset_NZ2`);
  ours go to `SAVE_VARIABLES` and are applied with
  `SET_GCODE_OFFSET` in the tool macros.
- Stock's "tandem mode" (`M605 S2`, both heads printing copies) maps
  to `SET_DUAL_CARRIAGE ... MODE=COPY`. Later.
- Homing: stock looks at both X home sensors and homes the head that
  is NOT at home first when only one is. Ours must do the same.

## Screen app

Done 2026-11-28 (rendered on the 1X from a side copy, not run on a
2X): the app knows the board (`MODEL` 2X), reads the power button on
GPIO 130 there, its header shows both nozzles when Klipper has an
`extruder1`, and PREHEAT then offers NOZZLE 1 / NOZZLE 2 / BOTH
(`M104 T0`/`T1`).

To do, once a 2X config exists (stock's pages show what is needed:
the 1X's stock screen is the 2X's with these parts commented out):

- nozzle 1 / nozzle 2 selector on JOG (which head moves), CLEAN and
  the Z offset page;
- FILAMENT: pick the cartridge first (stock's "cartridge selection"
  page), then load or unload it; both cartridges on the print page;
- calibration: nozzle XY (print stock's kind of pattern, enter the
  number of the straight line, 1 to 11, for X and for Y) and nozzle
  Z; a reset for both;
- PID tuning and the heater checks for the second nozzle.

## Where it lives (owner's decision)

The Debian root is about 920 MB; the NAND root has 42 MB free.

1. **USB stick as root** (our recommendation for the bring-up): an
   ext4 partition on a stick holds the root; a stick script starts it
   the way the remote shell starts today (warm takeover after stock
   is up, as on the 1X before 11-27). **No NAND write at all**, and
   pulling the stick gives a stock printer. Cost: a stick stays in.
2. **Our card in the SD socket** in place of Sindoh's factory card.
   Needs the printer opened, and the factory card kept safe (it is
   stock's recovery image; a copy of such a card is already on the
   PC). Read 2026-11-28: in normal running stock does not mount
   the card, but its recovery script asks the card what it is, and
   its card utility can format partition 3 as an encrypted volume.
   A card of ours would have to keep partition 3 free for that, and
   with it in the socket the printer has no card recovery (stock
   then says "Please Use USB Tool").
3. **A boot hook in the NAND root** (`/etc/init.d/S99klipper`, one
   small file, as on the 1X) so that 1 or 2 start without a stick
   script. This is a NAND write: the owner's OK, and only after the
   warm takeover has proven itself.

Not planned: our own kernel, or anything in the U-Boot blocks or
environment.

## Order of work

1. Serial boot capture (the cable is on the 1X; swap needed).
2. Emulate the 2X's two motion-core programs on the PC
   (`tools/x1_ucode_probe.py` needs the `unicorn` package, which is
   not installed on this PC any more).
3. A stick root and the warm takeover with a look-only config
   (stage 4 of the 1X plan): both cores up, sensors and thermistors
   read, nothing driven. Board check and pin list for `TOC` in
   `x1_stage4.sh`, `x1_web.sh`.
4. TMC read-back of all eight drivers (stock stopped).
5. Outputs one at a time, owner watching: fans (126, 14, 22, 225),
   heater 2 with low limits, the three new motors.
6. Homing both heads, then the tool macros and offsets.
7. Screen pages for the second head.
8. Decide 2 or 3 above.
