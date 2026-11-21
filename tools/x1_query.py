"""Print Klipper's state on the 1X (stage 4): MCUs, temperatures, inputs.
Run next to klippy:  python x1_query.py /path/to/klippy.sock
Talks to Klipper's API socket directly, so Moonraker is not needed."""
import json, socket, sys

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5)
s.connect(sys.argv[1])
buf = b''


def call(method, params=None):
    global buf
    s.sendall(json.dumps({'id': 1, 'method': method, 'params': params or {}}).encode() + b'\x03')
    while True:
        while b'\x03' not in buf:
            buf += s.recv(65536)
        msg, buf = buf.split(b'\x03', 1)
        m = json.loads(msg)
        if m.get('id') == 1:
            return m.get('result', m.get('error'))


info = call('info')
print('klippy state:', info.get('state'), '-', (info.get('state_message') or '').strip().replace('\n', ' | '))
names = call('objects/list').get('objects', [])
want = [n for n in names if n.split()[0] in ('mcu', 'temperature_sensor', 'gcode_button', 'output_pin', 'heater_generic', 'heater_fan')]
st = call('objects/query', {'objects': {n: None for n in want}}).get('status', {})
for n in sorted(st):
    v = st[n]
    if n.startswith('mcu'):
        ls = v.get('last_stats', {})
        print('%-28s %s  freq %s  awake %s  retransmit %s' % (
            n, v.get('mcu_version'), ls.get('freq'), ls.get('mcu_awake'), ls.get('bytes_retransmit')))
    elif n.startswith('temperature_sensor'):
        print('%-28s %.1f C' % (n, v.get('temperature', float('nan'))))
    elif n.startswith('heater_generic'):
        print('%-28s %.1f C  target %.0f  power %.2f' % (n, v.get('temperature', 0), v.get('target', 0), v.get('power', 0)))
    elif n.startswith('heater_fan'):
        print('%-28s speed %s' % (n, v.get('speed')))
    elif n.startswith('output_pin'):
        print('%-28s %s' % (n, v.get('value')))
    else:
        print('%-28s %s' % (n, v.get('state')))
