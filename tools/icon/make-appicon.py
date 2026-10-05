#!/usr/bin/env python3
"""make-appicon.py — generate the Perfect Passwords Grabber app icon.

An asterisk, the character a password field shows in place of each letter,
folded down its centre the way the sibling apps' glyphs are: orange on blue,
lit on the left and in shade on the right. FilmStrip is the reference for the
ground and the two planes — the colours below were sampled from its icon — so
PPG sits on the same shelf as WaxOnWaxOff, ClipHack, FilmStrip and KeyVault
rather than near it.

Five arms, not six. A six-armed cross with square ends and one arm upright is
the Star of Life, the sign on an ambulance, and an earlier pass read as exactly
that. Five is the asterisk of most text faces, and it keeps an arm on the fold.
No key and no lock either: those are KeyVault's, and the two apps share a Dock.

Geometry follows Apple's macOS grid: on a 1024 canvas the body is 824x824 with
a ~185 corner radius, inset 100 a side, which is where every sibling sits. The
icon this replaces was lettering on a white tile that filled its canvas edge to
edge, and was not even square (2169x2184).

Everything is drawn at 4x and downsampled with Lanczos — PIL's polygons and
rounded rectangles are aliased, and the fold seam shows every jaggy at 1024.

Usage:
  python3 tools/icon/make-appicon.py [--out FILE]

Writes assets/AppIcon.icns, which release.sh copies into the bundle. Requires
Pillow, and iconutil from the Xcode command line tools.
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFilter
except ImportError:
    sys.exit("make-appicon: Pillow is required — pip install Pillow")

# ── Canvas ────────────────────────────────────────────────────────────────────
BASE = 1024          # the coordinate space every number below is written in
SS = 4               # supersampling factor
S = BASE * SS

BODY_INSET = 100     # Apple's grid: 824x824 body on a 1024 canvas
CORNER = 185

# The .iconset an .icns is built from: (point size, scale) -> file name.
ICONSET = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
           (256, 1), (256, 2), (512, 1), (512, 2)]

# ── Palette ───────────────────────────────────────────────────────────────────
# FilmStrip's ground, sampled down its left margin. It is not a straight ramp:
# it falls away quickly under the top edge and flattens toward the bottom, and a
# two-stop gradient between the same end colours reads visibly paler.
GROUND = [(100, (38, 104, 149)), (300, (18, 89, 137)), (500, (1, 77, 127)),
          (700, (0, 70, 116)), (924, (0, 64, 107))]
# The two planes either side of the fold, each a touch darker at the foot.
LIT = [(150, (252, 158, 72)), (874, (246, 145, 62))]
SHADE = [(150, (198, 95, 14)), (874, (190, 88, 10))]
GLYPH_SHADOW = (0, 18, 36)

# ── Glyph ─────────────────────────────────────────────────────────────────────
ARMS = 5
ARM_REACH = 322      # centre to the tip of each arm
ARM_WIDTH = 142
ARM_CORNER = 22      # crisp ends, as the siblings' glyphs have, not round caps


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def px(v):
    """1024-space value -> supersampled pixels."""
    return int(round(v * SS))


def vertical_gradient(stops):
    """A full-canvas gradient through (y, colour) stops, flat beyond the ends."""
    column = Image.new("RGB", (1, BASE))
    for y in range(BASE):
        if y <= stops[0][0]:
            colour = stops[0][1]
        elif y >= stops[-1][0]:
            colour = stops[-1][1]
        else:
            for (y0, c0), (y1, c1) in zip(stops, stops[1:]):
                if y0 <= y <= y1:
                    colour = lerp(c0, c1, (y - y0) / (y1 - y0))
                    break
        column.putpixel((0, y), colour)
    return column.resize((S, S), Image.BILINEAR)


def arm(angle, cx, cy):
    """One arm as a mask: a bar from just behind the hub out to ARM_REACH,
    pointing `angle` degrees clockwise from 12 o'clock."""
    tail = ARM_WIDTH * 0.3            # tucks the inner end under its neighbours
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [px(cx - ARM_WIDTH / 2), px(cy - ARM_REACH),
         px(cx + ARM_WIDTH / 2), px(cy + tail)],
        radius=px(ARM_CORNER), fill=255)
    # PIL rotates counter-clockwise.
    return m.rotate(-angle, resample=Image.BICUBIC, center=(px(cx), px(cy)))


