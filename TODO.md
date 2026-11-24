# DP200 Klipper port - open items

**Open items only.** When an item is done: delete it here and add a line to
[docs/history/CHANGELOG.md](docs/history/CHANGELOG.md), in the same commit
as the work. No test logs here. Rules and the documentation map:
[docs/README.md](docs/README.md). Current state of the printers:
[docs/STATUS.md](docs/STATUS.md). Larger projects: [PROJECTS.md](PROJECTS.md).
The list as it stood before 2026-11-12, with all results:
[docs/history/TODO_archive_2026-11-12.md](docs/history/TODO_archive_2026-11-12.md).

## Owner at a printer

Dev printer:
2. **Load jam, filament held back mid-load** (optional; the empty-inlet
   case passed 11-12).
3. **Screen app's load error pages on hardware:** the running page after
   TRY AGAIN and the plain page for homing errors (0cc6a77) are deployed
   but have not seen an error yet. Also run `test_dp200_screen.py` on the
   printer.
4. **Screen features never used on hardware:** the calibration wizards
   (Z HEIGHT paper test, PROBE OFFSET, PID TUNE, SAVE Z OFFSET), WiFi ->
   SAVED (PREFER / FORGET). The custom MACROS page opens and lists the
   macros (owner, 11-16); adding an own macro and running one from it
   is not tried.
5. **Touch screen INPUT SHAPING page:** never tried on hardware (needs
   the accelerometer plugged in).
6. **Dryer leftovers:** STOP DRYING, PRINT_START during drying, FORCE=1
   above the 70 C sheet limit.
7. **A real Mainsail update** from SYSTEM -> UPDATE (only CHECK NOW tried).
8. **Ethernet recovery after a switch outage:** `dp200-netd.sh` restarts
   udhcpc after 30 s without an address; never exercised (pull the cable
   or power the switch off).

Either printer:
13. **Beeper:** mapped 11-18 from the stock app (docs/hardware_notes.md
    "Beeper"): passive piezo on dec_pwm block 10, control 0x18, volume by
    duty. **Heard 11-18 (dev printer)** once GPIO bank 5 pin 15 had its
    stock pad function (0x000C1001); our kernel leaves it a GPIO.
    Measured with the owner's spectrum analyzer: the timebase ticks at
    5 MHz, so stock's 250 ticks is 20 kHz (only a tick); **1250 ticks =
    4 kHz at 36 % duty sounds like stock** (owner's pick). Done 11-18:
    fork 9b174ab, `[output_pin beeper]`, M300 (36 %, owner: sounds like
    stock), the dryer's end signal. The kernel sets the pad (DTS
    `5 15 0x000c1001`): m1-nandboot-beeper 232c743a (= bank3 + this pad)
    RAM-booted (beep heard, no devmem step) and in mtd0 since 11-18. Left:
    - Stock pitch: **left as is** (owner, 11-20). The work printer's
      beeper is faulty (barely audible at the highest stock setting).
      **The owner measured a stock 1X's beep at 4 kHz** (11-20), the same
      as our 1250 ticks; a stock DP200 is still unmeasured (check if one
      turns up). Our M300 on the vendor kernel (stick install) is
      unchecked, since the work printer's beeper is faulty.
    - Optional: tones (M300 S<Hz>) need the firmware to take the period
      from Klipper's cycle_time for this block.
16. **Homing clearance:** a few mm of Z clearance before X homing, so the
    nozzle doesn't drag across a failed print. Mind that Z homes upward.

