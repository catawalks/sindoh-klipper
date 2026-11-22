"""3DWOX 1X bring-up: print the four filament switch inputs whenever one
changes (needs a config with them as gcode_button, e.g. x1_stage5f.cfg).
Run next to klippy:  python x1_sens.py /path/klippy.sock [SECONDS]"""
import json, socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.settimeout(5)
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 120
buf = b''
def call(m, p):
    global buf
    s.sendall(json.dumps({'id': 1, 'method': m, 'params': p}).encode() + b'\x03')
    while True:
        while b'\x03' not in buf: buf += s.recv(65536)
        msg, buf = buf.split(b'\x03', 1)
        r = json.loads(msg)
        if r.get('id') == 1: return r.get('result', {})
names = ['cart_filament_0', 'cart_filament_1', 'extr_filament_0', 'extr_filament_1']
objs = {'gcode_button ' + n: None for n in names}
last = None; t0 = time.time()
while time.time() - t0 < secs:
    st = call('objects/query', {'objects': objs})['status']
    cur = tuple(st['gcode_button ' + n]['state'][0] for n in names)
    if cur != last:
        print('%6.1f  gpio76=%s gpio80=%s gpio121=%s gpio120=%s' % ((time.time() - t0,) + cur), flush=True)
        last = cur
    time.sleep(0.1)
print('SENS_DONE (P = pin high, R = pin low)', flush=True)
