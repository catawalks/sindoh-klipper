# Status (overwrite in place; last updated 2026-11-25)

The project: Klipper on Sindoh 3DWOX printers, on the printer's own SoC.
Two DP200 setups exist, and they are different on purpose; a third
machine, the owner's 1X, is being ported (its own section below).

## The two printers

| | **Dev printer** (Stanley Model 1 converted to DP200Q) | **Work printer** |
|---|---|---|
| Role | All kernel and hardware testing | End-user stand-in; real prints |
| Kernel | **Our mainline 6.18.59**, in mtd0, two CPUs | **Stock vendor 3.2** |
| Root | Our Debian root, UBIFS in mtd6 (`ubi0:filesystem`) | Stock root + our runtime in `/klipper` (USB stick install) |
| Installed by | Hand, over serial | The USB stick (`docs/usb_installer.md`) |
| Reach | SSH port 2222 and Moonraker :7125 on Wi-Fi 10.10.0.21 (Ethernet .147 is down); serial only when it is at the desk | No link from the dev PC; the owner carries the stick and logs |

**The USB stick carries userspace only** (Klipper, Moonraker, Mainsail, the
screen app, macros, UPC firmware). It never carries a kernel. Kernel work
reaches the work printer at the end-goal install
([end_goal_install_plan.md](end_goal_install_plan.md)), when that printer
becomes the full kernel-swap test machine.

## Since 2026-11-18 (short)

- **Release:** the stick install is public as **v0.1.0, a beta
  pre-release** (payload `0ee46f50`, fork 9b174ab). v0.1.1 (SD/USB
  G-code storage) passed on the work printer on 11-24 but is not
  released on its own (owner): it goes into **v0.1.2**, whose test
  payload is now `9b781a1f` (build `6239434`, 11-25: the screen's full
  repaints and the cancel hand-over; installer and remover that free
  `/klipper` themselves) in the release folder on the PC. The work
  printer runs the one before, `0be1aace` (build `0e557d4`). Draft notes: `kernel/out/release/v0.1.2/release_notes_DRAFT.md`
  on the PC (TODO 49).
- **Repositories:** split on 2026-11-20 (this one, sindoh-kernel,
  sindoh); see the top README.
- **A third machine, the owner's 3DWOX 1X:** see "1X" below.
- **Fork pin:** `klipper/FORK` = `c9887565` since 11-27: `b3b8d837`
  plus the GPIO block output direction (1X and 2X firmware only; the
  DP200's firmware code is the same). `b3b8d837` = tag
  `v0.14.0-sindoh-1` + `sindoh_sound` + a README link: upstream
  Klipper v0.14.0 merged. Its
  DP200 firmware (fm `76a5dc0b`, io `86e3328e`, built in WSL with
  `tools/wsl_fw_build.sh`) runs on the dev printer since 11-24; the
  v0.1.2 payload still carries v0.1.0's firmware.
- Only one printer fits at the owner's desk: the serial cable is on the
  1X; the dev DP200 is reached over SSH.

## Dev printer, 2026-11-24 evening (newest; the sections below are older)

- **Software:** firmware from fork `b3b8d837` (above), v0.1.2's configs,
  macros and model files (`dp200_model.cfg` = DP200), the screen app of
  `8c4245c`, the reboot helper and sudo rule; old files in
  `/root/pre_v012/` on the printer, the firmware before as
  `/opt/dp200/{fm,io}.bin.before_b3b8`.
- **SSH:** dropbear on port 2222, key login
  (`D:\DP200\backup\keys\sindoh_dp200_ecdsa`), starts at every boot;
  Debian 13's armel `dropbear-bin` with its two libraries copied in (the
  NAND root has no apt).
- **Calibration:** probe `z_offset` 2.618 (11-24; PROBE_ACCURACY range
  0.042 mm).
- **Tested 11-24 (owner present):** homing with the 2 mm drop and with
  the Z switch pressed, BED FORWARD, the screen's probe offset, reboot
  from Mainsail. Shutdown resets after 30 s (the debug `hang_wdt=30`
  below; TODO 48). The 4 GB card had to be reseated (it read blank).

