"""
Generates the SignBridge launcher-icon source assets.

The mark is the Material `sign_language` glyph (codepoint 0xf07c3) -- the same
icon the app already uses as its deaf-role identity in onboarding, login, the
role badge, captions and conversation cards. The gradient runs from the app's
deaf-role blue (#2563EB, role_badge.dart) to its hearing-role emerald
(#10B981), so the icon is the two roles meeting.

Run:  python_scripts/venv/Scripts/python.exe tools/generate_brand_icon.py
Out:  assets/branding/*.png
"""

import os
from PIL import Image, ImageDraw, ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "assets", "branding")

FONT_PATH = r"C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
GLYPH = chr(0xF07C3)  # Icons.sign_language

# AppColors: primary (deaf) -> secondary (hearing)
C_DEAF = (0x25, 0x63, 0xEB)
C_HEARING = (0x10, 0xB9, 0x81)

SIZE = 1024


def render_glyph(px):
    """Rasterise the glyph, cropped tight to its ink, on transparent."""
    font = ImageFont.truetype(FONT_PATH, px)
    canvas = Image.new("L", (px * 2, px * 2), 0)
    ImageDraw.Draw(canvas).text((px // 2, px // 2), GLYPH, font=font, fill=255)
    bbox = canvas.getbbox()
    if bbox is None:
        raise RuntimeError("glyph rendered empty -- font lacks the codepoint")
    return canvas.crop(bbox)


def gradient(w, h):
    """Diagonal blue -> emerald."""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / max(w - 1, 1) + y / max(h - 1, 1)) / 2.0
            px[x, y] = tuple(
                round(C_DEAF[i] + (C_HEARING[i] - C_DEAF[i]) * t) for i in range(3)
            )
    return img


def alpha_of(glyph, frac):
    """The glyph scaled to `frac` of the canvas height and centred, as a mask."""
    target = int(SIZE * frac)
    scale = target / glyph.height
    g = glyph.resize((max(1, int(glyph.width * scale)), target), Image.LANCZOS)
    layer = Image.new("L", (SIZE, SIZE), 0)
    layer.paste(g, ((SIZE - g.width) // 2, (SIZE - g.height) // 2))
    return layer


def place(bg, glyph, frac):
    """White glyph composited onto `bg`."""
    out = bg.copy()
    out.paste(Image.new("RGB", (SIZE, SIZE), (255, 255, 255)), (0, 0),
              alpha_of(glyph, frac))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    glyph = render_glyph(900)
    grad = gradient(SIZE, SIZE)

    # Full-bleed icon (legacy launcher + store listing + splash source).
    icon = place(grad, glyph, 0.52)
    icon.save(os.path.join(OUT, "icon_source_1024.png"))

    # Adaptive icon layers. Android masks to the central 66% safe zone, so the
    # foreground glyph is kept well inside it and the gradient goes full-bleed
    # behind, which is what stops the mark being clipped under a round mask.
    fg = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    fg.putalpha(alpha_of(glyph, 0.42))
    fg.save(os.path.join(OUT, "icon_foreground_1024.png"))

    grad.save(os.path.join(OUT, "icon_background_1024.png"))

    # Splash logo: the glyph alone on transparency, so it sits on the brand
    # background without a square tile edge showing around it.
    splash = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    splash.putalpha(alpha_of(glyph, 0.62))
    splash.save(os.path.join(OUT, "splash_logo.png"))

    # Preview sheet: how it reads at real launcher sizes.
    sheet = Image.new("RGB", (1100, 420), (0xF0, 0xF4, 0xF8))
    d = ImageDraw.Draw(sheet)
    x = 40
    for sz in (192, 144, 96, 72, 48):
        sheet.paste(icon.resize((sz, sz), Image.LANCZOS), (x, 60 + (192 - sz) // 2))
        d.text((x, 300), f"{sz}px", fill=(0x0F, 0x17, 0x2A))
        x += sz + 30
    # Round-masked preview, the worst case for clipping.
    from PIL import ImageDraw as _D
    m = Image.new("L", (256, 256), 0)
    _D.Draw(m).ellipse((0, 0, 255, 255), fill=255)
    circ = icon.resize((256, 256), Image.LANCZOS).convert("RGBA")
    circ.putalpha(m)
    sheet.paste(circ, (x, 34), circ)
    d.text((x, 300), "round mask", fill=(0x0F, 0x17, 0x2A))
    sheet.save(os.path.join(REPO, "build", "branding_preview.png"))

    print("wrote:")
    for f in sorted(os.listdir(OUT)):
        p = os.path.join(OUT, f)
        print(f"  assets/branding/{f}  {os.path.getsize(p)}B")


if __name__ == "__main__":
    main()
