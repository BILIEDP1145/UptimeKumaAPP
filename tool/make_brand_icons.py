"""Derive the launcher icon set from the supplied Uptime Kuma mark.

The source (`assets/images/icon_official.png`) is a white square with the green
Kuma circle in the middle. Two outputs are produced per colour way:

* legacy `mipmap-*/ic_launcher*.png` – the square cropped/resized as-is, so
  pre-Android-8 launchers show exactly the supplied artwork,
* an adaptive icon (`mipmap-anydpi-v26/*.xml`) with a white background and the
  circle as the foreground, so Android 8+ masks and scales it like any other
  app instead of shrinking a legacy bitmap inside its own mask.

Colour ways are produced by re-hueing the green circle only; the white field and
the antialiasing around the circle are preserved, so all four read as one logo.
"""
import os

from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'icon_official.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
ASSETS = os.path.join(ROOT, 'assets', 'images')

ADAPTIVE_PX = 432          # 108 dp × 4 (xxxhdpi)
FOREGROUND_RATIO = 0.62    # circle size relative to the 108 dp canvas
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

VARIANTS = {
    'default': None,               # untouched official green
    'emerald': (0x10, 0xB9, 0x81),
    'midnight': (0x2A, 0x38, 0x58),
    'crimson': (0xE2, 0x3D, 0x3D),
}


def square(img):
    """Center-crops [img] to a square."""
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return img.crop((left, top, left + side, top + side))


def rebue(img, target, work=256):
    """Repaints the green body with [target], keeping the shading.

    The recolour runs on a [work]-pixel copy: a per-pixel Python loop over the
    full artwork takes minutes, and every output size is smaller anyway.
    """
    if target is None:
        return img.copy()
    src = img.convert('RGBA').resize((work, work), Image.LANCZOS)
    px = src.load()
    w, h = src.size
    tr, tg, tb = target

    total, count = 0.0, 0
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            r, g, b, a = px[x, y]
            if a > 200 and g > r + 12 and g > b + 12:
                total += (r + g + b) / 3.0
                count += 1
    base = (total / count) if count else 170.0

    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if not (g > r + 12 and g > b + 12):
                dst[x, y] = (r, g, b, a)
                continue
            lum = max(0.0, min(1.45, ((r + g + b) / 3.0) / base))
            dst[x, y] = (
                min(255, int(tr * lum)),
                min(255, int(tg * lum)),
                min(255, int(tb * lum)),
                a,
            )
    return out


def foreground(img, canvas_px=ADAPTIVE_PX, ratio=FOREGROUND_RATIO):
    """Extracts the coloured circle and centres it on a transparent canvas."""
    rgb = img.convert('RGB')
    diff = ImageChops.difference(rgb, Image.new('RGB', rgb.size, (255, 255, 255)))
    bbox = diff.point(lambda v: 255 if v > 12 else 0).getbbox()
    if bbox is None:
        return Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))

    glyph = img.crop(bbox)
    side = int(canvas_px * ratio)
    scale = side / max(glyph.width, glyph.height)
    glyph = glyph.resize(
        (max(1, int(glyph.width * scale)), max(1, int(glyph.height * scale))),
        Image.LANCZOS,
    )
    out = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    out.paste(glyph, ((canvas_px - glyph.width) // 2, (canvas_px - glyph.height) // 2), glyph)
    return out


def main():
    if not os.path.exists(SRC):
        raise SystemExit('missing official artwork: %s' % SRC)

    official = square(Image.open(SRC).convert('RGBA'))
    written = []

    # One shared white background for every adaptive descriptor.
    bg_dir = os.path.join(RES, 'drawable-nodpi')
    os.makedirs(bg_dir, exist_ok=True)
    Image.new('RGBA', (ADAPTIVE_PX, ADAPTIVE_PX), (255, 255, 255, 255)).save(
        os.path.join(bg_dir, 'uk_bg_white.png')
    )
    written.append('drawable-nodpi/uk_bg_white.png')

    for name, target in VARIANTS.items():
        art = rebue(official, target)

        if name != 'default':  # never overwrite the source artwork
            preview_name = 'icon_%s.png' % name
            art.resize((256, 256), Image.LANCZOS).save(os.path.join(ASSETS, preview_name))
            written.append(preview_name)

        for density, size in DENSITIES.items():
            out_dir = os.path.join(RES, 'mipmap-%s' % density)
            os.makedirs(out_dir, exist_ok=True)
            fname = 'ic_launcher.png' if name == 'default' else 'ic_launcher_%s.png' % name
            art.resize((size, size), Image.LANCZOS).save(os.path.join(out_dir, fname))
            written.append('mipmap-%s/%s' % (density, fname))

        fg_name = 'uk_fg_default.png' if name == 'default' else 'uk_fg_%s.png' % name
        foreground(art).save(os.path.join(bg_dir, fg_name))
        written.append('drawable-nodpi/%s' % fg_name)

    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    for name in VARIANTS:
        fg_name = 'uk_fg_default' if name == 'default' else 'uk_fg_%s' % name
        alias = 'ic_launcher' if name == 'default' else 'ic_launcher_%s' % name
        xml = (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/uk_bg_white" />\n'
            '    <foreground android:drawable="@drawable/%s" />\n'
            '</adaptive-icon>\n' % fg_name
        )
        with open(os.path.join(anydpi, alias + '.xml'), 'w', encoding='utf-8') as fh:
            fh.write(xml)
        written.append('mipmap-anydpi-v26/%s.xml' % alias)

    print('\n'.join(written))
    print('done: %d files' % len(written))


if __name__ == '__main__':
    main()
