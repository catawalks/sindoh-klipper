"""Run a stock 1X UPC microcode image (io or fm) under Unicorn and log the
hardware registers its start-up code writes and reads. PC only; for the 1X
port's stage 0 (docs/1x_port_plan.md).

usage: x1_ucode_probe.py image.bin [instructions] [--sum=0xOFFSET] [-v]

The UPC core sees ITCM at 0, the shared DTCM at 0x04000000, its local
register block at 0x08000000 and the SoC peripherals at their physical
addresses (as on the DP200, tools/pwmprobe.py). Unknown regions are mapped
on demand and reported.
"""
import sys, struct, collections
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_ARM, UcError, UC_HOOK_MEM_UNMAPPED
from unicorn.arm_const import UC_ARM_REG_PC

code = open(sys.argv[1], 'rb').read()
count = int(next((x for x in sys.argv[2:] if x.isdigit()), 2000000))
uc = Uc(UC_ARCH_ARM, UC_MODE_ARM)
uc.mem_map(0, 0x10000)
uc.mem_write(0, code)
uc.mem_map(0x04000000, 0x40000)
# The host preloads parameter tables into the DTCM and stores their byte sum
# and its complement right after them; the microcode halts on a mismatch
# ("TABLE Corrupted"). An all-zero table sums to 0. 1X io and fm: 0xa728.
SUM = int(next((x[6:] for x in sys.argv if x.startswith('--sum=')), '0xa728'), 16)
uc.mem_write(0x04000000 + SUM, struct.pack('<II', 0, 0xffffffff))
mem = {}
writes = []                       # (pc, addr, value) in order
reads = collections.Counter()
REGIONS = [(0x08000000, 0x10000, 'UPC local'), (0xf9300000, 0x10000, 'DEC (pwm/adc/sensor)'),
           (0xf8000000, 0x200000, 'IPS (stepper, dcmotor ...)'), (0xd4000000, 0x100000, 'APB (gpio, uart, i2c)'),
           (0xd0600000, 0x100000, 'AP config')]


def rd(base):
    def f(u, off, size, ud):
        a = base + off
        reads[a] += 1
        if a == 0xd4030014:
            return 0x60               # console UART (ttyS0) line status: TX empty
        if 0xf930a180 <= a < 0xf930a1a8:
            return 0x400              # ADC results: mid scale
        return mem.get(a, 0)
    return f


def wr(base):
    def f(u, off, size, val, ud):
        a = base + off
        if a == 0xd4030000:
            uart.append(val & 0xff)   # the microcode prints on the console UART
            return
        mem[a] = val
        writes.append((u.reg_read(UC_ARM_REG_PC), a, val))
    return f


for b, s, _ in REGIONS:
    uc.mmio_map(b, s, rd(b), None, wr(b), None)
unmapped = []
uart = []


def on_unmapped(u, access, addr, size, value, ud):
    unmapped.append((u.reg_read(UC_ARM_REG_PC), addr))
    base = addr & ~0xfff
    try:
        u.mmio_map(base, 0x1000, rd(base), None, wr(base), None)
    except UcError:
        return False
    return True


uc.hook_add(UC_HOOK_MEM_UNMAPPED, on_unmapped)
try:
    uc.emu_start(0, 0xffffffff, count=count)
except UcError as e:
    print('stopped:', e)
print('pc at end: %#x, %d register writes' % (uc.reg_read(UC_ARM_REG_PC), len(writes)))
for pc, a in unmapped[:20]:
    print('UNMAPPED region touched: pc=%05x addr=%#010x' % (pc, a))
last = None
for pc, a, v in writes:
    if 0x08000000 <= a < 0x08010000 and '-v' not in sys.argv:
        continue                   # UPC-local block: only with -v
    print('W pc=%05x %#010x <- %#x' % (pc, a, v))
print('console text:', bytes(uart).decode('ascii', 'replace')[:2000])
print('reads (address: count):')
for a, n in sorted(reads.items()):
    if not 0x08000000 <= a < 0x08010000:
        print('  %#010x: %d' % (a, n))
