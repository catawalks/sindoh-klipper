# Klipper on the Sindoh 3DWOX 1X: port plan

**Status (2026-11-21): stages 1 to 4 done. Klipper runs on the 1X with
our firmware on both UPC cores and reads its thermistors and home
sensors; nothing of ours has driven a motor or a heater yet.** The
owner's 1X is on stock firmware `ROD1X_200916_2` with a root serial
console and (after the USB stick tool) SSH. Everything known about the
machine is in [sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md);
this page is what we do with it.

## Why this should work

The 1X uses the same design as the DP200, one chip generation on:

| | DP200 (88PA6170) | 1X (88PA6270) | Port work |
|---|---|---|---|
| Motion and heaters | two UPC cores, FM and IO microcode | the same (the engine loads `fm` and `io` at boot) | reuse the Klipper UPC firmware |
| UPC driver | `upc.ko`, `/dev/upc0`, `/dev/upc1` | `upc_6270.ko`, same device nodes, almost the same symbols | check `upctool` against it |
| ITCM per core | 16 KB | 32 KB | more room; build option |
| DTCM | 256 KB shared | 256 KB shared, at 0xF9880000 (device tree) | address in `upctool` |
| PWM, ADC, sensor blocks | 0xF9304000, 0xF930A000, 0xF9301000 | the same addresses | probably unchanged; to verify |
| Stepper blocks | 5 at 0xF8150000 | 6 at 0xF8150000; registers moved up by 0x28 | new offsets in the firmware |
| GPIO | banks at 0xF8040000 | one block at 0xD4019000; Linux numbers known for 26 lines | new pin map |
| Motor drivers | A4982 (current by PWM) | TMC2224 on one UART (`ttyS2`) with a 3-line select | Klipper `tmc2208` + a select |
| Linux | 3.2, 2 cores, 494 MB, NAND | 4.2.8, 4 cores, 1 GB, eMMC (ext4) | easier: room and RAM to spare |
| Root access | serial console | serial console, SSH | done |
| Unbrick | Sindoh USB reflash | recovery system on its own partition, U-Boot prompt | better |

The stick install needs no kernel work on the 1X either: stock 4.2.8 is
recent enough for a current Debian (armhf: the CPU has VFPv4 and NEON).

## Rules for this printer

It is the owner's working 1X, on stock firmware.
- Nothing that moves or heats without the owner at the printer.
- No writes to the eMMC system, recovery or boot partitions, the U-Boot
  environment, the EEPROM, or `karas.db`. Never write 1 to
  `/sys/kernel/watchdog_reason` (it asks for the recovery boot). Never run
  `/snapshot_version.sh`.
- Until a stage says otherwise, everything of ours lives in RAM (`/tmp`)
  or, with the owner's OK, in its own folder on `/userdata` (4.1 GB free,
  Sindoh's user data partition), and a reboot brings back plain stock.
- Sindoh's engine owns the UPC cores, heaters and motors. A stage that
  needs the UPCs stops the engine first and ends with a reboot.

## Stages

Each stage ends with something checked, and the next one does not start
before it.

