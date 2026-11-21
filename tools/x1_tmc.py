"""Read the 3DWOX 1X's TMC2224 motor drivers over their shared UART.

Runs on the printer's own Linux (any Python 3, no extra modules), as
root, AFTER Sindoh's motion program has been stopped (install/x1/x1_stop.sh):
that program owns /dev/ttyS2 while it runs.

    python3 x1_tmc.py scan            every select code 0..7, who answers
    python3 x1_tmc.py read N          the interesting registers of motor N
    python3 x1_tmc.py write N REG VALUE   (needs --yes; nothing else writes)

The drivers share one single-wire UART (ttyS2, 115200) behind a 3-bit
select: GPIO 149/147/146 carry the motor number (149 is the high bit),
and GPIO 152 gates the selector: pulsed high while the number changes,
low while talking (found on the machine 2026-11-21: with it high nobody
answers). Motor numbers in the stock program: X1 0, X2 1, Y 2, Z 3,
E1 4, E2 5, C1 6, C2 7. The 1X has drivers at 0, 2, 3, 4 and 6.
"""
import os, sys, termios, time, select

TTY = '/dev/ttyS2'
SEL = (149, 147, 146)       # most significant bit first
GATE = 152
REGS = [(0x00, 'GCONF'), (0x01, 'GSTAT'), (0x02, 'IFCNT'), (0x06, 'IOIN'),
        (0x10, 'IHOLD_IRUN'), (0x13, 'TPWMTHRS'), (0x6a, 'MSCNT'),
        (0x6c, 'CHOPCONF'),
        (0x6f, 'DRV_STATUS'), (0x70, 'PWMCONF')]


def gpio_set(n, v):
    d = '/sys/class/gpio/gpio%d' % n
    if not os.path.isdir(d):
        raise SystemExit('GPIO %d is not exported (the stock firmware exports it at boot)' % n)
    with open(d + '/value', 'w') as f:
        f.write('1' if v else '0')


def motor_select(n):
    gpio_set(GATE, 1)
    time.sleep(0.01)
    gpio_set(GATE, 0)
    for i, g in enumerate(SEL):
        gpio_set(g, (n >> (2 - i)) & 1)
    gpio_set(GATE, 0)
    time.sleep(0.005)


def crc8(data):
    crc = 0
    for b in data:
        for _ in range(8):
            if (crc >> 7) ^ (b & 1):
                crc = ((crc << 1) ^ 0x07) & 0xff
            else:
                crc = (crc << 1) & 0xff
            b >>= 1
    return crc


def tty_open():
    fd = os.open(TTY, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    a = termios.tcgetattr(fd)
    a[0] = 0; a[1] = 0; a[3] = 0
    a[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    a[4] = a[5] = termios.B115200
    a[6][termios.VMIN] = 0; a[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, a)
    return fd


def xfer(fd, tx, want):
    termios.tcflush(fd, termios.TCIOFLUSH)
    os.write(fd, bytes(tx))
    buf = b''
    end = time.time() + 0.15
    while len(buf) < want and time.time() < end:
        if select.select([fd], [], [], 0.02)[0]:
            buf += os.read(fd, 64)
    return buf


def read_reg(fd, reg):
    tx = [0x05, 0x00, reg & 0x7f]
    tx.append(crc8(tx))
    rx = xfer(fd, tx, 12)
    # single wire: our 4 bytes come back first, then the 8-byte answer
    i = rx.find(bytes([0x05, 0xff, reg & 0x7f]))
    if i < 0 or len(rx) < i + 8:
        return None, rx
    ans = rx[i:i + 8]
    if crc8(ans[:7]) != ans[7]:
        return None, rx
    return int.from_bytes(ans[3:7], 'big'), rx


def write_reg(fd, reg, val):
    tx = [0x05, 0x00, reg | 0x80] + list(val.to_bytes(4, 'big'))
    tx.append(crc8(tx))
    xfer(fd, tx, 8)


def chop_info(v):
    mres = (v >> 24) & 0xf
    return 'microsteps %d, toff %d, intpol %d' % (256 >> mres, v & 0xf, (v >> 28) & 1)


def main():
    args = [a for a in sys.argv[1:] if a != '--yes']
    if not args:
        raise SystemExit(__doc__)
    fd = tty_open()
    if args[0] == 'scan':
        for n in range(8):
            motor_select(n)
            v, raw = read_reg(fd, 0x06)
            print('select %d: %s' % (n, 'IOIN %08x (version %02x)' % (v, v >> 24)
                                     if v is not None else 'no answer (%s)' % raw.hex()))
    elif args[0] == 'read':
        n = int(args[1])
        motor_select(n)
        for reg, name in REGS:
            v, raw = read_reg(fd, reg)
            extra = ''
            if v is not None and name == 'CHOPCONF':
                extra = '  ' + chop_info(v)
            if v is not None and name == 'IOIN':
                # TMC222x pin layout (SEL_A, bit 8, reads 0 on them)
                extra = '  version %02x, ENN %d MS1 %d MS2 %d DIR %d' % (
                    v >> 24, (v >> 3) & 1, (v >> 5) & 1, (v >> 6) & 1, (v >> 2) & 1)
            print('motor %d %-11s %s%s' % (n, name, '%08x' % v if v is not None
                                           else 'no answer (%s)' % raw.hex(), extra))
    elif args[0] == 'write' and '--yes' in sys.argv:
        n, reg, val = int(args[1]), int(args[2], 0), int(args[3], 0)
        motor_select(n)
        before, _ = read_reg(fd, reg)
        write_reg(fd, reg, val)
        after, _ = read_reg(fd, reg)
        print('motor %d reg %#x: %s -> %s' % (n, reg, before, after))
    else:
        raise SystemExit(__doc__)


main()
