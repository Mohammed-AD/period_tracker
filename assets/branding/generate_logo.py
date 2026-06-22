"""
Draws the Bloom app logo (5-petal flower mark) natively with PIL,
matching the SVG design: alternating pink/lavender petals, coral center,
small heart cutout, on a pale pink rounded-square background.
Rendered at high res (2048) then downsampled for clean anti-aliasing.
"""
import math
from PIL import Image, ImageDraw

SUPER = 2048  # render at 2x then downsample for AA
SIZE = 1024

# Brand colors (matching app_theme.dart)
BG = (255, 241, 245, 255)        # AppColors.cardBackground #FFF1F5
PETAL_PINK = (232, 160, 191, 255) # AppColors.primary #E8A0BF
PETAL_LAV = (185, 166, 221, 255)  # AppColors.secondary #B9A6DD
CENTER = (232, 96, 127, 255)      # AppColors.periodColor #E8607F


def rounded_rect_mask(size, radius):
    img = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return img


def draw_petal(draw, cx, cy, rx, ry, angle_deg, color):
    """Draw an ellipse petal rotated around (cx,cy) by angle_deg, offset outward."""
    # Petal center offset along the rotation direction, matching SVG translate(0,-185) rotate
    rad = math.radians(angle_deg)
    offset = 185 * (SUPER / 1024)
    px = cx + offset * math.sin(rad)
    py = cy - offset * math.cos(rad)

    # Build ellipse points then rotate around (px, py) by angle_deg
    pts = []
    steps = 64
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ex = rx * math.cos(t)
        ey = ry * math.sin(t)
        # rotate point by angle_deg around origin, then translate to (px, py)
        rx2 = ex * math.cos(rad) - ey * math.sin(rad)
        ry2 = ex * math.sin(rad) + ey * math.cos(rad)
        pts.append((px + rx2, py + ry2))
    draw.polygon(pts, fill=color)


def main():
    img = Image.new("RGBA", (SUPER, SUPER), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background rounded square
    radius = int(220 * (SUPER / 1024))
    draw.rounded_rectangle([0, 0, SUPER - 1, SUPER - 1], radius=radius, fill=BG)

    cx, cy = SUPER / 2, SUPER / 2
    rx = 83 * (SUPER / 1024)
    ry = 147 * (SUPER / 1024)

    angles = [0, 72, 144, 216, 288]
    colors = [PETAL_PINK, PETAL_LAV, PETAL_PINK, PETAL_LAV, PETAL_PINK]
    for angle, color in zip(angles, colors):
        draw_petal(draw, cx, cy, rx, ry, angle, color)

    # Center circle
    r = 83 * (SUPER / 1024)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CENTER)

    # Small heart cutout (drawn as background-colored heart on top of center circle)
    # Classic parametric heart curve: x = 16sin^3(t), y = -(13cos(t) - 5cos(2t) - 2cos(3t) - cos(4t))
    scale = (SUPER / 1024) * 2.6  # sizing to fit nicely inside the center circle
    heart_pts = []
    steps = 100
    for i in range(steps + 1):
        t = 2 * math.pi * i / steps
        hx = 16 * (math.sin(t) ** 3)
        hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        heart_pts.append((cx + hx * scale, cy + hy * scale))

    draw.polygon(heart_pts, fill=BG)

    # Downsample for clean anti-aliasing
    final = img.resize((SIZE, SIZE), Image.LANCZOS)
    final.save("/home/claude/period_tracker/assets/branding/logo_icon_1024.png")
    print("Saved logo_icon_1024.png")

    # --- Transparent variant (flower mark only, no background card) ---
    # Useful for Android adaptive icon foreground + in-app header logo.
    img2 = Image.new("RGBA", (SUPER, SUPER), (0, 0, 0, 0))
    draw2 = ImageDraw.Draw(img2)

    for angle, color in zip(angles, colors):
        draw_petal(draw2, cx, cy, rx, ry, angle, color)

    draw2.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CENTER)

    # Heart cutout: composite using alpha so it's a true transparent cutout,
    # not background-colored (works on any background now).
    mask = Image.new("L", (SUPER, SUPER), 0)
    mdraw = ImageDraw.Draw(mask)
    mdraw.polygon(heart_pts, fill=255)
    transparent = Image.new("RGBA", (SUPER, SUPER), (0, 0, 0, 0))
    img2 = Image.composite(transparent, img2, mask)

    final2 = img2.resize((SIZE, SIZE), Image.LANCZOS)
    final2.save("/home/claude/period_tracker/assets/branding/logo_mark_transparent.png")
    print("Saved logo_mark_transparent.png")


if __name__ == "__main__":
    main()
