"""Generates the DocFlip app icon (macOS iconset PNGs + Windows .ico).

Usage: python3 tool/make_icon.py   (needs: pip install pillow; macOS fonts)
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 4096  # supersampled canvas, downscaled for anti-aliasing
FONT = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size, bold):
    # HelveticaNeue.ttc: index 1 = Bold, index 0 = Regular
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def master():
    m = int(S * 0.098)             # margin (macOS icon grid)
    x0, y0, x1, y1 = m, m, S - m, S - m
    r = int(S * 0.18)
    mid = (y0 + y1) // 2

    body = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body).rounded_rectangle((x0, y0, x1, y1), r, fill=255)

    # Vertical gradients: light top, dark bottom.
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = ImageDraw.Draw(img)
    for y in range(y0, y1):
        if y < mid:
            t = (y - y0) / (mid - y0)
            c = int(252 - 12 * t)
        else:
            t = (y - mid) / (y1 - mid)
            c = int(70 - 14 * t)
        px.line((x0, y, x1, y), fill=(c, c, c, 255))

    # Notch: light triangle pointing down into the dark half.
    cx, nw, nh = S // 2, int(S * 0.06), int(S * 0.055)
    notch = Image.new("L", (S, S), 0)
    ImageDraw.Draw(notch).polygon(
        [(cx - nw, mid), (cx + nw, mid), (cx, mid + nh)], fill=255)
    notch = notch.filter(ImageFilter.GaussianBlur(S * 0.004))
    light = Image.new("RGBA", (S, S), (240, 240, 240, 255))
    img.paste(light, (0, 0), notch)

    # Text.
    d = ImageDraw.Draw(img)
    f1, f2 = font(int(S * 0.24), True), font(int(S * 0.285), False)
    d.text((S // 2, (y0 + mid) // 2 - int(S * 0.01)), "DOCX", font=f1,
           fill=(58, 58, 58, 255), anchor="mm")
    d.text((S // 2, (mid + y1) // 2 + int(S * 0.02)), "MD", font=f2,
           fill=(255, 255, 255, 255), anchor="mm")

    # Clip to rounded body, add soft drop shadow.
    clipped = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    clipped.paste(img, (0, 0), body)
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 120), (0, int(S * 0.012)), body)
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.012))
    out = Image.alpha_composite(shadow, clipped)
    return out


if __name__ == "__main__":
    big = master()
    big.resize((1024, 1024), Image.LANCZOS).save("docs/icon.png")
    for n in (16, 32, 64, 128, 256, 512, 1024):
        big.resize((n, n), Image.LANCZOS).save(
            f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{n}.png")
    big.resize((256, 256), Image.LANCZOS).save(
        "windows/runner/resources/app_icon.ico",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icons written")