## Dev printer back on our system since 2026-11-17 night

The stock Wi-Fi test is over (result: stock held the AP for 2 h with no
drop). Way back done 11-17 (owner-approved four-write job): RAM boot
from the card's gap, `mtd0_kernel_update.sh` (7eae8600, KUPDATE OK),
the saved root tar into mtd6 (md5 1d60d93b, 15331 files, 0 ECC
failures), card marker renamed to `/.dp200-root.off`, boot from NAND:
root ubi0:filesystem, Klipper ready with the saved shapers and mesh.
The section below is current again (Sindoh's 200730_2 update touched
only the stock root, which is replaced again), except that **Wi-Fi
power save is on** (the new default with our kernel, TODO 26) and X uses
`2hump_ei` 87.4 Hz (docs/input_shaping.md). Backups of the stock test:
`D:\DP200\backup\nand_images\stock_test_20261116\` (never published).

## Dev printer, as of 2026-11-15

- **mtd0 (since 2026-11-18):** `m1-nandboot-beeper.uimg`, md5
  `232c743afa9218f26174b401eb4559de` = C3 (the SMP freeze fix) + the GPIO
  bank 3 pad setup (the motor fix) + the beeper pad (bank 5 pin 15).
  Before it: bank3 `7eae8600...` (soaked 3.5 days); rollback images on the
  build box (10.10.0.68:8098).
- **Command line:** `console=ttyS0,115200n8 marvell_nand.write_window=1741,4091 panic=10 consoleblank=0 timer_mv61x0.hang_wdt=30`
- **Wi-Fi module:** `mwifiex_usb.ko` 0028 (`6645762a`): reload-safe.
- **Klipper:** the fork's `sindoh-dp200` ee0c7f8e (the pin in
  `klipper/FORK`) since 2026-11-15: fm `fbc8c0db`, io `16afb0be` (built
  on the build box, default config), klippy and `c_helper.so` `7380efa1`
  from 8203a7d7 (the three commits since then change firmware source
  only). Tested: homing, drift test, 20 mm box. Kept on the printer:
  `fm.bin.tip`/`io.bin.tip` (8203a7d7) and `klippy.cur`, `fm.bin.cur`,
  `io.bin.cur` (the build from before the branch replacement).
- **Config and screen app:** `dp200_macros.cfg` `1154d13d` (11-15: five
  warm-up touches before a mesh), `dp200_printer.cfg` `180033a5`,
  `dp200_screen.py` `561d5ee1`. Its own `printer.cfg` has
  `[axis_twist_compensation]` and probe `z_offset` 2.630 (was 2.580)
  since 11-15 (the old file is
  `printer.cfg.bak-1115` next to it).
- **Other changes of 11-14** (old files kept with `.bak-1114`):
  `rc.dp200` `9a605e09` logs the camera streamer and restarts it;
  `dp200_wifi.py` `1143a67e` limits saved networks to 2.4 GHz.
- **How to test and switch builds:**
  [dev_printer_testing.md](dev_printer_testing.md).
- **4 GB card** is inside as storage; its gap (sector 64) holds the beeper
  image for RAM boots. The 2 GB card is the rescue card: never write it.
- **Works:** boot from NAND, two CPUs (10 h soak on C3), NAND root, Wi-Fi
  (6 h soak), motion, heating, a full print with pause / unload / load /
  empty bin / resume.
- **11-16 additions on the dev printer:** `[input_shaper]` in printer.cfg
  (X 3hump_ei 82.6, Y 2hump_ei 39.0; backup `.bak-1116-shaper`); numpy 2.2.4 for Klipper (copied
  from the card, with libblas/liblapack/libgfortran); `dp200_adxl.cfg.off`
  with `rate: 800`, `max_freq: 135`; `dp200_macros.cfg` with the mesh
  front row at Y 5 (backup `.bak-1116`). Sensor config is off.
- **Bank3 kernel soak:** up 3 days 12 h on 11-16 (booted 11-13), with
  about ten prints, no freeze or reboot.
- **Not yet:** Wi-Fi cold boots (part D);
  the end-goal installer (stages 6-9).

## Work printer, as of 2026-11-25

- Runs the **v0.1.2 test payload `0be1aace`, build `0e557d4`** (the owner
  upgraded from the stick on 11-25, over v0.1.1 `75734d4`, with the SD
  storage card in and mounted). The screen's INFO page shows the build;
  the G-code row shows the card's capacity and Mainsail lists the card's
  files. 56 MB free on the stock root (39 before: the sample prints are
  now on the stick). The STOP hold on the screen stopped it (owner,
  11-25, during a cancel and while idle), and a first print on this build
  finished successfully the same day.
  The cancel hand-over of `9b781a1f` is not on it yet.
- v0.1.1 (11-24): G-code storage on a USB stick and on the SD card
  tested (upload, print, delete, emergency stop, firmware restart; both
  in: the card; neither: internal).

## Work printer, 2026-11-16 (older)

- Runs the 11-15 payload on the stock 3.2 kernel (installed from the
  stick by the owner on 11-16):
  `3e5e43ce1f2c063cf28aae663bfcee91`, 84,430,492 B, build
  `a112379 2026-11-15`. Userspace only. It carries the fork at 8203a7d7
  (klippy, helper, fm/io: the dev printer is three firmware commits
  newer, ee0c7f8e), the 11-12 and 11-15 macros, the screen app
  `561d5ee1`, the camera restart loop and the 2.4 GHz Wi-Fi limit. Its
  printer.cfg has no `[axis_twist_compensation]`. PC copies: this
  payload in `D:\DP200\kernel\out\payload_20261115`, the one before
  (`5f3336e1`, 11-07) in `D:\DP200\backup\usb_stick_copy_20261115_before`.
  Confirmed by the owner 11-16: SYSTEM -> INFO shows that build, the
  first print (the ADXL head mount, PLA) came out good, the prime line
  is in its new place, and Mainsail's MCU panel showed the UPC load
  live during the print.
- 11-16 is the first time this Klipper (on upstream 29d4ec2d) runs on
  the stock 3.2 kernel; before, only on the dev printer's mainline kernel.

## 1X (the owner's, stock firmware `ROD1X_200916_2`), as of 2026-11-22

Since then (11-23/24): speed test passed at 197 mm/s and 2500 mm/s²
(the config's `max_accel` now); the speaker plays (`sindoh_sound`); a
time zone page; Moonraker's reboot request works; SSH from the PC
through Sindoh's dropbear, started over serial (`D:\DP200\kernel\out\x1\rs.sh`,
RAM only); the start scripts set their own PATH and run over SSH too.
On 11-24 night it runs our stack (started over SSH), idle, not homed.

- **How it runs:** everything of ours is on the SD card `1x-dev` and in
  RAM; nothing is written to the eMMC, and a reboot returns to stock.
  After a stock boot: mount the card, `x1_stage4.sh start printer.cfg`
  (stops Sindoh's motion program, loads our firmware on both cores),
  then `x1_web.sh start` (Moonraker, Mainsail on port 80, camera, our
  screen app, the power helper). Reach: serial console on the dev PC's
  COM3, Ethernet 10.10.0.169, SSH port 2222 once started.
- **Port stage:** 6 of [1x_port_plan.md](1x_port_plan.md), nearly done.
  Works under Klipper: homing on all axes, both heaters (PID tuned),
  load, unload, nozzle wipe and bin routine copied from stock, bed
  leveling by nozzle touch with its screen page, print start and end,
  a first print (20 mm box, 11-22), 720p camera, the touch screen
  including NETWORK (view), UPDATE and INFO.
- **Config:** `klipper/config/x1/` (`printer.cfg`, `x1_printer.cfg`,
  `x1_macros.cfg`), the DP200's layout. Limits: 197 mm/s, `max_accel`
  2500 (speed-tested at 2500 on 11-24), Z zero by paper test (`position_endstop`
  2.100). X is the stock and slicer frame since 11-23 (0 at the bed's
  left edge, home on the left at negative X); before that it was
  mirrored.
- **Not yet:** a print with the 11-22 speed settings, the mirror check
  (big L), reboot and shut down from the screen (dry-run only), a cold
  start without Sindoh's program, the install onto the eMMC (stage 7),
  WiFi set-up from our screen. Open list: TODO 41 and 44, and
  "Owner at a printer".
- Stock facts and recordings: [sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md),
  [sindoh: 1x_stock_routines.md](https://github.com/catawalks/sindoh/blob/main/docs/1x_stock_routines.md).

## 2X (the owner's, stock firmware `PRIME_210419_2`), as of 2026-11-28

- Arrived and set up 2026-11-27; runs stock. Surveyed with the stick
  and read over the stick's remote shell (port 2222, key login; it
  ends at the next reboot). Nothing on it was changed; no motion, no
  heat. Facts: sindoh `docs/2x.md`; plan: [2x_port_plan.md](2x_port_plan.md).
- It is the family's NAND board (stock's "Prime_r1", board name
  `TOC`): the 1X's hardware with a NAND root (42 MB free), no eMMC,
  Sindoh's factory SD card in the socket. Five lines sit on other
  pins than on the 1X and there is no pin 69.
- Stock's watcher on it must be frozen before any stock program is
  stopped (`x1_stop.sh` does that on this board; only the freeze
  itself has been tried there).
- The screen app knows the board and shows two nozzles; Klipper has
  not run on it. Our system's home is made: an empty ext4 file
  system (label `klipper2x`, 6.3 GB) on partition 4 of Sindoh's card
  (2026-11-28, owner's OK; the rest of the card is untouched). Open:
  putting the root there and what starts it at power-on, the serial
  boot capture, the look-only takeover.

## Who owns what

One session coordinates: it alone drives the dev printer (serial, deploys,
NAND writes), merges `TODO.md` and publishes to GitHub. The others write
and build in their own area and report files and md5s.

| Area | Where the work lives |
|---|---|
| Coordination, printer access, macros and config, install, docs | this repo (`sindoh-klipper`), dev PC |
| Kernel and boot (SMP, NAND, build variants) | build box `~/SINDOH-DEV`, served on 10.10.0.68:8098; summary in `sindoh-kernel docs/smp_freeze_summary.md` |
| Motor / UPC driver | build box `~/SINDOH-DEV/motor`, branch `upc-bank3-pads` (75743ea, local; its two commits are in the sindoh-kernel repo as c72b89e and 94813ae) |
| Wi-Fi (8782 driver, firmware study) | build box; `TESTPLAN.md` and `upstream/` there; facts in `sindoh-kernel docs/wifi_88w8782.md` |
| Klipper code (UPC MCU port, stepping, host modules) | the fork `catawalks/klipper`, branch `sindoh-dp200`; the pinned commit is `klipper/FORK`; rules in `klipper/README.md`; `docs/faster_stepping_plan.md` |
| Touch screen app | `install/display/` in this repo; `docs/touchscreen.md` |

Publishing: commit here and push `main` to `catawalks/sindoh-klipper`.
Kernel work is published from the `sindoh-kernel` checkout, model research
from the `sindoh` checkout.

## Standing rules (short; the reasons are in the docs they point to)

- NAND: [nand_layout.md](nand_layout.md). Every NAND write needs the
  owner's OK; RAM-boot a kernel first.
- **Never home Z with anything on the bed** (Z homes upward).
- 1X: no writes to its eMMC, boot settings or database; never send
  Ctrl-C or anything during the boot countdown on its console; any
  connection to port 7126 is the emergency stop.
- Motion or heat only with the owner present.
- Check the printer is idle before restarting Klipper or the screen app.
- Never publish Marvell firmware or images, or Wi-Fi networks.
