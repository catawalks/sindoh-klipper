# 1X: Sindoh's slicer profiles against our test prints

Read 2026-11-22 from the owner's copies of Sindoh's downloads (not in
any repository): the Cura settings archive (`Cura_Settings.zip`: machine
definitions for the 3DWOX 1, 1X, 2X and 7X, quality and material files)
and the Simplify3D profile `Sindoh_3DWOX1_PLA.fff` (3DWOX 1 only). "Ours"
is `tools/gen_test_prints.py --model x1`, the settings of the first
print (the 20 mm box of 11-22).

## PLA print settings

| Setting | Sindoh, Cura 1X "Normal" | Sindoh, Simplify3D (3DWOX 1) | Ours |
|---|---|---|---|
| Layer height | 0.2 (Fast 0.3, Fine 0.1) | 0.2 | 0.2 |
| First layer height | 0.2 | 0.22 (110%) | 0.25 |
| Line width | 0.4 (Cura's default for the nozzle) | 0.4 | 0.45 |
| Flow | 100% (ABS 110%) | 90% | 100% |
| Nozzle | 200 C | 195 C | 210 C |
| Bed | not set: Cura's default, 60 C | 60 C | 60 C |
| Print speed | 40 mm/s | 40 mm/s, outlines 20 | 30 mm/s |
| First layer speed | Cura's rule: 20 mm/s | 20 mm/s (50%) | 20 mm/s |
| Travel speed | 130 mm/s | 80 mm/s | 100 mm/s |
| Retract | 6 mm at 30 mm/s (material file; the machine file says 3) | 6 mm at 40 mm/s, coast 0.2, wipe 3 | 5 mm at 35 mm/s |
| Part fan | 50%, full value from the third layer (0.6 mm) | 100% from layer 2 | 100% from the third layer |
| Walls | 0.8 mm (2 lines) | 2 | 2 |
| Top / bottom | 0.8 mm (4 layers) | 3 layers | 3 bottom layers |
| Infill | 15%, lines | 20% | none (open box) |
| Bed adhesion | **raft** by default; skirt 2 lines, 3 mm gap | skirt 2 lines, 4 mm gap | skirt 2 lines, 3 mm gap |

Taken over on 11-22 (owner): retract 6 mm, 40 mm/s printing, 130 mm/s
travel and acceleration 2000, as starting points to tune higher later.
The "Ours" columns show the values of the first print, before that.

Close: layer height, speeds, walls, skirt, bed temperature. Different:

- **Nozzle 210 C** is the stock firmware's own PLA value (210 first
  layer, 200 after); the slicer profiles say 200 and 195.
- **Retract:** Sindoh uses 6 mm in both slicers. Ours (5 mm) was a
  guess; 6 is the better starting value.
- **Fan:** Cura runs PLA at 50%, not 100.
- **First layer:** ours is thicker and wider (0.25 x 0.45 against
  0.2 x 0.4), which wants more room under the nozzle, not less.
- **Raft:** Sindoh's Cura default prints on a raft, which hides an
  uneven bed and a rough Z zero. Their Simplify3D profile prints on the
  bed with a Z offset of -0.15 mm (M206) for the 3DWOX 1.
- ABS (Cura): 230 C, bed 90 C, fan 3%, flow 110%.

## Machine limits in the Cura definition

| | Cura 1X definition | Found in the stock program (11-22) | Our config |
|---|---|---|---|
| Bed size | 228 x 200 x 300 mm | | X -8 to 262.7 (travel), Y 200.5, Z 310 |
| Max speed X, Y | 200 mm/s | ramp tables to 197.7 | 197 |
| Max speed Z | 10 mm/s | 12.0 | 12 |
| Max speed E | 50 mm/s | 86.7 | 86 (extrude-only) |
| Acceleration X, Y | 2000 mm/s2 (default 2500) | about 1460 average | 1500 |
| Acceleration Z | 100 | about 110 | 100 |
| Jerk X/Y, Z, E | 50, 0.1, 5 | 20, 0.1, 5 | Klipper's corner speed default |

The bed limit of 90 C for ABS fits our `max_temp: 100` for the bed. The
same definition serves the 2X apart from its two extruders and its own
start G-code.

## Start and end G-code (Cura, 1X)

    M107            ; fan off
    G200            ; nozzle cleaning
    G21, G90
    G92 E-20        ; then, after homing: G1 F800 E0 = feed 20 mm
    G28
    G1 F800 E0
    G0 Z1.0
    ...
    M2              ; end: the firmware does the rest

Heating is left to the firmware (Cura adds the temperatures itself).
Our `PRINT_START` does the same things in macros: clean, home, purge
20 mm less (we purge at the bin), wipe. A slicer set up for our port
calls `PRINT_START BED= EXTRUDER=` and `PRINT_END` instead; `G200` and
`M2` are not defined in our config.

## The X direction: what Sindoh does

