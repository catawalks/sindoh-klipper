# 1X: install, boot, uninstall and update (stage 7 plan)

**Status (2026-11-24): plan, nothing installed.** Today everything of
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
| Power button | ours (stock's `powerkeyd` frozen) | the same, started by the hook |
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
