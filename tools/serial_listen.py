"""Listen on a serial port and log everything, without ever sending a byte.

    py -3.15t tools/serial_listen.py LOGFILE [PORT] [BAUD] [SECONDS]

For a first look at an unknown console (made for the 1X, 2026-11-20): no
write, no break, DTR/RTS left low. Each line gets the seconds since start.
Stops after SECONDS (default 600) or 60 s of silence once data has come.
"""
import sys, time
import serial

log = sys.argv[1]
port = sys.argv[2] if len(sys.argv) > 2 else "COM3"
baud = int(sys.argv[3]) if len(sys.argv) > 3 else 115200
limit = float(sys.argv[4]) if len(sys.argv) > 4 else 600

s = serial.Serial()
s.port, s.baudrate, s.timeout = port, baud, 0.2
s.dtr = False
s.rts = False
s.open()
t0 = time.time()
last = None
n = 0
buf = b""
with open(log, "wb") as f:
    f.write(f"# listening on {port} at {baud}, {time.strftime('%Y-%m-%d %H:%M:%S')}\n".encode())
    f.flush()
    while time.time() - t0 < limit:
        d = s.read(4096)
        if d:
            n += len(d)
            last = time.time()
            buf += d
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                f.write(f"[{time.time() - t0:8.2f}] ".encode() + line.rstrip(b"\r") + b"\n")
            f.flush()
        elif last and time.time() - last > 60:
            break
    if buf:
        f.write(f"[{time.time() - t0:8.2f}] ".encode() + buf + b"\n")
    f.write(f"# end: {n} bytes in {time.time() - t0:.0f} s\n".encode())
print(n, "bytes")
