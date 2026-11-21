"""Turn a raw copy of the 1X's stock screen into an upright PNG.

On the printer (read-only):   cat /dev/fb0 > fb.raw
Then, where Pillow is installed (the SD card's Debian root has it):
    python3 x1_fbshot.py fb.raw screen.png

The 1X's framebuffer is 800 x 1440, 24 bit, of which the first 800 x 480
is what the panel shows, stored sideways.
"""
import sys
from PIL import Image

W, H, VISIBLE = 800, 1440, 480
d = open(sys.argv[1], 'rb').read()[:W * H * 3]
im = Image.frombuffer('RGB', (W, H), d, 'raw', 'BGR', 0, 1)
im.crop((0, 0, W, VISIBLE)).rotate(90, expand=True).save(sys.argv[2])
print('saved', sys.argv[2])
