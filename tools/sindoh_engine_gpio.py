#!/usr/bin/env python3
"""List the GPIO lines a Sindoh motion program opens.

    python3 sindoh_engine_gpio.py ENGINE.elf ENGINE.dis [FUNCTION ...]

ENGINE.dis is `arm-none-eabi-objdump -d` of ENGINE.elf (Sindoh's
marvell_lspsdk_3dp_granite2-debug_stripped.elf; local only, never
published). For every call of gpio_open(handle, bank, pin, direction)
in the named functions (default: engine_initGPIO) it prints the GPIO
number (bank * 32 + pin), the direction argument and the name of the
object the handle is stored in, in call order, with the address of the
call so that calls inside a board-revision branch can be told apart.
"""
import re
import struct
import sys


def load_elf(path):
    d = open(path, 'rb').read()
    phoff, = struct.unpack_from('<I', d, 28)
    phentsize, phnum = struct.unpack_from('<HH', d, 42)
    segs = []
    for i in range(phnum):
        t, off, va, _, fsz, _, _, _ = struct.unpack_from('<8I', d, phoff + i * phentsize)
        if t == 1:
            segs.append((va, off, fsz))

    def word(addr):
        for va, off, fsz in segs:
            if va <= addr < va + fsz:
                return struct.unpack_from('<I', d, off + addr - va)[0]
        return None
    shoff, = struct.unpack_from('<I', d, 32)
    shentsize, shnum = struct.unpack_from('<HH', d, 46)
    syms = {}
    for i in range(shnum):
        sh = struct.unpack_from('<10I', d, shoff + i * shentsize)
        if sh[1] in (2, 11):                      # SYMTAB, DYNSYM
            stroff = struct.unpack_from('<10I', d, shoff + sh[6] * shentsize)[4]
            for o in range(sh[4], sh[4] + sh[5], 16):
                name, val, size, info = struct.unpack_from('<IIIB', d, o)
                if info & 15 == 1 and val:        # OBJECT
                    e = d.index(b'\0', stroff + name)
                    syms[val] = (d[stroff + name:e].decode(), size)
    return word, syms


def name_of(syms, addr):
    for a, (n, size) in syms.items():
        if a <= addr < a + max(size, 4):
            return n if size <= 4 else '%s[%d]' % (n, (addr - a) // 4)
    return '0x%x' % addr


def decode(word, syms, lines, func):
    reg, out, on = {}, [], False
    for ln in lines:
        if ln.startswith('00') and '<' in ln:
            on = ('<%s@@Base>:' % func) in ln or ('<%s>:' % func) in ln
            reg = {}
            continue
        m = re.match(r'\s*([0-9a-f]+):\s+[0-9a-f]{8}\s+(\S+)\s*(.*)', ln)
        if not on or not m:
            continue
        pc, op, args = int(m.group(1), 16), m.group(2), m.group(3).split('@')[0].strip()
        a = [x.strip() for x in args.split(',')]
        try:
            if op in ('mov', 'movw') and a[1].startswith('#'):
                reg[a[0]] = int(a[1][1:], 0)
            elif op == 'ldr' and a[1].startswith('[pc'):
                off = int(a[2].rstrip(']')[1:], 0) if len(a) > 2 else 0
                reg[a[0]] = word(pc + 8 + off)
            elif op == 'ldr' and len(a) == 3 and a[1].startswith('[r') and not a[2].startswith('#'):
                base, idx = reg.get(a[1][1:]), reg.get(a[2].rstrip(']'))
                reg[a[0]] = word((base + idx) & 0xffffffff) if None not in (base, idx) else None
            elif op == 'add' and len(a) == 3 and a[1] == 'pc':
                reg[a[0]] = (pc + 8 + reg[a[2]]) & 0xffffffff
            elif op == 'add' and len(a) == 3 and a[2].startswith('#'):
                reg[a[0]] = reg[a[1]] + int(a[2][1:], 0)
            elif op == 'bl' and 'gpio_open' in args:
                h, bank, pin, d = (reg.get(r) for r in ('r0', 'r1', 'r2', 'r3'))
                out.append((pc, bank * 32 + pin if None not in (bank, pin) else None, d,
                            name_of(syms, h) if h is not None else '?'))
            elif op.startswith('bl'):
                for r in ('r0', 'r1', 'r2', 'r3'):
                    reg.pop(r, None)
        except (KeyError, TypeError, ValueError):
            reg.pop(a[0], None)
    return out


def main():
    word, syms = load_elf(sys.argv[1])
    lines = open(sys.argv[2], encoding='utf-8', errors='replace').read().split('\n')
    for func in sys.argv[3:] or ['engine_initGPIO']:
        print('== %s' % func)
        for pc, gpio, d, name in decode(word, syms, lines, func):
            print('%6x  gpio %-4s dir %-3s %s' % (pc, gpio, d, name))


if __name__ == '__main__':
    main()
