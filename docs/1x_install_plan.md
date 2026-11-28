# 1X: install, boot, uninstall and update (stage 7 plan)

**Status (2026-11-27): the boot hook is installed (warm takeover, root on the SD card); the rest is a plan.** Today everything of
ours runs from the SD card `1x-dev` and RAM, started by hand after a
stock boot ([1x_port_plan.md](1x_port_plan.md), "Stage 6 as it
stands"); a reboot returns to stock. This page is how that becomes an
installed system that starts by itself, can be removed, and can be
updated. Every write to the 1X's eMMC needs the owner's OK, each time.

The facts below were read from the owner's 1X on 2026-11-23 (its boot
scripts copied to the PC; nothing run). Stock facts that are not about
installing live in [sindoh: 1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md).

## How the stock 1X boots

1. U-Boot, the kernel, then BusyBox init (`/etc/inittab`):
   - `sysinit`: `/app/recovery.check.sh --prior-integrity` = `fsck.ext4
     -fy` on the root (`mmcblk0p2`). Errors it cannot fix ask for a
     recovery boot.
   - `/etc/init.d/rcS` runs `S01` to `S59` in order: logging, **S02
     powerkeyd**, avahi, udev, urandom, **S21 watchdog** (BusyBox
     `watchdog -t 25 -T 60`, then `watchdog_reason` = 2 = "normal"),
     dbus, modules, network, ifplugd, avahi, dropbear, snmpd.
   - The serial console logs in root by itself (`getty -l
     /app/autologin.sh`); the login shell reads **`/etc/profile`**,
     which runs `/etc/date_check.sh` (time zone from the database),
     `/app/audio_amp.sh` and **`/run.sh`**.
