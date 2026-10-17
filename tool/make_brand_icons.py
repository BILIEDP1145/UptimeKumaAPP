"""Derive the launcher icon set from Uptime Kuma's official `public/icon.svg`.

The upstream artwork is a green rounded glyph with a *semi-transparent* white
stroke, drawn on a 640×640 canvas. Shipped as a legacy bitmap it renders small
and washed-out on Android 8+, because the system expects an adaptive icon
(108 dp canvas, 72 dp safe zone) and shrinks bare bitmaps to fit its own mask.

This script therefore produces three things per variant:

* legacy `mipmap-*/ic_launcher*.png` – the artwork magnified so it fills the
  frame instead of floating in transparent padding,
* an adaptive background bitmap (`drawable-nodpi/uk_bg_*.png`) used by the
  `mipmap-anydpi-v26/ic_launcher*.xml` descriptors, so every launcher mask
  scales the icon the same way as any other app,
* the in-app previews used by the icon picker and the About page.

Colour ways are produced by re-hueing the green body only; the white stroke and
the alpha channel are preserved, so all four look like the same logo.
"""
import os

from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SRC = os.path.join(ROOT, 'assets', 'images', 'icon_official.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
ASSETS = os.path.join(ROOT, 'assets', 'images')

# Android wants 108 dp; xxhdpi = 3×.
ADAPTIVE_PX = 432
DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}

# The official gradient runs #5CDD8B → #86E6A9. The other three keep the same
# luminance curve so the glyph reads identically, only the hue moves.
VARIANTS = {
    'default': None,                      # untouched official green
    'emerald': (0x10, 0xB9, 0x81),
    'midnight': (0x2A, 0x38, 0x58),
    'crimson': (0xE2, 0x3D, 0x3D),
}


def rebue(img, target):
    """Repaints the green body of [img] with [target], keeping shading."""
    if target is None:
        return img.copy()
    src = img.convert('RGBA')
    px = src.load()
    w, h = src.size
    tr, tg, tb = target

    # Mean luminance of the original body, used to normalise the gradient.
    total = 0.0
    count = 0
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
            is_body = g > r + 12 and g > b + 12
            if not is_body:
                # White stroke / antialiasing: keep as drawn.
                dst[x, y] = (r, g, b, a)
                continue
            lum = ((r + g + b) / 3.0) / base
            lum = max(0.0, min(1.45, lum))
            dst[x, y] = (
                min(255, int(tr * lum)),
                min(255, int(tg * lum)),
                min(255, int(tb * lum)),
                a,
            )
    return out


def zoom_center(img, factor):
    """Scales [img] about its centre and crops back to the original frame."""
    w, h = img.size
    big = img.resize((int(w * factor), int(h * factor)), Image.LANCZOS)
    left = (big.width - w) // 2
    top = (big.height - h) // 2
    return big.crop((left, top, left + w, top + h))


def trim_to_content(img, pad_ratio=0.02):
    """Crops transparent border, then re-centres on a square canvas."""
    bbox = img.getbbox()
    if not bbox:
        return img
    cropped = img.crop(bbox)
    side = max(cropped.size)
    side = int(side * (1 + pad_ratio * 2))
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(
        cropped,
        ((side - cropped.width) // 2, (side - cropped.height) // 2),
        cropped,
    )
    return canvas


def main():
    if not os.path.exists(SRC):
        raise SystemExit('missing official artwork: %s' % SRC)

    official = Image.open(SRC).convert('RGBA')
    written = []

    for name, target in VARIANTS.items():
        art = rebue(official, target)

        # In-app preview (also the icon picker grid).
        preview_name = 'icon_official.png' if name == 'default' else 'icon_%s.png' % name
        preview = art.resize((256, 256), Image.LANCZOS)
        preview.save(os.path.join(ASSETS, preview_name))
        written.append(preview_name)

        # Legacy bitmaps: trim the transparent margin, then draw edge-to-edge so
        # pre-Android-8 launchers do not shrink the artwork.
        solid = trim_to_content(art)
        for density, size in DENSITIES.items():
            out_dir = os.path.join(RES, 'mipmap-%s' % density)
            os.makedirs(out_dir, exist_ok=True)
            fname = 'ic_launcher.png' if name == 'default' else 'ic_launcher_%s.png' % name
            solid.resize((size, size), Image.LANCZOS).save(os.path.join(out_dir, fname))
            written.append('mipmap-%s/%s' % (density, fname))

        # Adaptive background: 108 dp canvas, artwork magnified so the glyph
        # still reaches the edges after a circular mask.
        bg_dir = os.path.join(RES, 'drawable-nodpi')
        os.makedirs(bg_dir, exist_ok=True)
        bg = zoom_center(solid, 1.16).resize((ADAPTIVE_PX, ADAPTIVE_PX), Image.LANCZOS)
        bg_name = 'uk_bg_default.png' if name == 'default' else 'uk_bg_%s.png' % name
        bg.save(os.path.join(bg_dir, bg_name))
        written.append('drawable-nodpi/%s' % bg_name)

    # Adaptive descriptors. `foreground` is a fully transparent bitmap: the
    # artwork already carries its own background, so keeping it in the background
    # layer lets launchers apply their mask without double-shrinking it.
    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    fg_path = os.path.join(RES, 'drawable-nodpi', 'uk_fg_blank.png')
    Image.new('RGBA', (ADAPTIVE_PX, ADAPTIVE_PX), (0, 0, 0, 0)).save(fg_path)
    written.append('drawable-nodpi/uk_fg_blank.png')

    for name in VARIANTS:
        bg_name = 'uk_bg_default' if name == 'default' else 'uk_bg_%s' % name
        alias = 'ic_launcher' if name == 'default' else 'ic_launcher_%s' % name
        xml = (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/%s" />\n'
            '    <foreground android:drawable="@drawable/uk_fg_blank" />\n'
            '</adaptive-icon>\n' % bg_name
        )
        with open(os.path.join(anydpi, alias + '.xml'), 'w', encoding='utf-8') as fh:
            fh.write(xml)
        written.append('mipmap-anydpi-v26/%s.xml' % alias)

    print('\n'.join(written))
    print('done: %d files' % len(written))


if __name__ == '__main__':
    main()
