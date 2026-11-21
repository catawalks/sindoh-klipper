# Klipper on the Sindoh 3DWOX 1X: port plan

**Status (2026-11-20): planning. Nothing of ours has run on the 1X.** The
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

**0. Paper work (PC only).** Done so far: the comparison above. To do:
- `upc_6270.ko`'s ioctl numbers and structures against the DP200's
  (`host/upctool.c`), from the two modules.
- The 1X `fm`/`io` microcode's start-up: what it writes to the PWM, ADC,
  GPIO and stepper blocks (emulate it, as `tools/fmprobe.py` and
  `pwmprobe.py` do for the DP200). This gives the heater PWM channels,
  the ADC channels of the three thermistors, endstop inputs, and the
  step/dir/enable wiring of each stepper block.
- The thermistor tables as Klipper `[adc_temperature]` sections
  (`tools/gen_thermistors.py`).
- The TMC2224 setup the engine sends (registers and values), and the
  select-line code for each motor.

**1. A Debian root on the 1X (no hardware touched).** A Debian armhf
root in `/userdata/klipper` (owner's OK needed: first write to the eMMC),
built with the DP200's `install/build_rootfs*.sh`, entered by chroot.
Klipper, Moonraker and Mainsail installed but not started. Check: the
chroot runs, Python and the Klipper host code import, nothing of Sindoh's
is disturbed.

**2. Look, don't touch (stock engine running).** `upctool` built for the
1X map, read-only commands only (`info`, `dump` of the shared DTCM): do
our tools see the stock firmware's state the way they do on the DP200?

**3. Passive probe on the UPCs (owner present).** Stop Sindoh's engine,
load our probe firmware (`upc_fw/probe`, reads registers, drives
nothing), read the report, reboot. Before stopping the engine: confirm
what its outputs do when it dies (heaters and motor enables must go
off; on the DP200 they do). Check: the probe report matches stage 0.

**4. Klipper firmware, inputs only (owner present).** The fork gets a
1X build (`config/x1_fm.config`, `x1_io.config`: 6270 map, stepper
offsets). Both MCUs connect to klippy; read thermistors, endstops, fan
tach and filament sensors. No outputs enabled in the config.

**5. Outputs one at a time (owner present each time).** Fans, lamp,
beeper; TMC2224 UART (read registers before writing any); one motor at a
time at low current, bed empty; homing; then heaters with low limits.

**6. A printer.** `printer.cfg` for the 1X, bed leveling (the 1X has
active leveling tables in `karas.db`), filament handling, the touch
screen app (the panel is a different size), then a first print.

**7. Installer.** Fold the 1X into the one installer for every model
(TODO 38): `_update_rodin_1x`, AES packing, `/userdata` or the root as
the target, hook into the boot, stock backup and remover.

## Open questions

- What the engine's death does to heaters and motors (stage 3 gate).
- Does a watchdog or `recovery_watchdog.sh` react when the engine or
  UIManager is stopped? (`recovery.check.sh --post-process-integrity`
  restarts programs; it must be paused for our tests, not fought.)
- Bed leveling hardware on the 1X (`gp_En_LevelSensor`, the active
  leveling tables) and the "clutch" and "solenoid" the engine drives.
- Which stepper block is which axis, and the 1X's kinematics limits.
- The 2X shares this code (two X carriages); keep the 1X work general
  enough to add it.