def asterisk():
    # Centre the glyph's bounding box rather than its hub: with an arm straight
    # up and none straight down, the hub sits above the middle. The two lower
    # arms bottom out on the rounding of their outer corners, not at their
    # tips, so that corner's arc is what sets the lowest point.
    cx = BASE / 2
    tilt = math.radians(180 / ARMS)               # lower arms, off straight down
    lowest = ((ARM_REACH - ARM_CORNER) * math.cos(tilt)
              + (ARM_WIDTH / 2 - ARM_CORNER) * math.sin(tilt) + ARM_CORNER)
    cy = BASE / 2 + (ARM_REACH - lowest) / 2
    m = Image.new("L", (S, S), 0)
    for k in range(ARMS):
        m = ImageChops.lighter(m, arm(k * 360 / ARMS, cx, cy))
    return m


def build_master():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    body = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body).rounded_rectangle(
        [px(BODY_INSET), px(BODY_INSET),
         px(BASE - BODY_INSET), px(BASE - BODY_INSET)],
        radius=px(CORNER), fill=255)

    # ── Shadow ────────────────────────────────────────────────────────────────
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.putalpha(ImageChops.offset(body, 0, px(10))
                    .point(lambda v: v * 78 // 255))
    canvas = Image.alpha_composite(
        canvas, shadow.filter(ImageFilter.GaussianBlur(px(10))))

    # ── Ground ────────────────────────────────────────────────────────────────
    ground = vertical_gradient(GROUND).convert("RGBA")
    ground.putalpha(body)
    canvas = Image.alpha_composite(canvas, ground)

    # ── Glyph ─────────────────────────────────────────────────────────────────
    glyph = asterisk()

    # Its shadow falls down and to the right, and stays on the ground.
    cast = Image.new("RGBA", (S, S), GLYPH_SHADOW + (0,))
    cast.putalpha(ImageChops.offset(glyph, px(12), px(22))
                  .point(lambda v: v * 175 // 255))
    cast = cast.filter(ImageFilter.GaussianBlur(px(18)))
    cast.putalpha(ImageChops.multiply(cast.getchannel("A"), body))
    canvas = Image.alpha_composite(canvas, cast)

    # The fold: lit left of the vertical centre line, shade right of it.
    right = Image.new("L", (S, S), 0)
    ImageDraw.Draw(right).rectangle([px(BASE / 2), 0, S, S], fill=255)
    planes = Image.composite(vertical_gradient(SHADE), vertical_gradient(LIT),
                             right).convert("RGBA")
    planes.putalpha(glyph)
    return Image.alpha_composite(canvas, planes)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.normpath(
        os.path.join(here, "..", "..", "assets", "AppIcon.icns"))

    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=default_out,
                    help="the .icns file to write")
    args = ap.parse_args()

    if not os.path.isdir(os.path.dirname(os.path.abspath(args.out))):
        sys.exit(f"make-appicon: no such directory: {os.path.dirname(args.out)}")

    master = build_master()
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.mkdir(iconset)
        for points, scale in ICONSET:
            suffix = "@2x" if scale == 2 else ""
            size = points * scale
            name = f"icon_{points}x{points}{suffix}.png"
            master.resize((size, size), Image.LANCZOS).save(
                os.path.join(iconset, name), "PNG")
        subprocess.run(["iconutil", "-c", "icns", "-o", args.out, iconset],
                       check=True)
    print(f"  wrote {os.path.relpath(args.out)}")


if __name__ == "__main__":
    main()
