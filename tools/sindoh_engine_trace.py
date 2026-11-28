#!/usr/bin/env python3
"""Outline routines of a Sindoh motion program: every call with its arguments.

    python3 sindoh_engine_trace.py ENGINE.elf ENGINE.dis FUNCTION ... [--all-calls]

ENGINE.dis is `arm-none-eabi-objdump -d` of ENGINE.elf (Sindoh's
marvell_lspsdk_3dp_granite2-debug_stripped.elf; local only, never
published). For each named function it prints, in address order, the
strings it refers to, the constants it compares against and each call
with what is known of r0-r3 at that point: a number, the name of the
global variable the value was loaded from ("name" or "name+8"), or "?".
Arguments are followed through the frame (str/ldr at [fp, #-n]) within
straight-line code only; a branch target resets nothing, so read a
value after a branch with care. Without --all-calls only Stepper*,
engine_*, ENGINE_*, upc_*, usleep and sleep calls are shown.
"""
import re
import struct
import sys


def load(path):
    d = open(path, 'rb').read()
    phoff, = struct.unpack_from('<I', d, 28)
    pes, pn = struct.unpack_from('<HH', d, 42)
    segs = [struct.unpack_from('<8I', d, phoff + i * pes) for i in range(pn)]
    segs = [(s[2], s[1], s[4]) for s in segs if s[0] == 1]

    def data(addr, n=4):
        for va, off, fsz in segs:
            if va <= addr < va + fsz:
                return d[off + addr - va: off + addr - va + n]
        return b''
    shoff, = struct.unpack_from('<I', d, 32)
    shs, shn = struct.unpack_from('<HH', d, 46)
    syms = []
    for i in range(shn):
        sh = struct.unpack_from('<10I', d, shoff + i * shs)
        if sh[1] in (2, 11):
            stroff = struct.unpack_from('<10I', d, shoff + sh[6] * shs)[4]
            for o in range(sh[4], sh[4] + sh[5], 16):
                name, val, size, info = struct.unpack_from('<IIIB', d, o)
                if info & 15 == 1 and val:
                    e = d.index(b'\0', stroff + name)
                    syms.append((val, max(size, 4), d[stroff + name:e].decode()))
    syms.sort()
    return data, syms


def symname(syms, addr):
    lo, hi = 0, len(syms)
    while lo < hi:
        mid = (lo + hi) // 2
        if syms[mid][0] <= addr:
            lo = mid + 1
        else:
            hi = mid
    if lo:
        a, size, n = syms[lo - 1]
        if a <= addr < a + size:
            return n if addr == a else '%s+%d' % (n, addr - a)
    return None


class Sym(str):
    """The address of a global: its name."""


class Val(str):
    """A value loaded from a global: shown as the global's name."""


def show(v):
    if v is None:
        return '?'
    if isinstance(v, int):
        return str(v - (1 << 32) if v >= 1 << 31 else v)
    return str(v)