2. `/run.sh` (Sindoh's start of everything):
   - pin set-up (`/app/pinconf.sh`), loads `/app/upc_6270.ko` (the
     `/dev/upc0`/`upc1` our `upctool` uses), the USB gadget, `mdev`, a
     message queue, two clock registers;
   - an unfinished firmware update (`/updating_usb`,
     `/updating_network`) shows a message and stops here;
   - `recovery.check.sh --prior` (a full file check if a stamp asks
     for it);
   - **`/app/UIManager`**, which starts the motion program
     (`marvell_lspsdk_3dp_granite2-debug_stripped.elf`) and the screen
     (`/app/appBrowser`);
   - **`/app/recovery_watchdog.sh &`** and **`recovery.check.sh
     --post &`** (below).
   The motion program does not home anything at boot; it heats the
   nozzle and bed to its idle temperatures (the console shows "FULL
   Heater ... BD Target Reached!").
3. USB firmware updates: `/app/auto_update.sh` (started by Sindoh's
   programs when a stick is in) reads `/mnt/sda1/_update_rodin_1x/`,
   runs every `unmistakable*.she` there first, then `update.she`
   (AES with the 1X's key, as on the DP200: sindoh
   `docs/other_models.md`). That is the route a 1X installer stick
   takes, as on the DP200.

## What makes the stock 1X reinstall itself

A "recovery boot" rewrites the system from the recovery partition
(`mmcblk0p5`). It is asked for by writing 1 to
`/sys/kernel/watchdog_reason`. Sindoh's scripts do that when:

- **the root stays read-only for 10 s** (`recovery_watchdog.sh`,
  checks every 50 s);
- a file under `/app /bin /boot /etc /lib /sbin /test /usr` or the
  motion program **cannot be read** (`recovery.check.sh
  --post-file-integrity all`, 60 s after boot: `md5sum` of every regular
  file; only read errors count, the sums are not compared with
  anything);
- the boot `fsck` finds errors it cannot fix.

So for an install:

- **Adding files is safe;** a changed file is safe too, as long as it
  reads. Nothing compares contents.
- **Never leave `/` read-only** while `recovery_watchdog.sh` runs.
  Our power-off path remounts it read-only on the way out, so it freezes
  that script first (`x1_web.sh`, 2026-11-23).
- Never write 1 to `watchdog_reason` (standing rule).
- The process check (`--post-process-integrity`) only prints a message
  when the motion program is gone; it does not ask for recovery.

## Where our system goes

- **`/userdata`** (`mmcblk0p6`, ext4, 4.2 GB, mounted at boot from
  `/etc/fstab`, empty, used by no stock program): `/userdata/klipper/`
  holds the Debian root (about 920 MB) that the SD card holds today,
  used as a chroot in place.
- Sindoh's own updates use `/userdata` as scratch space for the root
  image when it has room (`update.sh`: free space above the image size
  plus 50 MB), and fall back to `/systemdata`. **Keep at least 1 GB
  free there** so a Sindoh update still works; never put anything
  outside `/userdata/klipper/`.
- The SD card is then not needed.

## Boot: two steps

**Step A, "warm takeover" (first install).** Stock starts as it does
now; ours takes over once it is up, exactly what is done by hand today
(`x1_stage4.sh start` stops the motion program, holds the cores, checks
the heaters, loads our firmware; `x1_web.sh start` brings up Moonraker,
the screen app, the camera and the power button). Proven every day
since 11-21. The hook:

- **one new file, `/etc/init.d/S99klipper`** (`install/x1/S99klipper`,
  written 2026-11-24, not installed): rcS runs it last; it
  starts a background waiter and returns. No Sindoh file is changed
  (uninstall = delete it). A Sindoh firmware update replaces the root
  and with it the hook: the printer is then stock again, with our files
  still in `/userdata`.
- `S99klipper` runs `/userdata/klipper/boot.sh` (`install/x1/x1_hook.sh`,
  written 2026-11-27; dry run in RAM on the printer the same day, SSH
  login checked on a test port). It first starts **SSH** (stock
  dropbear, port 2222, key only; host key and `authorized_keys` kept in
  `/userdata/klipper/ssh/`, so the host key survives reboots), also when
  `BOOT_STOCK` is set, so a printer away from the serial cable can
  always be reached. Then it finds the root: `/userdata/klipper/root`
  when installed, otherwise the SD card (mounted at `/tmp/sd`), and
  runs that root's `stage/x1_boot.sh`. With the card as root the eMMC
  holds only `S99klipper`, `boot.sh` and the two key files.
  **Installed on the owner's 1X 2026-11-27** (owner's OK), root on
  the card: a reboot with `BOOT_STOCK` gave stock with SSH up 10 s
  after power-on; a reboot without it had Klipper, Moonraker and the
  screen up by themselves 90 s after power-on.
- **Never a login shell over SSH:** `/etc/profile` ends with
  `/run.sh`, so a login shell would start Sindoh's programs a second
  time. The hook gives every key a forced command that runs a
  non-login shell (interactive sessions checked 11-27).
- The waiter (`install/x1/x1_boot.sh`; dry runs on the printer
  2026-11-24: refuses a missing root, honors `BOOT_STOCK`, waits for
  the motion program) takes over once the motion program has started and
  finished its start-up (the "IO Ready" point), and **does nothing**
  when: `/userdata/klipper/BOOT_STOCK` exists, an update is unfinished
  (`/updating_usb`, `/updating_network`), or a stick with
  `_update_rodin_1x` is in (Sindoh is updating, or about to).
- If our system is missing or broken, stock simply keeps running: a
  failed takeover leaves a working stock printer.
- Cost: for the first 30 to 60 s after power-on stock runs, heats a
  little and shows its own screen.

**Step B test mode (written 2026-11-27, not installed):** `S99klipper`
now runs `boot.sh early` before the console logs in. With
`/userdata/klipper/BOOT_COLD_ONCE` (removed at once, so the next boot
is a normal one) it covers `/run.sh` with a RAM copy holding only the
hardware part of Sindoh's own script (up to the two clock registers);
Sindoh's programs and recovery checks are not started. The hook then
starts SSH, mounts the card and stops, for the driver set-up and the
Klipper start by hand. Open for a cold start: WiFi (stock's programs
bring it up from their database; the wired port comes up from the
init scripts), the screen's backlight, and the unknowns in
[1x_port_plan.md](1x_port_plan.md) stage 7 item 4.

**First cold starts, 2026-11-27 (owner present, steps by hand):**
- The covered `/run.sh` works: no Sindoh program starts, the heater
  PWM blocks read 0, the wired port and SSH are up 10 s after power-on.
- The driver UART and its select GPIOs work without the stock program
  (`x1_tmc.py setup` exports them).
- **The SoC GPIO outputs are inputs until Sindoh's motion program
  starts**, and our firmware only writes levels. First try: the drivers
  were never enabled and homing ended in "No trigger after full
  movement" with nothing moving; the microstep pins read 32 (4 on the
  cartridge feed). `x1_stage4.sh` now sets the stock outputs and
  levels on a cold start (`cold_pins`, table taken from the difference
  between a cold start and the takeover); `x1_tmc.py setup` also
  selects 16 microsteps by register if the pins do not give 16.
