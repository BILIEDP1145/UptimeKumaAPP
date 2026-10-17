"""Generate the launcher icon set + in-app previews.

Design: squircle tile with a two-stop diagonal gradient and a heartbeat
polyline. Four colour ways, all sharing one geometry so the icon stays
recognisable when the user switches it.
"""
import os

from PIL import Image, ImageDraw

SS = 4  # supersampling factor


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(size, top, bottom):
    img = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        for_x = y / max(1, size - 1)
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, for_x))
    return img


def squircle_mask(size, radius_ratio=0.235):
    m = Image.new('L', (size * SS, size * SS), 0)
    d = ImageDraw.Draw(m)
    r = int(size * SS * radius_ratio)
    d.rounded_rectangle([0, 0, size * SS - 1, size * SS - 1], radius=r, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def draw_glyph(img, accent):
    """Heartbeat polyline: flat, spike, recovery, flat."""
    size = img.size[0]
    layer = Image.new('RGBA', (size * SS, size * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    s = size * SS

    def pt(x, y):
        return (s * x, s * y)

    stroke = int(s * 0.062)
    pts = [
        pt(0.17, 0.52),
        pt(0.33, 0.52),
        pt(0.41, 0.33),
        pt(0.52, 0.70),
        pt(0.61, 0.46),
        pt(0.68, 0.52),
        pt(0.83, 0.52),
    ]
    d.line(pts, fill=(255, 255, 255, 255), width=stroke, joint='curve')
    # round the caps
    for p in (pts[0], pts[-1]):
        r = stroke / 2
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255, 255))

    # subtle accent halo behind the peak
    peak = pt(0.52, 0.70)
    r = s * 0.16
    halo = Image.new('RGBA', layer.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse(
        [peak[0] - r, peak[1] - r, peak[0] + r, peak[1] + r],
        fill=accent + (46,),
    )
    layer = Image.alpha_composite(halo, layer)
    return layer.resize((size, size), Image.LANCZOS)


VARIANTS = {
    'default': {'top': (0x16, 0x70, 0xF5), 'bottom': (0x0B, 0x3F, 0xB8), 'accent': (0x9C, 0xC8, 0xFF)},
    'emerald': {'top': (0x10, 0xB9, 0x81), 'bottom': (0x04, 0x78, 0x57), 'accent': (0xA7, 0xF3, 0xD0)},
    'midnight': {'top': (0x2A, 0x38, 0x58), 'bottom': (0x0A, 0x11, 0x1F), 'accent': (0x7D, 0x9C, 0xD8)},
    'crimson': {'top': (0xE2, 0x3D, 0x3D), 'bottom': (0x8E, 0x17, 0x17), 'accent': (0xFF, 0xC2, 0xC2)},
}

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def build(size, cfg):
    base = gradient(size, cfg['top'], cfg['bottom']).convert('RGBA')
    base.putalpha(squircle_mask(size))
    glyph = draw_glyph(base, cfg['accent'])
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.alpha_composite(base)
    out.alpha_composite(glyph)
    return out


if __name__ == '__main__':
    root = os.path.dirname(os.path.abspath(__file__))
    project = os.path.abspath(os.path.join(root, '..'))

    preview_dir = os.path.join(project, 'assets', 'images')
    os.makedirs(preview_dir, exist_ok=True)

    for name, cfg in VARIANTS.items():
        preview = build(256, cfg)
        preview.save(os.path.join(preview_dir, f'icon_{name}.png'))
        print('preview', name)

        for density, size in DENSITIES.items():
            res = os.path.join(project, 'android', 'app', 'src', 'main', 'res', f'mipmap-{density}')
            os.makedirs(res, exist_ok=True)
            fname = 'ic_launcher.png' if name == 'default' else f'ic_launcher_{name}.png'
            build(size, cfg).save(os.path.join(res, fname))
        print('mipmaps', name)

    # A wide banner used by the dashboard header fallback.
    print('done')