def trace(data, syms, lines, func, all_calls):
    on, reg, frame = False, {}, {}
    for ln in lines:
        if ln.startswith('00') and '<' in ln:
            on = ln.split('<')[1].split('>')[0].split('@')[0] == func
            reg, frame = {}, {}
            continue
        m = re.match(r'\s*([0-9a-f]+):\s+[0-9a-f]{8}\s+(\S+)\s*(.*)', ln)
        if not on or not m:
            continue
        pc, op, rest = int(m.group(1), 16), m.group(2), m.group(3).split('@')[0].strip()
        a = [x.strip() for x in rest.split(',')]
        try:
            if op in ('mov', 'movw') and a[1].startswith('#'):
                reg[a[0]] = int(a[1][1:], 0)
            elif op == 'mvn' and a[1].startswith('#'):
                reg[a[0]] = ~int(a[1][1:], 0) & 0xffffffff
            elif op == 'movt':
                reg[a[0]] = (reg.get(a[0], 0) & 0xffff) | int(a[1][1:], 0) << 16 if isinstance(reg.get(a[0], 0), int) else None
            elif op == 'mov' and a[1] in reg:
                reg[a[0]] = reg[a[1]]
            elif op == 'ldr' and a[1].startswith('[pc'):
                off = int(a[2].rstrip(']')[1:], 0) if len(a) > 2 else 0
                reg[a[0]] = struct.unpack('<I', data(pc + 8 + off))[0]
            elif op == 'add' and len(a) == 3 and a[1] == 'pc' and isinstance(reg.get(a[2]), int):
                v = (pc + 8 + reg[a[2]]) & 0xffffffff
                s = data(v, 100).split(b'\0')[0]
                n = symname(syms, v)
                if n:
                    reg[a[0]] = Sym(n)
                elif len(s) > 2 and all(9 <= c < 127 for c in s):
                    reg[a[0]] = None
                    print('  %x  "%s"' % (pc, s.decode().replace('\n', '\\n').replace('\t', '\\t')))
                else:
                    reg[a[0]] = v
            elif op == 'ldr' and len(a) == 3 and a[1].startswith('[r') and a[2].rstrip(']') in reg and isinstance(reg.get(a[1][1:]), int) and isinstance(reg[a[2].rstrip(']')], int):
                v = struct.unpack('<I', data((reg[a[1][1:]] + reg[a[2].rstrip(']')]) & 0xffffffff))[0]
                n = symname(syms, v)
                reg[a[0]] = Sym(n) if n else v
            elif op in ('ldr', 'ldrb', 'ldrh', 'ldrsh') and a[1].startswith('[fp'):
                reg[a[0]] = frame.get(a[2].rstrip(']') if len(a) > 2 else '#0')
            elif op in ('ldr', 'ldrb', 'ldrh', 'ldrsh', 'ldrd') and a[1].startswith('[r'):
                base = reg.get(a[1].strip('[]'))
                off = int(a[2].rstrip(']')[1:], 0) if len(a) > 2 and a[2].startswith('#') else 0
                if isinstance(base, Sym):
                    name = str(base)
                    if off:
                        b0, _, o0 = name.partition('+')
                        name = '%s+%d' % (b0, int(o0 or 0) + off)
                    reg[a[0]] = Val(name)
                else:
                    reg[a[0]] = None
            elif op == 'str' and a[1].startswith('[fp'):
                frame[a[2].rstrip(']') if len(a) > 2 else '#0'] = reg.get(a[0])
            elif op == 'add' and len(a) == 3 and a[2].startswith('#') and isinstance(reg.get(a[1]), int):
                reg[a[0]] = (reg[a[1]] + int(a[2][1:], 0)) & 0xffffffff
            elif op == 'add' and len(a) == 3 and a[2].startswith('#') and isinstance(reg.get(a[1]), Sym):
                b0, _, o0 = str(reg[a[1]]).partition('+')
                reg[a[0]] = Sym('%s+%d' % (b0, int(o0 or 0) + int(a[2][1:], 0)))
            elif op == 'sub' and len(a) == 3 and a[2].startswith('#') and isinstance(reg.get(a[1]), int):
                reg[a[0]] = (reg[a[1]] - int(a[2][1:], 0)) & 0xffffffff
            elif op == 'rsb' and len(a) == 3 and a[2] == '#0':
                v = reg.get(a[1])
                reg[a[0]] = (-v) & 0xffffffff if isinstance(v, int) else (Val('-' + v) if v is not None else None)
            elif op in ('add', 'sub', 'mul', 'lsl', 'asr') and len(a) == 3:
                x, y = reg.get(a[1]), reg.get(a[2]) if not a[2].startswith('#') else int(a[2][1:], 0)
                sign = {'add': '+', 'sub': '-', 'mul': '*', 'lsl': '<<', 'asr': '>>'}[op]
                if x is None or y is None or a[1] in ('fp', 'sp') or a[0] in ('fp', 'sp'):
                    reg[a[0]] = None
                else:
                    reg[a[0]] = Val('(%s%s%s)' % (show(x), sign, show(y)))
            elif op.startswith('cmp') and a[1].startswith('#'):
                print('  %x  cmp %s, %s' % (pc, show(reg.get(a[0])), a[1]))
            elif op in ('bl', 'blx') and '<' in m.group(3):
                callee = m.group(3).split('<')[1].split('>')[0].split('@')[0]
                if all_calls or re.match(r'Stepper|engine_|ENGINE_|upc_|usleep|sleep|IF_|UART_|tmc', callee):
                    print('  %x  %s(%s)' % (pc, callee, ', '.join(show(reg.get(r)) for r in ('r0', 'r1', 'r2', 'r3'))))
                for r in ('r0', 'r1', 'r2', 'r3', 'ip'):
                    reg.pop(r, None)
                reg['r0'] = Val('ret(%s)' % callee)
            elif a and re.match(r'r\d+$|ip$', a[0]) and op not in ('str', 'strb', 'strh', 'strd', 'push', 'tst', 'b', 'bx'):
                reg[a[0]] = None
        except (KeyError, TypeError, ValueError, IndexError, struct.error):
            if a:
                reg[a[0]] = None


def main():
    args = [x for x in sys.argv[1:] if not x.startswith('--')]
    data, syms = load(args[0])
    lines = open(args[1], encoding='utf-8', errors='replace').read().split('\n')
    for func in args[2:]:
        print('== %s' % func)
        trace(data, syms, lines, func, '--all-calls' in sys.argv)


if __name__ == '__main__':
    main()