- With that, Klipper started cold and **X, Y and Z homed** (bed empty,
  owner's word), temperatures and filament sensors read as usual, the
  PSU fan runs with the motors.
- **Heat and a print from that cold start (same day):** nozzle to
  200 C in about 60 s, bed to 60 C, PSU and head fans on with the
  heaters; `x1_box_20mm.gcode` printed start to end (306 s, 350 mm of
  filament, as on 11-23), bed check answered through the macro.
- **Automatic (same day):** a cold boot now runs `x1_boot.sh` like a
  normal boot, without the wait for Sindoh's program: Moonraker
  answered "ready" about 35 s after power-on (takeover: about 90 s),
  and X, Y and Z homed. `COLD_MANUAL` stops after SSH and the root; a
  failed cold start leaves `COLD_FAILED`, and `BOOT_COLD` is ignored
  until that file is removed.
- The lines in `cold_pins` that were not in our config are named in
  `x1_stage4.sh` (from Sindoh's motion program and microcode); only
  GPIO 156 (set high once at start) has no known use.
- **WiFi and addresses on a cold start are ours, as on the DP200
  (same day).** A first version copied the network from Sindoh's
  database at every boot; the owner asked for the full replacement, so
  that script is gone. `x1_web.sh` `net_start` now runs the DP200's own
  scripts from `<root>/dp200/` (`dp200-wifi.sh`, `dp200-wifi-action.sh`,
  `dp200-netd.sh`; the 1X has the same WiFi module, `wpa_supplicant` and
  database tables): the first run imports the secured networks saved on
  Sindoh's screen into `<root>/etc/dp200/wpa_supplicant.conf` and a fixed
  WiFi address into `network.json`; from then on both are ours, and the
  touch screen's WIFI and WIFI IP pages work (they are on once
  `/run/dp200/net.ok` exists, so not on a takeover boot). Checked: joined
  8 s after start, fixed address kept, Moonraker ready over WiFi 33 s
  after power-on, a scan through `dp200_wifi.py` lists networks. Owner,
  same day: the WIFI IP page switched the address to DHCP, and a cold
  start with the wired port unplugged came up on WiFi alone (Moonraker
  ready about 30 s after power-on). Not checked: joining another
  network from the WIFI page. The stock 1X has no `mlanutl`, so a scan
  uses `wpa_supplicant`'s own (the link drops for about 10 s).
- **The cold start is the default since 2026-11-27** (owner):
  `/userdata/klipper/BOOT_COLD`. The card also runs the screen app of
  that day (it had the 11-24 one; the old file is
  `/usr/local/bin/dp200_screen.py.prev` on the card).
- Still open: the reference blocks' second register, the estop route
  (`X1_PC`) at boot, the firmware setting pin directions itself, and
  `build_root_1x.sh` putting the three network scripts into
  `<root>/dp200/` (copied by hand so far).

**Step B, "cold start" (later).** Ours starts instead of Sindoh's
programs: no stock heating, no stock screen at boot. **The stock program
also sets up the eight TMC2224 drivers** at start (sindoh
`docs/tmc2224_setup.md`: GCONF, IHOLD_IRUN, PWMCONF, TPWMTHRS over
`/dev/ttyS2`, select GPIOs 146, 147, 149, decoder 152); today Klipper
runs on that set-up. A cold start has to write the same first:
`tools/x1_tmc.py setup --yes` does that (written 11-22, not run on a
cold printer yet; `x1_stage4.sh` runs its read-only `check`). It also needs (1) the
cold start without the motion program to work (prepared, not tried:
[1x_port_plan.md](1x_port_plan.md), stage 7 item 4), and (2) a way to
keep `/run.sh` from starting `UIManager`. Candidate (owner 11-24:
the warm takeover is not the favorite, so this comes next): the same
`S99klipper` bind-mounts our own `/run.sh` from `/userdata/klipper`
over Sindoh's before the console logs in (rcS runs before the
getty). Ours does Sindoh's hardware set-up (pins, `upc_6270.ko`, the
gadget, `mdev`, clocks) and starts our system instead of `UIManager`.
No Sindoh file changes, `/run.sh` is outside the folders the
integrity check reads, the mount is gone at the next boot, and
`BOOT_STOCK` or a missing install skips the mount.

