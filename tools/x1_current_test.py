# As curtest.py, but with a short, hard move: a motor whose current reference
# is at 0 still turns slowly without load (the drivers run in voltage mode),
# so the test asks for an acceleration only a motor with current can follow.
import sys, json, urllib.request, urllib.parse
B = 'http://10.10.0.169'
def get(p):
    return json.load(urllib.request.urlopen(B + p, timeout=30))['result']
def g(script):
    r = urllib.request.Request(B + '/printer/gcode/script?script=' + urllib.parse.quote(script), method='POST')
    return json.load(urllib.request.urlopen(r, timeout=90))
def on(ax):
    return get('/printer/query_endstops/status')['stepper_' + ax] == 'TRIGGERED'
ax, dist, inside, vel, accel = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
for pin in sys.argv[6:]:
    name, val = (pin.split('=') + [None])[:2]
    g('G28 ' + ax.upper()); g('G90'); g('G1 %s%s F1200' % (ax.upper(), inside)); g('M400')
    if not on(ax): sys.exit('%s: not on its sensor at the start' % ax)
    if val: g('SET_PIN PIN=%s VALUE=0' % name); g('G4 P1500')
    g('FORCE_MOVE STEPPER=stepper_%s DISTANCE=%s VELOCITY=%s ACCEL=%s' % (ax, dist, vel, accel))
    moved = not on(ax)
    if val: g('SET_PIN PIN=%s VALUE=%s' % (name, val))
    print('%-22s %s' % (name if val else 'baseline (nothing at 0)', 'came off the sensor' if moved else 'STAYED on the sensor'))