**0. Paper work (PC only).** Done: the comparison above; the microcode
start-up emulated (`tools/x1_ucode_probe.py`: PWM, ADC and GPIO set-up,
motor driver pins); thermistor tables (the DP200's, value for value);
axes, limits, homing and the nozzle-contact bed leveling
([sindoh: 1x_stock_routines.md](https://github.com/catawalks/sindoh/blob/main/docs/1x_stock_routines.md)).
Still to do:
- `upc_6270.ko`'s ioctls against the DP200's (`host/upctool.c`).
  **First look, 2026-11-20** (`tools/kodis.py upc_ioctl` on both
  modules): the 1X driver handles the same four command numbers `upctool`
  uses (0x7521 run, 0x7522 hold, 0x7523 select ITCM, 0x7524 select DTCM
  offset) and the same mailbox calls, plus two new ones (0x7530, 0x7531,
  not decoded). Still to check: the direction and size bits of each
  number, the 32 KB ITCM limit, and what the new `upc_seek` and
  `upc_write_align` change for writes.
- The 1X `fm`/`io` microcode's start-up: what it writes to the PWM, ADC,
  GPIO and stepper blocks (emulate it, as `tools/fmprobe.py` and
  `pwmprobe.py` do for the DP200). This gives the heater PWM channels,
  the ADC channels of the three thermistors, endstop inputs, and the
  step/dir/enable wiring of each stepper block.
- The thermistor tables as Klipper `[adc_temperature]` sections
  (`tools/gen_thermistors.py`).
- Done 2026-11-21: the TMC2224 setup the engine sends and the
  select-line code ([sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md),
  "What the engine writes to each TMC2224"). Current comes from VREF
  (PWM), microstepping from the MS pins.

**1. A Debian root on the 1X (no hardware touched).** A Debian armhf
root on an **SD card in the mainboard's slot** (owner, 2026-11-21: a
spare 2 GB card as the development and staging area, so nothing of ours
is written to the eMMC), built with the DP200's
`install/build_rootfs*.sh`, entered by chroot.
- The card: `/dev/mmcblk1p1`, ext4, label `1x-dev`, 1.7 GB free. The
  stock system detects it but does not mount it (its `media.connect`
  exits for SD cards), so we mount it ourselves at `/tmp/sd` (a RAM
  folder: `/mnt/sd` would have to be created on the eMMC root). After a
  repartition the `/dev` node can be missing: `mknod /dev/mmcblk1p1 b
  179 33`. Its old contents are backed up on the owner's PC
  (`sd_card_backups/`).
- 1.7 GB holds the runtime, not a full build system: compile elsewhere.
- **Done 2026-11-21** (`install/x1/build_root_1x.sh`): Debian trixie
  armhf, Klipper (fork 9b174ab), Moonraker, Mainsail; `chelper` built,
  klippy and Moonraker import; nothing started; 790 MB left on the card.
  Sindoh's programs kept running throughout.
Klipper, Moonraker and Mainsail installed but not started. Check: the
chroot runs, Python and the Klipper host code import, nothing of Sindoh's
is disturbed.

**2. Look, don't touch (stock engine running).** `upctool` built for the
1X map, read-only commands only (`info`, `dump` of the shared DTCM): do
our tools see the stock firmware's state the way they do on the DP200?
**Done 2026-11-21** with `upctool --dtcm 0xf9880000 --ro dump` (the new
read-only mode: no driver call, memory mapped read-only): the shared
memory starts with the nozzle thermistor table (first entry 299819, as in
the engine), and the table checksum and its complement sit at 0xA728 and
0xA72C, exactly where the emulated microcode looks for them.

**3. Passive probe on the UPCs (owner present).** Stop Sindoh's engine,
load our probe firmware (`upc_fw/probe`, reads registers, drives
nothing), read the report, reboot. Before stopping the engine: confirm
what its outputs do when it dies (heaters and motor enables must go
off; on the DP200 they do). Check: the probe report matches stage 0.

**Done 2026-11-21** (owner at the printer). What it showed:
- **The stock 1X keeps its heaters on when idle** (owner: the screen
  shows nozzle 80 °C, bed 50 °C, all the time; boot log: `T.Cfg N:0 T:80`,
  `N:1 T:80`, `N:2 T:50`). Two PWM blocks with period 1000 (5 and 28,
  counted as on the DP200: block N at 0xF9304000 + 0x100*N) run at a few
  percent duty that changes every second. The screen's power saving
  setting (owner set it to 5 minutes) is the stock way to cool down.
- **The engine's death does not switch the heaters off.** After
  `kill -TERM` the microcode goes on regulating to the last targets. The
  engine stays as a zombie under UIManager; nothing reacts
  (`watchdog_reason` stays 2, the hardware watchdog is fed by a separate
  `watchdog` process, `recovery.check.sh` only prints a line).
- **Holding the cores freezes every PWM output as it is**, so a running
  heater output must be stopped right after the hold. Clearing bit 0 of
  the block's control register (0x29 -> 0x28, the value the microcode
  itself uses for a stopped channel) does it; the bed reading fell
  afterwards. While the microcode runs it puts the bit back at once.
- **The PWM block works like the DP200's; the block numbers differ.**
  (Corrected later the same day: at first the unfamiliar values looked
  like a different register.) Bit 0 is run, bit 2 the level when
  stopped, the rest per-block configuration (0x28 fans and heaters,
  0x0A motor references, 0x18, 0x68), and the enable word at 0xF9304000
  has one bit per block in use. Blocks on the 1X, by period:
  - 1000 (heaters): 5, 25, 28. 5 and 28 are the two that regulate; 25
    never runs on the 1X (the 2X's second nozzle, our reading).
  - 100 (fans): 2, 10, 14, 20, 22. Block 10 runs at 80 % at idle.
  - 200 (motor driver references): 13, 21, 23, 29, 30, 31, 32 running;
    8, 18, 24, 26 stopped.
  - 250: block 19, stopped (our reading: the beeper, 4 kHz).
  - Block 7: a static level, on at idle and off in power saving (the
    case lights). Block 25 follows it.
  The DP200's "safe" writes still must not be used here: its stepper
  register offsets are wrong for the 1X. `upctool --passive` skips them
  and the probe has a look-only build (`make X1=1` in `upc_fw/probe`,
  `prebuilt/probe_x1_*.bin`).
- The engine uses the same four driver calls as `upctool` (0xC0017522
  hold, 0xC0017521 run, 0x7523 ITCM, 0xC0047524 DTCM offset), and loads
  in the same order (hold, zero the ITCMs, write, run).
- **Probe report:** both cores start our code from the ITCM and report
  through the DTCM at 0xF9880000. CP15 ID 0x56051012 (FM) and 0x56151012
  (IO), TCM status 0x2C01C0, Thumb works, no aborts, about 1.2 million
  loops a second. XENA timer 1 counts down at 398.04 MHz and the
  reload-and-extend scheme of the Klipper timer works. The console UART
  at 0xD4030000 prints.
- **The XENA input registers (XIRD) read all zero** on both cores: the
  1X's inputs do not come in that way. Stage 4 has to read them from the
  GPIO block (0xD4019000) instead.
- The ADC keeps converting with the cores held, on the channel selected
  last. Result words carry a channel tag in the upper bits and a 10-bit
  value below (for example 0x0007C33F).
- Sequence used: `kill -TERM` the engine; `upctool --passive --force
  stop`; clear bit 0 of PWM blocks 5, 25 and 28 with `devmem`;
  `upctool --passive --force --dtcm 0xf9880000 load probe_x1_io.bin
  probe_x1_fm.bin`; `upctool --dtcm 0xf9880000 probe 5`; `reboot`. The
  reboot brought stock back with no complaint.

**4. Klipper firmware, inputs only (owner present).** The fork gets a
1X build (`config/x1_fm.config`, `x1_io.config`: 6270 map, stepper
offsets). Both MCUs connect to klippy; read thermistors, endstops, fan
tach and filament sensors. No outputs enabled in the config.

**Done 2026-11-21** (owner at the printer, printer cooled by its power
saving mode first):
- Fork commit 3dcad7d8: `CONFIG_UPC_GPIO_BLOCK` adds read-only input
  pins `gpio0`..`gpio255` on the SoC GPIO block (level register at
  bank + 0x00, checked against the kernel's view of seven lines);
  `config/x1_fm.config`, `x1_io.config` (398 MHz timer). Both images fit
  the 16 KB the DP200 build uses (12.6 and 12.8 KB).
- **The ADC needed no change:** the 1X's microcode programs it exactly
  as the DP200's does, and the thermistor tables use the DP200's index
  bases (nozzle 110, bed 381). Mux select 1 is the nozzle, 2 and 3 both
  read the bed, 4 is open on the 1X. Klipper showed nozzle 25.8 °C and
  bed 35.6 °C a few minutes after the stock firmware's own values of
  28.8 and 38.2 °C while cooling.
- `install/x1/x1_stop.sh` stops the engine, holds the cores and stops
  the heater PWM blocks; `install/x1/x1_stage4.sh start|status|stop`
  loads the firmware, runs `upctool bridge` and klippy in the SD card's
  Debian root with `klipper/config/x1/x1_stage4.cfg` (no outputs
  defined). `tools/x1_query.py` prints the state from Klipper's API
  socket. `upctool` is passive by itself on these boards.
- Both MCUs connect (398.04 MHz measured by Klipper). The home sensors
  follow the owner's hand: **X home is GPIO 99, Y home is GPIO 82, both
  high at home.** The four filament sensor lines read; which level means
  "filament present" is not checked yet.
- Not done in stage 4: fan tach inputs, the Z home sensor and the
  nozzle-contact input (not found yet).

**5. Outputs one at a time (owner present each time).**

**5a done 2026-11-21: lights, beeper and fans** (fork 8ceef800: the 1X's
PWM block map and writable `gpioN` pins; `klipper/config/x1/x1_stage5a.cfg`;
`tools/x1_gcode.py` sends timed G-code). Each output was switched by
Klipper with the owner watching:

| Output | What it is (owner watching, 2026-11-21) |
|---|---|
| PWM block 2 | part cooling fan |
| PWM block 10 | power supply fan (80 % whenever stock is up; enable GPIO 127) |
| PWM block 20 | back right exhaust fan |
| GPIO 188 (`gp_En_NozzleFan[1]`) | extruder (hot end) fan, on/off |
| GPIO 112 (`gp_En_MainFan[1]`) | back left exhaust fan, on/off |
| PWM block 7 | case lights (static level) |
| PWM block 19 | beeper (period 250 = 4 kHz, duty 0.36 as stock) |
| PWM blocks 14, 22; GPIO 225 | nothing on the 1X (the 2X's second head, our reading) |

**5b, first half, done 2026-11-21: the motor drivers read over their
UART** from Linux (`tools/x1_tmc.py`; ttyS2 with GPIO 149/147/146 as
select and 152 as gate). Five TMC222x at motor numbers 0 (X), 2 (Y),
3 (Z), 4 (extruder), 6 (cartridge), 16 microsteps, set up as the engine
leaves them, and they keep that while powered. So Klipper needs no TMC
access for a first motor test: step, direction, enable and the current
reference PWM are enough.

**5b, second half, done 2026-11-21: X, Y and Z moved by Klipper** (fork
e3e1b356: the 1X's stepper register offsets, read from the stock FM
microcode; `klipper/config/x1/x1_stage5b.cfg` with one `manual_stepper`
per axis; step batching off in `x1_fm.config` until the engine clock is
measured). 5 mm out and back on each axis with the owner watching;
directions and pins in sindoh docs/1x_stock_routines.md. The drivers ran
on the stock current reference and set-up, untouched. One mistake: the
first Y move went toward the home stop (direction read from the wrong
part of the stock recording) and slipped the belt for 5 mm; no damage
reported. Rule since: no move toward a stop before the direction is
confirmed by a move away from it.

**Homing attempt stopped, 2026-11-21: the head was driven into the left
wall.** Reloading the config (to add the home sensors as endstops)
restarted the firmware. Its restart path sets bit 0 of each engine's
configuration register (the DP200's "driver disabled" bit) and, with the
1X's drivers enabled by GPIO lines, nothing cleared it again. With that
bit set the X direction pin (GPIO 163) stayed high whatever the control
register said, so the "move away" of 15 mm and six 1 mm test moves all
went left, into the stop. The owner called it; motors off, printer
rebooted to stock. Fork 0938457c clears the bit when an engine is
claimed and never sets it on these boards: **built, not yet run on the
printer** (the FORK pin stays at e3e1b356 until it is).

Rules from the two motion mistakes of this stage:
- After every firmware restart or config reload, check each axis's
  direction again before any real move: step with the driver disabled
  (enable line high) and read the direction pin, then one 1 mm move
  with the owner watching.
- Never move toward a stop unless the direction has just been confirmed
  by a move away from it and the sensor has been seen to release.
- If a move does not do what was commanded, stop and switch the motors
  off before investigating; do not send more moves to find out.

**Fix verified and X, Y homed, 2026-11-21** (fork 0938457c, FORK pin
moved to it). With the fixed firmware each engine's configuration reads
0x10 before and after a firmware restart, the direction pins follow the
control register, and a restart leaves all three drivers disabled.
Then, from the middle of travel and with the sensors released, X was
homed to the left and Y to the back in 20 mm sections with
`STOP_ON_ENDSTOP` (`tools/x1_home_sections.sh`): both stopped cleanly
on their sensors (owner watching). Note: a `manual_stepper` move
enables its driver by itself, so there is no "dry" stepping through
Klipper; the pin check before a move is reading, the move is real.

**Z homed the same day** (bed empty, owner watching, direction checked
again after the config reload: positive is down): upward at 2 mm/s in
2 mm sections, stopped on the sensor (GPIO 83, high at home) after
about 19 mm. The head was parked at the left, off the bed, so the gap
to the nozzle at Z home was not seen.

**5c done 2026-11-21: both heaters driven by Klipper** (owner present;
`x1_stage5c.cfg`: `heater_generic` with low limits, reduced power and
`verify_heater`). PWM 5 at 40 % took the nozzle from 56.8 to 88.3 °C in
45 s with the bed flat; PWM 28 at 60 % took the bed from 46.3 to
56.6 °C in 75 s and held it, with the nozzle cooling. Later the nozzle
went to 240 °C at 60 % in about 190 s under watermark control (peak
243.4). The extruder fan (GPIO 188) ran as a `heater_fan`.

**5d, extruder motor: not working yet, stopped** (`x1_stage5d.cfg`,
`x1_stage5e.cfg`). Engine 3 stepped (its counter moved), the extruder's
driver (number 4) was enabled and counted the steps (its MSCNT changed;
the cartridge driver's did not), but nothing moved in the head and no
filament came out, at 100, 500, 2000 and 20000 steps with the nozzle at
240 °C. Reason found afterwards: **the extruder has a press and a clutch
that the stock firmware works with the motors themselves**
(`StepperPressPositionToOn/Off`, `StepperPressClutchOn/Off`,
`engine_extrPressRelease`, `engine_extrPressAdjust`; console at wake-up:
"PressToOffMovedStep, E:4296, C:2062", "PressToOnMovedStep, E:5075,
C:2436"). The blind steps may have moved that mechanism; the printer
was rebooted to stock, which re-synchronizes it at start-up. **No more
extruder steps under Klipper until those routines are understood on
paper** and a stock extrusion has been recorded.

Also learned: **never send Ctrl-C to the 1X's console.** Sindoh's
engine takes it as its exit signal ("GOT SIGNAL EXIT ... Maybe
Ctrl-C"); it happened once here, to free a console blocked by a
download from a PC file server that had stopped. The microcode kept
regulating and `x1_stop.sh` took over from there. Downloads on the
printer now use `wget -T`.

**5d solved the same day: Klipper extruded** (fork b58960c9, FORK pin
moved; `x1_stage5f.cfg`). The press was not the cause. A recording of
two stock 10 mm feeds and one retract showed:
- the stock firmware uses **another control value on the extruder's
  engine** (0x33024 feed, 0x33034 retract) and on the cartridge
  engine (0x30224 feed, 0x30334 retract) than on X, Y, Z (0x33224).
  With the axis value the extruder's driver counted steps but the motor
  did not turn (so the 22,700 blind steps moved nothing; the owner
  confirmed stock still fed and extruded afterwards);
- **458.8 steps per mm** on the extruder (4588 steps per 10 mm, by the
  engine's own counter), about 220.35 on the cartridge feeder;
- both motors run together on every stock feed and retract, and feed
  is the direction bit clear;
- no clutch, solenoid or press output changes around a normal feed.

With those values and both motors moved together at the stock ratio
(`MANUAL_STEPPER ... SYNC=0`), 1 mm and 5 mm turned the gear train and
15 mm more at 240 °C extruded TPU (owner watching). Owner's note: the
cartridge motor may only be needed with a Sindoh cartridge; to be
tested with the extruder alone in open-filament mode.

The press and clutch, decoded from the FM microcode for later: the
press clutch is GPIO 148 (command argument bit 0) and GPIO 191 (bit 1);
the four solenoids are PWM blocks 18, 8, 24 and 26 (argument bits 0 to
3; run 0x0B, stop 0x0A).

**A stock PLA load jammed afterwards (2026-11-21, open-filament mode,
recorded).** What the recording and console show:
- stock's press-positioning move took about twice its usual travel
  first ("PressToOnMovedStep, E:10495, C:5038"; usual about 5075/2436),
  so the press started from an unusual place;
- the cartridge feed motor then pushed alone for about 25 s; the
  filament reached the extruder's entry sensor (GPIO 120) after 7 s and
  from then on the filament encoder ran at about 60 % of its speed;
- when the extruder motor joined, the load stopped with "Load 405Error
  or 406", and stock then looped with both motors running and the
  encoder barely moving;
- both engines used the normal control values and directions: not a
  repeat of the stuck-direction fault.
**Probably ours, not proven:** the press is positioned by the same two
motors our feed test had just run (21 mm forward under Klipper), which
fits the abnormal press travel; a filament tip catching at the extruder
entry would look the same. To settle it: a stock load after a clean
stock boot with no Klipper feed-motor moves in between.

**Second attempt, same day, after a clean stock boot: jammed again**,
earlier in the sequence: "Load 411Error, Step:440476" 17 s after the
load started, while the cartridge feed motor was still pushing alone
and with no unusual press move before it. That weakens the press
explanation and points at something mechanical in the rear feed path
(the owner switched the printer off to open the rear gear train).
Whether our long retract left something behind there is open.

**Cause found the same evening: not ours.** With the rear gear train
open (photos on the dev PC, `Mainboard_Photos/RODIN_1X/rear_gear_train_20261121`)
the owner saw the second feed stage's gear standing still. Both feed
motors ran under Klipper when stepped one at a time, with clean driver
status: engine 4 is the **initial feed motor**, engine 3 the **rear
(second-stage) feed motor**; what earlier notes call "the extruder" is
this rear motor. The recordings then showed the stock load's staged
checks: in the good cartridge load "Pass411" came 0.8 s after the start,
when the cartridge-side filament sensor (GPIO 80) changed, and the rear
motor started in the second the filament reached GPIO 120. In the
jammed loads GPIO 80 never changed, check 411 never passed, the rear
motor was never started, and the first motor went on pushing into a
stationary gear (second attempt: "Load 411Error"). The owner had fed
the loose filament past that switch (it also reports a cartridge). So
on the 1X the cartridge-bay switch doubles as the filament-in sensor
for the load sequence. The press explanation above was wrong.

The filament was then pulled back under Klipper, cold, with both
motors in the stock retract direction (direction checked first):
1057 mm in total before it was out. GPIO 120 changed after about
330 mm (the tip leaving the extruder), so **GPIO 120 low means filament
at the extruder entry**. The filament path from the cartridge bay to
the extruder is long, about a meter.

Still to do in stage 5: find out what our feed-motor moves do to the
press (before any more of them), the extruder alone in open-filament
mode, the nozzle-contact probe, then a real printer config and a first
print (stage 6). Open: how the extruder and
cartridge motors are stepped.

Plan as first written: Fans, lamp,
beeper; TMC2224 UART (read registers before writing any); one motor at a
time at low current, bed empty; homing; then heaters with low limits.

**6. A printer.** `printer.cfg` for the 1X, bed leveling (the 1X has
active leveling tables in `karas.db`), filament handling, the touch
screen app (the panel is a different size), then a first print.

**7. Installer.** Fold the 1X into the one installer for every model
(TODO 38): `_update_rodin_1x`, AES packing, `/userdata` or the root as
the target, hook into the boot, stock backup and remover.

## Open questions

- Heaters, settled on paper 2026-11-21 (sindoh
  docs/1x_stock_routines.md): PWM block 5 is the nozzle, 28 the bed, 25
  the 2X's other nozzle (unconnected on the 1X, where stock leaves it
  switched on). Thermistors: ADC select 1 nozzle, 2 and 3 bed, the
  DP200's tables and index bases. Not yet driven by Klipper. Whether
  the 1X's hot end has one heater cartridge or two is still open.
- What the motor drivers do when the cores are held (they stayed as they
  were; not looked at closely).
- Bed leveling hardware on the 1X (`gp_En_LevelSensor`, the active
  leveling tables) and the "clutch" and "solenoid" the engine drives.
- Which stepper block is which axis, and the 1X's kinematics limits.
- **Build for the 2X from the start** (owner, 2026-11-21: a 2X is on
  its way). Same board and chassis with a second head: one carriage
  homes at each end of X. The 1X's head is the stock "X2" carriage and
  homes on the left, where the cleaning and filament stations are. So
  the firmware build keeps all eight motor slots and both nozzle heater
  channels, and the 1X config is written as the one-carriage case of a
  two-carriage layout (Klipper `[dual_carriage]` for the 2X). Each
  head has its own filament dump station and cleaning area at its end,
  so the cleaning, load and unload macros take the head as a parameter
  and keep one set of positions per head.
