"""Outline of functions in a PIC ARM ELF: the calls they make, the strings
they use, and the global variables they reach through the GOT, in order.
Made for Sindoh's engine programs (which keep their dynamic symbols).

    python tools/elfcalls.py app.elf func [func...]

Needs: pip install pyelftools capstone
"""
import struct, sys
from capstone import Cs, CS_ARCH_ARM, CS_MODE_ARM
from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection

e = ELFFile(open(sys.argv[1], 'rb'))
dyn = e.get_section_by_name('.dynsym')
syms = list(dyn.iter_symbols())
by_name = {s.name: s for s in syms if s.name}
by_addr = {}
for s in syms:
    if s.name and s['st_value']:
        by_addr.setdefault(s['st_value'] & ~1, s.name)
segs = [(s['p_vaddr'], s.data()) for s in e.iter_segments() if s['p_type'] == 'PT_LOAD']
got = {}                                   # GOT slot address -> symbol name
plt = {}
for sec in e.iter_sections():
    if isinstance(sec, RelocationSection):
        st = e.get_section(sec['sh_link'])
        for r in sec.iter_relocations():
            n = st.get_symbol(r['r_info_sym']).name
            if n:
                got[r['r_offset']] = n


def mem(a, n):
    for va, d in segs:
        if va <= a and a + n <= va + len(d):
            return d[a - va:a - va + n]
    return None


def u32(a):
    b = mem(a, 4)
    return struct.unpack('<I', b)[0] if b else None


def cstr(a):
    b = mem(a, 1)
    if b is None:
        return None
    out = b''
    while len(out) < 160:
        c = mem(a + len(out), 1)
        if not c or c == b'\0':
            break
        if not (32 <= c[0] < 127 or c[0] in (9, 10, 13)):
            return None
        out += c
    return out.decode() if len(out) >= 3 else None


# PLT stubs: "add ip, pc, #..; add ip, ip, #..; ldr pc, [ip, #..]!" -> GOT slot
def plt_target(a):
    w = [u32(a + i * 4) for i in range(3)]
    if None in w or (w[0] >> 20) != 0xe28 or (w[2] >> 20) != 0xe5b:
        return None
    def imm(x):
        rot = (x >> 8) & 0xf
        v = x & 0xff
        return ((v >> (2 * rot)) | (v << (32 - 2 * rot))) & 0xffffffff
    slot = (a + 8 + imm(w[0]) + imm(w[1]) + (w[2] & 0xfff)) & 0xffffffff
    return got.get(slot)


md = Cs(CS_ARCH_ARM, CS_MODE_ARM)
for want in sys.argv[2:]:
    s = by_name[want]
    a0, n = s['st_value'] & ~1, s['st_size']
    code = mem(a0, n)
    print('==== %s @ %#x (%d bytes)' % (want, a0, n))
    gotbase = {}                            # reg -> GOT-relative base value
    lit = {}
    insns = list(md.disasm(code, a0))
    for k, i in enumerate(insns):
        op = i.op_str
        if i.mnemonic == 'ldr' and '[pc' in op:
            reg = op.split(',')[0]
            off = int(op.split('#')[1].rstrip(']'), 0) if '#' in op else 0
            v = u32(i.address + 8 + off)
            lit[reg] = v
            continue
        if i.mnemonic == 'add' and op.replace(' ', '').endswith('pc,' + op.split(',')[0].strip()) or \
           (i.mnemonic == 'add' and ', pc, ' in op):
            reg = op.split(',')[0]
            src = op.split(',')[2].strip()
            if src in lit and lit[src] is not None:
                val = (i.address + 8 + lit[src]) & 0xffffffff
                gotbase[reg] = val
                t = cstr(val)
                if t:
                    print('  %06x  "%s"' % (i.address, t.replace('\n', '\\n')))
            continue
        if i.mnemonic == 'ldr' and op.count('[') == 1 and ']' in op:
            inner = op[op.index('[') + 1:op.index(']')].replace(' ', '').split(',')
            if len(inner) == 2 and inner[0] in gotbase and inner[1] in lit and lit[inner[1]] is not None:
                slot = (gotbase[inner[0]] + lit[inner[1]]) & 0xffffffff
                name = got.get(slot)
                if name:
                    print('  %06x  var %s' % (i.address, name))
            continue
        if i.mnemonic in ('bl', 'blx') and op.startswith('#'):
            t = int(op[1:], 0)
            name = by_addr.get(t) or plt_target(t) or ('sub_%x' % t)
            print('  %06x  call %s' % (i.address, name))
