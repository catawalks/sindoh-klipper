# Does an axis keep its position at speed? Home, run back and forth, then
# step up to the home sensor's edge: it must switch within 0.5 mm of where
# homing put it. X and Y only; nothing moves in Z.
#   speedtest.py SPEED ACCEL TRIPS
import sys, json, urllib.request, urllib.parse
B = 'http://10.10.0.169'


def get(p):
    return json.load(urllib.request.urlopen(B + p, timeout=30))['result']


def g(script):
    r = urllib.request.Request(B + '/printer/gcode/script?script=' + urllib.parse.quote(script), method='POST')
    return json.load(urllib.request.urlopen(r, timeout=120))


def on(ax):
    return get('/printer/query_endstops/status')['stepper_' + ax] == 'TRIGGERED'


speed, accel, trips = float(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3])
s = get('/printer/objects/query?configfile=settings')['status']['configfile']['settings']
print('limits', s['printer']['max_velocity'], s['printer']['max_accel'])
g('G28 X'); g('G28 Y'); g('G90')
g('SET_VELOCITY_LIMIT VELOCITY=%g ACCEL=%g' % (speed, accel))
for ax, lo, hi, edge, sign in (('x', 20, 230, 242.4, 1), ('y', 20, 190, 5.5, -1)):
    A = ax.upper()
    g('G1 %s%g F6000' % (A, hi if ax == 'x' else lo))
    for i in range(trips):
        g('G1 %s%g F%d' % (A, lo if ax == 'x' else hi, speed * 60))
        g('G1 %s%g F%d' % (A, hi if ax == 'x' else lo, speed * 60))
    g('M400')
    before = edge - sign * 0.5      # just off the sensor
    after = edge + sign * 0.5       # just on it
    g('G1 %s%g F600' % (A, before)); g('M400'); a = on(ax)
    g('G1 %s%g F600' % (A, after)); g('M400'); b = on(ax)
    print('%s: %d trips of %d mm at %g mm/s, %g mm/s2: sensor %s 0.5 mm before its edge, %s 0.5 mm after -> %s'
          % (A, trips, hi - lo, speed, accel, 'ON' if a else 'off', 'on' if b else 'OFF',
             'position kept' if (not a and b) else 'POSITION LOST'))
    g('G1 %s%g F3000' % (A, edge - sign * 20))