Looked up 2026-11-22 in the stock motion program (the G0/G1 handler
`parsedData::parseGcode_G0_G1` and `..._calcPulse`, disassembled on the
PC) and in a print file sliced by Sindoh's own slicer (the 1X's
`/example/PLA/LINE TEST_PLA.gcode`, 3DWOX Desktop 1.5).

- **The stock program does not turn X around.** It takes the X of a
  print file as it stands, checks it, and converts the difference to
  the last position into steps at 0.0125 mm per step. There is no
  offset and no sign change on the way.
- **A print file's X is the motor frame we measured.** The handler
  accepts X from 0 to 228, plus exactly two values outside the bed:
  262.7 and -38.2. 262.7 is the home position at the left wall, where
  the 1X's head parks; -38.2 is the matching park position past the
  other end, for the 2X's other head. Y is accepted from 0 to 200.
- **Sindoh's slicer puts the bed center at X 114, Y 100**: its line
  test (a 20 mm part on a raft) spans X 101.9 to 126.1 and Y 87.9 to
  112.1. Our test prints are centered at X 110, the middle between the
  two front notches (-7.5 and 228.5), 4 mm to the right of that.
- **Neither of Sindoh's third-party profiles mirrors.** The Cura
  definition has no such setting. The Simplify3D profile's
  `flipXoverride` is 1, which is Simplify3D's "not flipped" (an earlier
  note here read it as a flip; that was wrong).
- Their start G-code in that file: T0, M140/M104 without waiting,
  M107, G200, G21, G90, G92 E-20, M190, M109, G28, `M298` ("move
  nozzles on bed plate"), G0 Z3. The header gives a Z offset without a
  raft of -0.15 mm.

So in the stock machine a print file's X 0 is at the right edge of the
bed and X grows to the left, exactly as in our config, and nothing in
Sindoh's chain that we can read turns it around. What that leaves:

1. Sindoh's own slicer mirrors the model before writing the file (not
   visible in a round sample part), and files from Cura with Sindoh's
   own profile come out mirrored on a stock 1X; or
2. our picture of the directions is wrong somewhere, and nothing is
   mirrored.

Only a print can tell: an asymmetric part under our config behaves as
the same file would under stock. `x1_xy_scale_150mm.gcode` is an L
whose corner is at low X and low Y: corner at the front right = the
frame mirrors, front left = it does not. Decide about turning X around
after that print (TODO 41).

A Cura post-processing script in the archive
(`DisplayInformationIn3DWOX.py`) writes the comment lines the stock
screen shows: `;ESTIMATION_TIME`, `;TOTAL_LAYER`, `;DIMENSION`,
`;ESTIMATION_FILAMENT_CARTRIDGE_0`.

## Sindoh's own slicer (3DWOX Desktop 1.6): profiles and a sliced cube

Read 2026-11-22 from the owner's installation (`profile\` folder: 23
models, per model a machine file, the start/end code and the print
profiles) and from an XYZ calibration cube the owner sliced for the 1X
with "Fast". Not copied into any repository.

1X print profiles (PLA; all with a raft, 15 % infill, fan 50 % from
0.6 mm, retract 6 mm at 30 mm/s, nozzle 200 C, bed 60 C, Z offset
without a raft -0.15 mm):

| Profile | Layer | Print | First layer | Top/bottom | Travel |
|---|---|---|---|---|---|
| Fast | 0.2 | 60 mm/s | 20 | 20 | 130 |
| Normal | 0.2 | 40 | 20 | 20 | 130 |
| Fine | 0.1 | 25 | 20 | 10 | 60 |
| Silent | 0.2 | 40 | 20 | 20 | 60 |

ABS: 230 C, bed 90 C, fan 8 %, retract 3 mm. Flexible: 240 C, 30 mm/s,
retract 7 mm at 70 mm/s, travel 100.

Machine file, 1X: bed 228 x 200 x 300, acceleration 2500 mm/s2, corner
speed ("bump") 25 mm/s for X and Y, 0.4 for Z, 5 for E; nozzles 0.4
(0.2 and 0.6 selectable). The slicer's speed limits there (600 mm/s
X/Y, 40 Z) are far above the firmware's and mean nothing for the
machine. The same values serve nearly every model; the 5X and 7X have
1600 mm/s2 and bump 20, the "1X DP302" 800 and 8. Bed sizes: DP200,
3DWOX 1, DP102/103: 210 x 200 x 195; 2X as the 1X; 5X 350 x 350 x 350;
7X 370 x 390 x 450. Every model has the same start code (M107, G200,
G21, G90, G92 E-20) and end code (M2).

**The cube is not mirrored in the file.** Its top face carries an
engraved Z; drawn from the G-code with X to the right and Y up, it
reads as a normal Z. So Sindoh's slicer does not mirror either. With
the firmware passing X through (above), a stock 1X prints a file
exactly as our config does. Whatever a stock print looks like, ours
looks the same: if stock parts are not mirror images, no change to our
X is needed, and the earlier "mirrored" reasoning has a direction
wrong somewhere (most likely which end of Y is the front). The L print
settles it.
