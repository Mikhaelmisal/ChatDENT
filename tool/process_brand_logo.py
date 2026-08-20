"""Crop ChatDENT logos to square assets with correct padding for each layout."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC_DARK = ROOT / "assets/brand/logo-dark.png"
SRC_LIGHT = ROOT / "assets/brand/logo-light.png"


def bbox_non_bg(im: Image.Image, is_dark: bool, thresh: int = 18) -> tuple[int, int, int, int]:
    px = im.convert("RGBA")
    w, h = px.size
    data = px.getdata()
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(h):
        row = y * w
        for x in range(w):
            r, g, b, a = data[row + x]
            if a < 8:
                continue
            if is_dark:
                if r + g + b < thresh * 3:
                    continue
            else:
                if r > 240 and g > 240 and b > 240:
                    continue
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
    if max_x <= min_x:
        return (0, 0, w, h)
    return (min_x, min_y, max_x + 1, max_y + 1)


def square_pad(im: Image.Image, pad_ratio: float, bg) -> Image.Image:
    w, h = im.size
    side = int(max(w, h) * (1 + pad_ratio * 2))
    canvas = Image.new("RGBA", (side, side), bg)
    canvas.paste(im, ((side - w) // 2, (side - h) // 2), im)
    return canvas


def to_transparent(im: Image.Image, is_dark: bool, thresh: int = 18) -> Image.Image:
    im = im.convert("RGBA")
    data = list(im.getdata())
    out = []
    for r, g, b, a in data:
        if is_dark:
            if r + g + b < thresh * 3:
                out.append((r, g, b, 0))
                continue
        else:
            if r > 240 and g > 240 and b > 240:
                out.append((r, g, b, 0))
                continue
        out.append((r, g, b, a))
    im.putdata(out)
    return im


def resize(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print("wrote", path)


def main() -> None:
    dark = Image.open(SRC_DARK).convert("RGBA")
    light = Image.open(SRC_LIGHT).convert("RGBA")

    dark_crop = dark.crop(bbox_non_bg(dark, True))
    light_crop = light.crop(bbox_non_bg(light, False))

    tooth_dark = to_transparent(dark_crop, True)
    tooth_light = to_transparent(light_crop, False)

    # In-app sidebar: light mark, extra horizontal room so it sits beside "ChatDENT"
    in_app = square_pad(tooth_light, 0.08, (0, 0, 0, 0))
    save_png(resize(in_app, 256), ROOT / "assets/images/logo.png")

    # App / MSIX / launcher: dark mark on black square (Windows taskbar)
    icon_dark = square_pad(tooth_dark, 0.14, (0, 0, 0, 255))
    icon_1024 = resize(icon_dark, 1024)
    save_png(icon_1024, ROOT / "assets/app_icon.png")
    save_png(resize(icon_dark, 512), ROOT / "assets/app_icon_desktop.png")

    # Adaptive / iOS / Android: light mark on white
    fg = square_pad(tooth_light, 0.22, (0, 0, 0, 0))
    save_png(resize(fg, 1024), ROOT / "assets/app_icon_foreground.png")
    android = square_pad(tooth_light, 0.16, (255, 255, 255, 255))
    save_png(resize(android, 1024), ROOT / "assets/app_icon_android.png")
    ios = square_pad(tooth_light, 0.16, (255, 255, 255, 255))
    save_png(resize(ios, 1024), ROOT / "assets/app_icon_ios.png")

    docs = ROOT / "docs/logo.png"
    save_png(resize(in_app, 256), docs)

    ico = resize(icon_dark, 256).convert("RGBA")
    ico_path = ROOT / "windows/runner/resources/app_icon.ico"
    ico.save(
        ico_path,
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print("wrote", ico_path)


if __name__ == "__main__":
    main()
