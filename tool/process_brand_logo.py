"""Keep one ChatDENT mark: the in-app sidebar logo, copied to every icon slot."""
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
# Canonical mark — never regenerate this from brand/logo-light or logo-dark.
SRC = ROOT / "assets/images/logo.png"
_CHROME = (245, 243, 238, 255)


def flood_fill_white_bg(im: Image.Image, thresh: int = 242) -> Image.Image:
    """Knock out the square backdrop from the edges; keep the white speech bubble."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    visited = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or visited[y][x]:
            continue
        visited[y][x] = True
        r, g, b, a = px[x, y]
        if a < 8 or r < thresh or g < thresh or b < thresh:
            continue
        px[x, y] = (r, g, b, 0)
        q.append((x - 1, y))
        q.append((x + 1, y))
        q.append((x, y - 1))
        q.append((x, y + 1))
    return im


def corners_are_opaque_white(im: Image.Image) -> bool:
    w, h = im.size
    for xy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        r, g, b, a = im.getpixel(xy)
        if a < 250 or r < 242 or g < 242 or b < 242:
            return False
    return True


def resize(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print("wrote", path)


def scale_on_canvas(im: Image.Image, size: int, scale: float) -> Image.Image:
    """Center the mark at `scale` of the canvas (0.8 = 20% smaller)."""
    inner = max(1, int(round(size * scale)))
    tooth = resize(im.convert("RGBA"), inner)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    off = (size - inner) // 2
    canvas.alpha_composite(tooth, (off, off))
    return canvas


def flatten_on_chrome(
    im: Image.Image, size: int, scale: float = 1.0
) -> Image.Image:
    tooth = (
        scale_on_canvas(im, size, scale)
        if scale < 1
        else resize(im.convert("RGBA"), size)
    )
    canvas = Image.new("RGBA", (size, size), _CHROME)
    canvas.alpha_composite(tooth)
    return canvas.convert("RGB")


def main() -> None:
    mark = Image.open(SRC).convert("RGBA")
    if corners_are_opaque_white(mark):
        mark = flood_fill_white_bg(mark)
        save_png(mark, SRC)
    else:
        print("kept", SRC)

    # Same pixels everywhere — only the canvas size changes.
    # White speech bubble stays opaque; do not invert it for Android.
    save_png(resize(mark, 1024), ROOT / "assets/app_icon.png")
    save_png(resize(mark, 1024), ROOT / "assets/images/logo_transparent.png")
    save_png(resize(mark, 512), ROOT / "assets/app_icon_desktop.png")
    # Android launcher: 25% smaller so the tooth sits inside the round mask.
    save_png(scale_on_canvas(mark, 1024, 0.75), ROOT / "assets/app_icon_foreground.png")
    save_png(flatten_on_chrome(mark, 1024, 0.75), ROOT / "assets/app_icon_android.png")
    save_png(flatten_on_chrome(mark, 1024), ROOT / "assets/app_icon_ios.png")
    save_png(resize(mark, 256), ROOT / "docs/logo.png")

    save_png(flatten_on_chrome(mark, 48), ROOT / "web/favicon.png")
    save_png(flatten_on_chrome(mark, 192), ROOT / "web/icons/Icon-192.png")
    save_png(flatten_on_chrome(mark, 512), ROOT / "web/icons/Icon-512.png")
    save_png(flatten_on_chrome(mark, 192), ROOT / "web/icons/Icon-maskable-192.png")
    save_png(flatten_on_chrome(mark, 512), ROOT / "web/icons/Icon-maskable-512.png")

    # Do not overwrite windows/runner/resources/app_icon.ico — that icon is frozen.


if __name__ == "__main__":
    main()