## The way back to stock

- **From our screen:** SYSTEM -> POWER -> "Next start: Sindoh" (to
  build) writes `BOOT_STOCK` and reboots. Stock then runs at every
  start until the flag is removed. Sindoh's screen cannot remove it,
  so that takes a stick (below) or the console.
- **From a stick:** a `_update_rodin_1x` stick with only our
  `unmistakable_klipper_boot_stock.she` sets the flag (or removes it).
- **Never** use the power button at power-on: U-Boot reads that line
  and asks for the recovery boot (sindoh `docs/1x.md`).

## Install, uninstall, update (USB stick, as on the DP200)

- **Install** (`unmistakable_klipper_install.she` in
  `_update_rodin_1x/`, run by `auto_update.sh` under stock): unpack the
  payload into `/userdata/klipper/` (check the space first, keep 1 GB
  free), write `x1_machine.cfg` from the database
  (`install/x1/x1_machine_cfg.sh`, written 2026-11-23), keep an
  existing `printer.cfg`, add `S99klipper`, show the result on the
  screen, reboot.
- **Uninstall** (`unmistakable_klipper_remove.she`, or from our
  screen): delete `S99klipper` and `/userdata/klipper/` (refuse while
  anything is mounted inside it), reboot to stock.
- **Update:** Mainsail from the screen's UPDATE page (works today);
  Klipper, Moonraker and our programs from a new stick payload (the
  installer replaces the program files and keeps `printer.cfg`,
  `x1_variables.cfg` and the logs).
- One installer for every model (TODO 38): it recognizes the model by
  `/sys/kernel/board_name` and the firmware tag and takes the 1X path.

## Things stock does that the installed system must do

| | Today (beside stock) | Installed |
|---|---|---|
| Network (Ethernet, WiFi) | stock's `udhcpc` and `wpa_supplicant` | step A: still stock's; step B: ours (`dp200_wifi.py`, `dp200_net.py`, as on the DP200) |
| Time zone | copy of stock's `/etc/localtime` | the same; our own setting later (TODO 47) |
| Power button | ours (stock's `powerkeyd` frozen) | the same, started by the hook. A hold switches off, and during a print it is the emergency stop first (both tested 11-27); the POWER menu and Mainsail can only shut down and then show "It's now safe to turn off your printer", because the power board ignores GPIO 158 without a hold (sindoh `docs/1x_r4.md`) |
| Watchdog | BusyBox `watchdog` (stock) | keep it |
| Camera | ustreamer (ours) | the same |
| Stock web page, port 9100 printing from Sindoh's slicer | stopped | stopped |

## Order of work

1. Owner present, no writes: after a stock boot, run
   `X1_BASE=<a folder whose root/ is the card> sh x1_boot.sh` by hand
   (what `S99klipper` would run) and check the takeover point. The
   start scripts take the root's place from `X1_ROOT` since 2026-11-24
   (default: the card).
2. Owner's OK: copy the root to `/userdata/klipper/`, run from there
   by hand (the card out).
3. Owner's OK: add `S99klipper`; power cycles: normal start, the
   `BOOT_STOCK` flag, a stick present, a broken install (stock must
   keep running).
4. The stick installer, uninstaller and update payload for the 1X.
5. Step B (cold start), after its own test.
