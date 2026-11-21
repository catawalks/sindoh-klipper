"""Send G-code to Klipper on the 1X through its API socket, with optional
pauses, and print a time stamp for each step.
    python x1_gcode.py /path/klippy.sock "SET_PIN PIN=lights VALUE=0" 4 "SET_PIN PIN=lights VALUE=1"
A bare number is a pause in seconds."""
import json, socket, sys, time

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(30)
s.connect(sys.argv[1])
buf = b''
t0 = time.time()
for n, arg in enumerate(sys.argv[2:], 1):
    try:
        time.sleep(float(arg))
        continue
    except ValueError:
        pass
    s.sendall(json.dumps({'id': n, 'method': 'gcode/script', 'params': {'script': arg}}).encode() + b'\x03')
    while True:
        while b'\x03' not in buf:
            buf += s.recv(65536)
        msg, buf = buf.split(b'\x03', 1)
        m = json.loads(msg)
        if m.get('id') == n:
            print('%6.1f  %s  %s' % (time.time() - t0, arg, 'ok' if 'result' in m else m.get('error')), flush=True)
            break
print('SEQ_DONE', flush=True)
