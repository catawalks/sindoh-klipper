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

## The X direction

Cura's definition has X 0 to 228 with no mirror setting, while the
motor frame we measured grows to the LEFT (home at 262.7 on the left).
So the stock firmware must turn slicer X around before moving, or every
stock print would be mirrored. Sindoh's Simplify3D profile for the
3DWOX 1 has `flipX` set, which points the same way. Our config uses the
motor frame as is, so **G-code sliced for a normal bed prints mirrored
left to right on our port** until X is turned around in the config
(stepper direction and positions) or in the slicer. Not changed yet:
owner's decision (TODO 41).

A Cura post-processing script in the archive
(`DisplayInformationIn3DWOX.py`) writes the comment lines the stock
screen shows: `;ESTIMATION_TIME`, `;TOTAL_LAYER`, `;DIMENSION`,
`;ESTIMATION_FILAMENT_CARTRIDGE_0`.
