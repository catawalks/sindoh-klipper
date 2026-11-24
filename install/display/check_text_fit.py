"""Render every page of dp200_screen.py off-screen and report text that
runs past the panel's edges. Nothing is sent to the printer (POSTs are
stubbed); it needs a running Moonraker for the status query, like the
other tests here.
    /usr/bin/python3 check_text_fit.py [--model dp200|1x] [--nobed]"""
import os, sys
from PIL import ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dp200_screen as S

if '--model' in sys.argv:
    m = sys.argv[sys.argv.index('--model') + 1].lower()
    S.IS_1X = m in ('1x', 'x1')
    S.MODEL = '1X' if S.IS_1X else 'DP200'
if '--nobed' in sys.argv:              # the DP201's pages (no heated bed)
    S.NO_BED, S.MODEL = True, 'DP201'
S.post = lambda *a, **k: {}

bad = []
_text = ImageDraw.ImageDraw.text


def text(self, xy, txt, *a, **k):
    f = k.get('font')
    anchor = k.get('anchor')
    try:
        x0, y0, x1, y1 = self.textbbox(xy, str(txt), font=f, anchor=anchor)
    except Exception:
        x0 = y0 = x1 = y1 = 0
    if txt and (x0 < -1 or x1 > S.PW + 1 or y1 > S.PH + 1):
        bad.append((CUR, str(txt)[:70], int(x0), int(x1), int(y1)))
    return _text(self, xy, txt, *a, **k)


ImageDraw.ImageDraw.text = text

ui = S.UI()
ui.settings = {}
ui.st = S.query()
try:
    ui.cmds = set(k.upper() for k in S.get('/printer/gcode/help'))
except Exception:
    ui.cmds = None
ui.info = S.system_info(ui.ip)
pages = sorted(n[5:] for n in dir(S.UI) if n.startswith('page_'))
skip = {'console', 'key_held', 'powering'}
CUR = ''
for name in pages:
    if name in skip:
        continue
    for estop in ((False, True) if name in ('key_off', 'timezone') else (False,)):
        CUR = name + (' (e-stop)' if estop else '')
        if name == 'timezone':           # the region list, then America's cities
            CUR = name + (' (America)' if estop else '')
            ui.tz = {'region': 'America' if estop else None, 'page': 0,
                     'cities': S.tz_cities('America') if estop else []}
        ui.screen = name
        ui.key_estop = estop
        ui.key_off_at = S.time.time() + S.KEY_CANCEL_1X if name == 'key_off' else 0.0
        ui.last_touch = S.time.time()
        try:
            ui.render()
        except Exception as e:
            bad.append((CUR, 'RENDER FAILED: %s' % e, 0, 0, 0))
print('%s: %d pages, %d problems' % (S.MODEL, len(pages) - len(skip), len(bad)))
for page, txt, x0, x1, y1 in bad:
    print('  %-14s x %d..%d (panel %d) y to %d: %r' % (page, x0, x1, S.PW, y1, txt))