1X (get a fresh "bed empty" first; background in items 41 and 44):
- **First layer over the whole bed** (`x1_xy_scale_150mm.gcode`, the
  bed's bow) after the Z paper test. The Benchy of 11-23 completed in
  the corrected X frame; its quality is the owner's to judge.
- **Z zero:** paper test at the bed center, then a first layer print
  (`x1_first_layer.gcode`).
- **Speed test at the new acceleration:**
  `tools/x1_speed_test.py 197 2500 5` (passed at 2000).
- **SYSTEM -> POWER:** SHUT DOWN (never run), and REBOOT from the
  screen (the same helper rebooted fine from Mainsail's side 11-23).
- **Remote reboot** (item 48): with the console back, copy the three
  files to the card's stage folder and restart the web side, then try
  Mainsail's power menu. Installed 11-23 with the screen app and
  macros of that day: try BED FORWARD on the MOVE page too.
- **Runout sensor** during a print; a held-back filament for the jam
  check.
- **Cold start** without Sindoh's program (port plan, stage 7 item 4).
- **Boot takeover by hand** (no writes): after a stock boot, run the
  boot hook's script from the card instead of the two start commands
  ([docs/1x_install_plan.md](docs/1x_install_plan.md), "Order of work"
  1). Then the owner's OK for the first eMMC writes (root to
  `/userdata/klipper/`, then `S99klipper`).
- Z and the extruder at their limits (12 and 86 mm/s).

## Printer tuning

Print quality and speed settings, found with test prints (owner at the
printer for each print). Results go into the printer's printer.cfg, the
shipped config or the slicer profiles.

9. **Work printer has no `[axis_twist_compensation]`:** if wide first
   layers are uneven left to right there, do the comparison in
   docs/dev_printer_testing.md on that printer (see also #29).
10. **Resume quality on real prints:** some straggler lines at the resume
    layer after a load (11-12). Tune `reprime_len` (30 mm) if needed.
12. **Print speed** (owner asked 11-15; goal: faster prints at the same
    quality, no mechanical changes). Today: test prints at 30 mm/s,
    `max_accel` 1500, no input shaping. X/Y are proven to 208 mm/s. In
    this order:
    a. **Max flow:** measured 11-17 (dev printer, PLA at 205 C, into the
       air): normal to 14 mm3/s; 16 and 18 came out thicker (the owner
       sees no other difference on matte gray PLA); extruder clicks at
       20. Slicer max volumetric speed 12 for now (the owner's profile
       has 8), 16 probably safe to try later. 12 is about 145 mm/s at
       0.45 x 0.2 mm. Test file `dp200_max_flow.gcode`. First fast
       Benchy started 11-17 (`dp200_benchy_fast.gcode`: 12 mm3/s, outer
       walls 60, inner 100, infill 130, travel 180, accel 2500).
       Result 11-17 (1h 16m printing, owner's photos): hull, bow, chimney,
       door arch, roof top and the bottom text good; fine hairs all over
       (stringing; retraction 4 mm at 35, 205-210 C; the PLA is dry: it
       sat on the bed through the dryer test); stern text illegible; a
       rough patch at a stern corner about 5 mm up (#18). Next: #14 and
       12c.
    b. **Input shaping:** X measured on the dev printer 11-16
       (docs/input_shaping.md "Dev printer, 2026-11-16"): Klipper
       recommends `3hump_ei` 80-83 Hz, max_accel <= 4300 (three runs,
       the last with head mount version 4, which homes X fine); the X
       peak is at 38-47 Hz. Y measured 11-16 with the bed bar: `2hump_ei`
       39.0 Hz, max_accel <= 1500; wide Y peak at 27-40 Hz. Y is the
       limiting axis. Both picks are in the dev printer's printer.cfg
       since 11-16; no print with them yet. Left:
       - Ringing test print with the saved shapers: started 11-16
         (`dp200_ringing_tower.gcode`, 1500 to 4250 in 5 mm bands);
         Y clean to 2750, X rings at sharp corners in every band.
         `dp200_x_shaper_compare.gcode` (six X shapers in 10 mm
         bands at 2500, 11-17): no band differs, so the visible X
         ripple is not the measured 38 Hz peak (docs/input_shaping.md).
         Cause: the head sits on magnets and a loose dovetail
         (owner); ripple about 4 mm = about 20 Hz. X set to the
         fastest band, `2hump_ei` 87.4 (max_accel 8094). A new
         carriage mount is a future project. Earlier plan, kept for
         reference: keep
         them, or a lighter one (X: ei ~42; Y: ei 40 or mzv 29.4,
         which allow 2500-2900), and put the result in the shipped
         config.
       `max_accel` 2500 on the dev printer since 11-17 (owner; its printer.cfg,
       the shipped dp200_printer.cfg stays 1500 for printers without shapers).
       Next: prints at the higher speeds (12c, 12d).
    c. Re-tune pressure advance at the new speeds; check part cooling.
    d. Slicer profile with the result (expected: walls and infill
       80-120 mm/s, travel 150-200), then the payload.
14. **Retraction test** (two towers; the 11-17 Benchy strung at 4 mm /
    35 mm/s with dry PLA), maybe a temperature tower, then the slicer
    profiles; recheck pressure advance (0.30, set 10-28 on damp PLA at
    slow speeds) with the dry filament (12c).
15. **Mesh front limit at Y 5** (was 30; six rows): a mesh ran clean
    on the dev printer 11-16 (30 points, reference check -0.019 mm;
    front row about 0.1 mm lower than the row behind it). Left: a first
    layer printed at the front of the bed, before the next payload
    carries the change to the work printer.
17. Optional: a 6-7 mm/s Z lift test (10 stalls lifting; stock is 5.05).
18. **Benchy: damaged port stern corner** (not the Z seam): in `dp200_benchy_fast.gcode`
    (`seam_position = aligned`) the hull's outer wall starts and ends at
    the stern corner (X 77, Y 92-95) on every layer from about 3 to 10 mm;
    the rough patch at about 5 mm is there, where the stern text and its
    short moves and retractions begin. **11-18, corrected:** the damage is
    on the port stern corner, which faced the back of the bed (high Y);
    the seam was on the starboard one. At 3-7 mm the G-code is the same
    at both stern corners (same speeds, same kind and number of
    segments, no seam or retraction at the damaged one), so the cause is
    not in the G-code. Suspects on the printer side: part cooling that
    reaches that corner less (where does the part fan blow?), the
    corner curling up there and the nozzle catching it, or the loose
    head (12b). Next: note the fan direction, print a small test
    (e.g. four 20 mm towers in the bed corners, or the Benchy turned
    180 degrees) and see if the damage follows the bed side or the
    model side.
28a. **Mesh reference drift:** PRINT_START's mesh was discarded once in
    five prints on 11-15 ("reference probe moved -0.112 mm", limit 0.1).
    Cause: the pin keeps settling for about 25 touches after a deploy
    (40 touches: first one +0.04 mm, then a slow fall of 0.02 mm on a
    cool bed and 0.07 mm on a bed cooling from 60 C), and the mesh starts
    as soon as the bed reaches temperature. Options: more warm-up touches
    (`variable_warmup`, now 5; 25 adds about 3 min), a soak of a minute or
    two after the bed reaches temperature, or both. Measure which helps.
    The Z motor is not losing steps (the readings level off).
29. **Probe: false left-right slope** (found 11-14, fixed on the dev
    printer with `[axis_twist_compensation]` in its printer.cfg, plus
    five warm-up touches before every mesh; docs/dev_printer_testing.md).
    Left:
    - After the fix the owner still saw slightly more squish on the
      right over 150 mm: the right value (0.103) may need about +0.02.
    - The center value (-0.042) is the least certain: the raw center
      reading moved 0.04 mm between runs. Redo the three-spot comparison
      once more and adjust.
    - The comparison was made at Y 30 only. Check one more row (Y 150).
    - The work printer needs its own values: do the same comparison
      there, or ship without the section and tell users how.
    - A way to do the comparison from the touch screen (wizard).

## Agent (no owner needed)

Input shaper sensor (the system behind the accelerometer):
19. **Make the sensor setup part of the install:**
    - A stable name for the board's port: after a replug with Klipper
      running it becomes /dev/ttyACM1 (docs/input_shaping.md has the
      recovery).
    - rc.dp200 should set group dialout / mode 660 on /dev/ttyACM0
      (today by hand after every Klipper restart).
    - `setup_numpy.sh` does not work on the NAND root (no apt); the dev
      printer got numpy by hand from the card. Decide how the payload /
      root build ships it. The stock-kernel path (work printer) is
      untested with a sensor.

Kernel (dev printer only):
24. **Initramfs** (checked 11-16; needs a new kernel image, so do it
    with the next kernel build, before end-goal stage 6):
    - Its own log is still lost: it is copied to /newroot/run, which
      init.mainline's tmpfs covers (no such file on the dev printer).
      Write it where it survives, e.g. append to /var/log/dp200-init.log.
    - Close the mtd6 write window when the root isn't mtd6 (does not
      matter on the dev printer today: its root is mtd6).
    - Optional: refuse a root without init.mainline.

Wi-Fi:
26. **Wi-Fi watchdog never returns to the preferred network** (not a
    release blocker). The drops that started it (one access point at the
    dev printer's site disconnecting it every ~95 s on our kernel, not on
    stock) are put down to that home network (owner, 2026-11-20); the
    11-14 to 11-18 trace is in the changelog. Left: `dp200_wifi.watchdog`
    reads cached scan results, which after a few minutes hold only the
    current access point, so it never sees the preferred one; a fresh scan
    makes wpa_supplicant switch back (seen 11-14).
27. Upstream submission of the 8782 fix: **tabled by the owner 11-12**.
    The patch and cover letter are ready on the build box, not sent.

Motion and firmware:
28. **Root and payload builds now take Klipper from the fork**
    (`klipper/get_fork.sh`, 2026-11-13). Syntax-checked and the checkout
    tested on the PC; the first real root or payload build is the test.
    The two printers' `/home/klipper/klipper` are older checkouts: move
    them to the pinned fork commit with the next payload.
28b. **Root build with the new fork:** klippy's C helper changed with
    the move to upstream 29d4ec2d and the NAND root has no gcc. The stick
    payload carries the right `c_helper.so` (built on the card). Still to
    check: `install/rootfs_inside.sh` (a root built from scratch) builds
    it too.
28c. **`UPC_STEP_ARM`** (fork, default off): the ARM-mode step path
    passed homing, the drift test and a print on 11-15 (FM image 14068 B
    of 16384). Turn it on in `config/dp200_fm.config` only if the speed
    work (#12) shows the step firmware is the limit.
28d. **The stick payload (11-15) has the firmware of 8203a7d7**, without
    the three stepping commits merged later that day (ee0c7f8e). They go
    into the next payload.
End-goal install ([docs/end_goal_install_plan.md](docs/end_goal_install_plan.md);
stages 1-5 done on the dev printer):
34. **Stage 6:** installer v2 (USB stick under stock 3.2 writes mtd6, then
    mtd0).
35. **Stage 7:** the full Sindoh-stick revert cycle (YES-YES)
    and the broken-root prompt on hardware.
36. **Stage 8:** the work printer.
37. **Stage 9:** release checklist (PROJECTS #10).
39. **Repo split follow-ups** (11-20): the fork's
    `config/sindoh-dp200/README.md` still points at
    catawalks/sindoh `klipper_port/klipper/config/` (fix with the next
    fork commit; now catawalks/sindoh-klipper `klipper/config/`). Optional:
    move the kernel/NAND/U-Boot test scripts from `tools/` to
    sindoh-kernel ([tools/README.md](tools/README.md) lists them).
40. **v0.1.1: G-code storage on a card or stick, stick install** (owner
    11-20; PROJECTS 11). Built 11-20, tested on the PC with stand-in
    mount commands only: `install/printer/dp200-storage.sh` (opt-in by a
    `dp200_storage` folder; mounted over the G-code folder at boot;
    released by `dp200-start.sh stop`), and the installer and remover
    refuse to delete `/klipper` while anything is mounted inside it.
    **Not public until it has run on the work printer.** To check there
    (stock 3.2): the stock mount points (`/mnt/sd`, `/mnt/sda1`) and that
    BusyBox `mount` takes `uid=,gid=,umask=`; upload, print and delete
    from a FAT32 stick; boot without it (falls back to internal); the
    remover with the stick in (G-code on the stick must survive); the SD
    slot. Still to build: space management on the internal flash (refuse
    what doesn't fit, show free space), logs on the storage, a screen
    message when storage is in use. **Test payload `32ec81c0`** (build
    `75734d4`, fork and firmware as v0.1.0, content audit clean) is on
    the USB stick's `_update_rodin_KlipperInstall` with the new remover
    since 11-20; v0.1.0 (`0ee46f50`) is kept next to it in
    `_update_rodin_KlipperInstall_v0.1.0`. Not installed anywhere yet.
41. **1X port** (owner 11-20): plan and stages in
    [docs/1x_port_plan.md](docs/1x_port_plan.md), state in
    [docs/STATUS.md](docs/STATUS.md), what is done in the changelog.
    Stage 6 (a real config): homing, heaters, load/unload, bin, bed
    leveling, print start/end and a first print are done. Open (the
    checks that need the owner are in "Owner at a printer", 1X):
    - **X direction: fixed 11-23.** Our config had X backwards (0 at
      the right, home at 262.7: the stock program's printed range,
      which is the 2X's other carriage) and printed mirror images
      (the big L). Now the stock frame: X 0 at the bed's left edge,
      home sensor at -17.85, wall at -38.2; every X value converted
      (new = 224.5 - old). Homing, park, wipe, leveling and the L's
      outline (right way round) checked on the printer. A complete
      print in the new frame is still to come.
    - **Z zero and the bed's bow:** the first print's first layer was
      too close at the center (box 9.8 mm for 10). Z zero rests on one
      paper test. No mesh is possible on the stock bed (the nozzle
      only makes contact at the notches); a conductive sheet or a
      second probe would be an end-user change.
    - **Print settings** (`gen_test_prints.py --model x1`): retract
      6 mm, 40 mm/s, travel 130 mm/s, `max_accel` 2500 are Sindoh's
      "Normal" values, not printed with yet. Then tune toward 60 mm/s
      (Sindoh's "Fast"), further with input shaping (owner 11-22).
      The first layer stays 0.25 x 0.45.
    - `PRIME_LINE` (11-23): never drawn. Check where the front edge
      of the sheet really is and set `prime_y` (now 1.0).
    - Bed `max_temp` 100 is a guess (Sindoh's ABS profile uses 90).
    - The jam check's window values are estimates.
    - The DP200 has no runout switch: the owner prints Sindoh's
      adapter; then test it and add it to the DP200 config.
    - **Installer for the 1X:** write `x1_machine.cfg` from the
      database as for the DP200 (X from MOTOR_PWM_X2OFFSET, Y, Z, E,
      and C from MOTOR_PWM_COFFSET; outputs `motor_current_x/y/z/e/c`).
    - **Stage 7: install, boot, uninstall, update:** plan in
      [docs/1x_install_plan.md](docs/1x_install_plan.md) (11-24 night:
      Sindoh's boot and integrity checks read; a "warm takeover" hook
      first, the cold start later). `install/x1/x1_machine_cfg.sh`
      writes the motor currents from the database (tried read-only on
      the printer: X 0, Y +40, Z +40, E +50, C +9). Owner 11-24: use
      the stock counts and the warm takeover is not the favorite;
      next to look at: the cold start with our own `/run.sh` put in
      place by the hook (no Sindoh file changed), after a by-hand
      cold-start test with the owner present.
    - **DP200 motor currents** (found 11-24 on the 1X): the DP200
      installer writes `(100 + offset) / 200`, which Klipper cuts to
      one count below stock for some offsets (e.g. -15 gives 84, stock
      85). Use the 1X rule `(ceil(high * 255 / 200) + 0.25) / 255` in
      `unmistakable_klipper_install.sh` and `dp200_printer.cfg` with the
      next payload (TODO 49), and read back with `devmem` on a DP200.
    - **DP201** (owner 11-24): not a DP200 twin. Same RODIN_ firmware,
      but PLA only with **no heated bed**; the part-cooling fan moved to
      the side of the head (same pins, no config change). The DP102 is
      identical to the DP200. The installer now refuses a model ID with
      "201" in it (the real ID is unknown). To support it: its model
      ID and a survey report from an owner, then a config without
      `heater_bed` and a PRINT_START without bed heating.
    - **2X:** second carriage and nozzle (a 2X is on its way).
    - Paper work: the stepper engine clock against the timer (step
      batching is off on the 1X), the microstep pins of the drivers.
    - The DP200 firmware built from the 1X-capable fork has not run on
      a DP200.
43. **Rename the fork branch `sindoh-dp200`** (owner 11-22: the port runs
    on several models now) to `sindoh-upc`, **after the work printer's
    v0.1.1 stick test of Monday 11-23** (the stick's scripts fetch by
    the old name). Touches `klipper/FORK`, `tools/fork_*.sh`,
    `klippy_*.sh`, `payload_prep.sh`, the READMEs and the release
    checklist; keep the old branch name on GitHub until no released
    installer needs it. Done 11-22: the version tag `sindoh-upc-1` (the
    cores report `sindoh-upc-...` from the next firmware build on) and
    the build menu text.
45. **3DWOX 1 in our tree** (owner 11-22): `klipper/config/3dwox1/`
    holds his values in our layout (`3dwox1_printer.cfg` + `printer.cfg`). Open: go through the
    changes in his copy of `dp200_printer.cfg` one by one (max_accel
    3000, second Z homing approach at 0.5 mm/s with a 2 mm back-off,
    the step pulse note) and take what is right for the DP200 too; his
    print start without the bed-empty question stays out. Tell him the
    file is here and that our macros have moved on since his copy
    (step lines, JOG, screen timeout). His repository has no license
    file; the config derives from ours, but ask him to add one. The
    installer does not know the 3DWOX 1 yet. Both wait for a 3DWOX 1
    or for someone who has one (owner 11-22). Owner's reading of his
    slower speeds: the Z stall was probably the motor current (the
    DP200's values, far too low for his unit, before the installer read
    them per machine), and the "violent" homing is Klipper stopping dead
    from stock's homing speed where stock ramps down after the sensor.
    So the model file's speeds may not be needed with the right current.
46. **Idea: ramp down after a home sensor trips** (owner 11-22), as
    stock does (1X: it runs about 4.9 mm past the sensor's edge),
    instead of Klipper's dead stop. Would be a change to the stop path
    in `src/stepper.c` (and our hardware-burst path) plus a per-stepper
    option; the host already copes with a stop position that differs
    from the trigger position. Only for axes with room behind the
    sensor (never Z). Shelved (owner 11-22): too far from stock Klipper to carry alone; revisit once our board support has been accepted upstream.
47. **Time zone** (owner 11-22). The 1X takes the zone set on the stock
    screen at every start. Open: the DP200 and 3DWOX 1 (does their
    stock keep the same setting? the installer could carry it over),
    and what happens once stock is gone for good (stage 7 install):
    then we need our own setting. Proposal: SYSTEM page, pick a region
    then a city from the system's zone list (it has the daylight saving
    rules), default = what stock had.
49. **Next stick payload (v0.1.2)** (owner 11-23: the installed
    v0.1.1 test payload is from 11-20 and lacks the screen and macro
    work since). It should carry: JOG, the MOVE page order with BED
    FORWARD, the lamp going off with the screen (`SCREEN_TIMEOUT` /
    `SCREEN_WAKE`, restart fix), step messages during load and
    unload, homing at 100 mm/s with a 2 mm Z back-off, the automatic
    `LV_PROBE_CALIBRATE_SAVE`, and the remote reboot (item 48). Before
    it can be built:
    - The DP200 firmware from the current fork (f97fa268) has never
      run on a DP200: test it on the dev printer first, or build the
      payload with the firmware of v0.1.0 and only new host files.
    - `BED_FORWARD`, the new `LV_PROBE_CALIBRATE_SAVE`, the Z
      homing that first moves off a pressed switch, and the
      `PRINT_START` with its step list (11-23: the nozzle now heats
      over the bin before the purge), on a DP200 (owner
      present). The work printer's own edit (Z `position_min` -5) is
      the new shipped value.
    - `docs/INSTALL.md` still tells users to type
      `LV_PROBE_CALIBRATE_SAVE Z=<value>` (right for v0.1.0 and
      v0.1.1): change it with the release that carries the new macro.
    - The dev printer answers on WiFi, 10.10.0.21 (Ethernet .147 is
      down); Moonraker only, no shell, while the serial cable is on
      the 1X. Config and macro files can go there through Moonraker;
      the screen app and firmware cannot.
48. **Reboot and power off from Mainsail, every model** (owner 11-23:
    people will want to restart their printer remotely). Moonraker runs
    `sudo reboot` / `sudo poweroff` inside the Klipper root, which
    cannot restart the machine. Built 11-23, tried on the PC only:
    `dp200-power-request` (in `install/rootfs/usr/local/sbin/`,
    installed as `reboot`, `poweroff` and `halt` ahead of the system's
    own) writes the same request the touch screen's POWER page writes;
    a sudo rule lets Moonraker's user run it; a root without sudo (the
    1X card) gets a stand-in. Open:
    - 1X: reboot through Moonraker's API worked 11-23. Still to try
      (owner present): Shutdown from Mainsail and SHUT DOWN / REBOOT
      on the screen's POWER page (same helper; power off uses GPIO
      158 and has never run).
    - DP200: the root builds install it (`build_rootfs.sh`,
      `rootfs_inside.sh`), not run since. **The stick payload and its
      installer do not carry it yet** (left alone on 11-23, the day of
      the v0.1.1 work-printer test): add the three files to the
      payload and the upgrade step.
    - On our own kernel Moonraker refuses with "inside a container"
      (confirmed on the dev printer 11-23: it reports "lxc", because
      process 1 is called `init.mainline`). `init.mainline` now
      renames itself to `init`; not on the printer yet (needs a
      shell there: the serial cable is on the 1X).
    - The planned 1X install that boots our system directly (stage 7)
      keeps this path: only the helper behind the request file changes.
42. **1X speaker** (owner 11-21: use it for tones or tunes, not only the
    beeper): USB audio card 0 + amplifier enable GPIO 180, stock plays
    MP3s with mplayer ([sindoh: 1x_stock_routines.md](https://github.com/catawalks/sindoh/blob/main/docs/1x_stock_routines.md),
    "The speaker"). To do: play a sound from the Debian root under
    Klipper, then a `M300`-style macro or shell command for it.
38. **One installer for every model** (owner 11-20: no per-model
    releases; the installer reads the machine it is on and sets it up).
    Each firmware line (RODIN_, RODUP_, the 6270 models) is treated as its
    own target, possibly with its own mainboard ([docs/other_models.md](https://github.com/catawalks/sindoh/blob/main/docs/other_models.md)).
    Model facts so far are from Fredrik Gustafsson's 3DWOX 1
    ([docs/3dwox1.md](https://github.com/catawalks/sindoh/blob/main/docs/3dwox1.md), "Later findings"), not our printers.
    - Done 11-20, untested on a printer: the installer writes
      `dp200_machine.cfg` with the motor currents from the printer's own
      karas.db (CONF_ENGINE_PWM NO=4). First run: the next work-printer
      upgrade (check the file and the BusyBox awk output; expect
      0.425/0.6/0.65/0.75 only if its offsets equal the dev printer's).
    - Model from the firmware tag: accept `RODUP_` (3DWOX 1) as well as
      `RODIN_` in the installer's firmware check, `dp200-start.sh` and the
      screen header; 3DWOX 1 sticks need `_update_rodin_up` and AES
      packing (sindoh docs/other_models.md), and it has 34.5 MB free on its root.
    - Partitions (checked 11-20 from the update files): the 3DWOX 1's
      Sindoh update script is byte for byte the DP200's, with the same
      kernel load (0x40000, 0x7C0000); its kernel is a 2018 rebuild of the
      same 3.2.0-g67a8e16 source (same size, no driver or board string
      differs). Its `/proc/mtd` (Fredrik) has the DP200's mtd0-6; mtd7/8
      are most likely gluebi copies of the two attached UBI volumes, which
      both kernels build in. The stick install writes files on the mounted
      root, so it needs no raw partition knowledge. **Confirmed on a real
      unit** by Sebastian Schmidt's 2021 3DWOX 1 dumps (`3dwox1_2021/` in
      catawalks/sindoh; sindoh docs/3dwox1.md): the DP200's mtdparts exactly, and
      mtdblock7/8 = the gluebi copies of the UBI volumes. **Asked of
      Fredrik (11-20, owner sends):** `df /`, the size of the Sindoh app
      and WebKit (will Klipper fit?), `ubinfo -a`, the U-Boot block md5,
      his karas.db motor row, what holds `/dev/ttyS2`, the bank 2
      registers, a mainboard photo, and his OK for GPLv3 on his notes.
    - Driver board: detect A4982 vs TMC2224 (GPIO bank 2 pin 0, as stock)
      and, for a TMC2224, set it up the way stock does over its UART. First
      settle what `/dev/ttyS2` is (power-management MCU in our
      hardware_notes vs the TMC2224 UART in his audit).
    - More stock values worth reading per printer (stock_routines.md has
      the tables): the Z/E current variants (`MOTOR_PWM_ZOFFSET_DOWN`,
      `EOFFSET_UNLOAD`), PID gains, leveling positions.
    - `MESH_ADAPTIVE` (opt-in macro, 11-20) and `PRINT_START MESH=0`: not
      yet run on a printer.
    - 1X (owner's, surveyed 11-20, [docs/1x.md](https://github.com/catawalks/sindoh/blob/main/docs/1x.md)): the first
      6270 data. Next for a port: the UPC memory map on the 6270, what the
      stock engine talks to on `ttyS2`, how Marvell's stepper/dcmotor
      drivers relate to the UPC, and heater/thermistor wiring. A serial
      console on its `ttyS0` would help.

44. **Screen app** ([docs/touchscreen.md](docs/touchscreen.md)).
    - **Buttons act through config macros** (owner 11-22: no per-model
      code per button; a missing macro shows "not set up yet"). Still
      coded in the app: the filament presets and temperatures, the 1X
      filament page's sensor names, the cool-down command list, and
      which pages are off on the 1X. Move them when those pages are
      next touched.
    - **Lamp wake waits behind the G-code queue** (owner 11-22):
      `SCREEN_WAKE` did not switch the lamp on until a heat-up had
      finished. Idea: a small module in the fork that switches an
      output at once on a web request; the config still says what the
      timeout covers. To decide with the owner.
    - **1X power button** (owner 11-23). The power circuit sends one
      pulse (GPIO 116 low about 3 s) after a hold of about 3 s, and
      nothing more however long the button is held; a tap never
      reaches Linux. The first design (keep holding 3 s more to shut
      down) could not work: owner's test 11-23, the countdown stuck
      at 1. The second design (hold again on the POWER page) was
      rejected by the owner 11-24. Now (11-24, on the printer): one
      hold = "Powering off in 3 s" with CANCEL, then power off; a
      running print or move gets the emergency stop at once (the
      owner uses the button as the e-stop on stock). **Owner present:**
      a hold with CANCEL, a hold to the end (first real power off,
      GPIO 158), and a hold during a print. The screen log says "power
      button held: power off in 3 s" with the time.
    - **The R4 core** (PC_DEBUG2): studied from the PC 11-24 (sindoh
      `docs/1x_r4.md`). It does not reach the power board; the only
      link is GPIO 116 in and 158 out. A real press signal would need
      a hardware change (owner's call; nothing planned).
    - **1X updater:** Mainsail lists the card's Klipper checkout as
      invalid (detached, untracked files). Do not use its "recover"
      there; the stage 7 install will have no checkout.
    - WiFi set-up from our screen on the 1X waits for stage 7.
    - The lamp fix of 11-22 (run `SCREEN_TIMEOUT` again after a
      Klipper restart) is tested on the 1X only.
