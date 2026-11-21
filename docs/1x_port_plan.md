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
- The 1X's PWM control register is not the DP200's (values seen: 0x28,
  0x29, 0x2C, 0x0A, 0x0B, 0x18, 0x6C), so the DP200's "safe" writes must
  not be used here: `upctool --passive` skips them and the probe has a
  look-only build (`make X1=1` in `upc_fw/probe`, `prebuilt/probe_x1_*.bin`).
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

- Which of PWM blocks 5 and 28 is the nozzle and which the bed, and how
  the ADC values map onto the two thermistor tables (the bed channel
  fits the bed table by plain index; the nozzle channel is not matched
  yet). The owner suspects two heater cartridges in the hot end.
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
