#!/usr/bin/env python3
"""Generate MeetsRecord app icon and menu bar icons."""

from PIL import Image, ImageDraw
import os
import shutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
RESOURCES_DIR = os.path.join(PROJECT_DIR, "MeetsRecord", "Resources")
ICONSET_DIR = os.path.join(RESOURCES_DIR, "AppIcon.appiconset")

os.makedirs(ICONSET_DIR, exist_ok=True)


def draw_waveform(draw, cx, cy, radius, color, num_bars=5, bar_width_ratio=0.09):
    """Draw a stylized audio waveform centered at (cx, cy)."""
    bar_w = max(int(radius * bar_width_ratio * 2), 1)
    spacing = radius * 0.24
    heights = [0.30, 0.60, 1.0, 0.60, 0.30]

    total_width = (num_bars - 1) * spacing
    start_x = cx - total_width / 2

    for i, h in enumerate(heights):
        bx = start_x + i * spacing
        bar_h = radius * 0.65 * h
        x0 = bx - bar_w / 2
        x1 = bx + bar_w / 2
        y0 = cy - bar_h
        y1 = cy + bar_h
        r = max(bar_w / 2, 1)
        draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=color)


def generate_app_icon(size):
    """Generate the main app icon at a given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    padding = size * 0.05
    corner_radius = size * 0.22

    # Background — warm coral
    bg_rect = [padding, padding, size - padding, size - padding]
    draw.rounded_rectangle(bg_rect, radius=corner_radius, fill=(255, 95, 87))

    # Subtle bottom shadow for depth
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    half_y = size * 0.55
    odraw.rounded_rectangle(
        [padding, half_y, size - padding, size - padding],
        radius=corner_radius,
        fill=(220, 60, 50, 50)
    )
    img = Image.alpha_composite(img, overlay)
    draw = ImageDraw.Draw(img)

    # White circle
    cx, cy = size / 2, size / 2
    circle_r = size * 0.30
    draw.ellipse(
        [cx - circle_r, cy - circle_r, cx + circle_r, cy + circle_r],
        fill=(255, 255, 255, 235)
    )

    # Waveform inside the circle
    draw_waveform(draw, cx, cy, circle_r, color=(255, 95, 87))

    # Small record dot at top-right of the circle
    dot_r = size * 0.05
    dot_cx = cx + circle_r * 0.7
    dot_cy = cy - circle_r * 0.7
    draw.ellipse(
        [dot_cx - dot_r, dot_cy - dot_r, dot_cx + dot_r, dot_cy + dot_r],
        fill=(255, 255, 255, 240)
    )
    # Inner red dot
    inner_r = dot_r * 0.6
    draw.ellipse(
        [dot_cx - inner_r, dot_cy - inner_r, dot_cx + inner_r, dot_cy + inner_r],
        fill=(255, 59, 48)
    )

    return img


def generate_menu_bar_icon(size, state="idle"):
    """Generate a menu bar icon (template style — black on transparent)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = size / 2, size / 2

    if state == "idle":
        draw_waveform(draw, cx, cy, size * 0.4, color=(0, 0, 0, 255),
                      num_bars=5, bar_width_ratio=0.13)
    elif state == "recording":
        r = size * 0.32
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 59, 48))
    elif state == "paused":
        bar_w = size * 0.12
        bar_h = size * 0.5
        gap = size * 0.08
        r = max(bar_w / 3, 1)
        draw.rounded_rectangle(
            [cx - gap - bar_w, cy - bar_h/2, cx - gap, cy + bar_h/2],
            radius=r, fill=(0, 0, 0, 255)
        )
        draw.rounded_rectangle(
            [cx + gap, cy - bar_h/2, cx + gap + bar_w, cy + bar_h/2],
            radius=r, fill=(0, 0, 0, 255)
        )

    return img


# =============================================================================
# App icons
# =============================================================================
print("🎨 Generating app icons...")

icon_sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in icon_sizes:
    icon = generate_app_icon(s)
    icon.save(os.path.join(ICONSET_DIR, f"icon_{s}x{s}.png"), "PNG")
    print(f"  ✅ {s}x{s}")

# Contents.json
import json
contents = {
    "images": [
        {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
        {"filename": "icon_64x64.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
        {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
        {"filename": "icon_1024x1024.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
    ],
    "info": {"author": "xcode", "version": 1}
}
with open(os.path.join(ICONSET_DIR, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

# =============================================================================
# .icns via iconutil
# =============================================================================
print("\n🎨 Converting to .icns...")

iconset_path = os.path.join(RESOURCES_DIR, "AppIcon.iconset")
icns_path = os.path.join(RESOURCES_DIR, "AppIcon.icns")

os.makedirs(iconset_path, exist_ok=True)

icon_mappings = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

for fname, size in icon_mappings.items():
    icon = generate_app_icon(size)
    icon.save(os.path.join(iconset_path, fname), "PNG")

ret = os.system(f'iconutil -c icns "{iconset_path}" -o "{icns_path}"')
if ret == 0:
    print(f"  ✅ AppIcon.icns created")
else:
    print(f"  ⚠️  iconutil failed (code {ret})")

shutil.rmtree(iconset_path, ignore_errors=True)

# =============================================================================
# Menu bar icons
# =============================================================================
print("\n🎨 Generating menu bar icons...")

MENUBAR_DIR = os.path.join(RESOURCES_DIR, "MenuBarIcons")
os.makedirs(MENUBAR_DIR, exist_ok=True)

for state in ["idle", "recording", "paused"]:
    for scale, suffix in [(18, ""), (36, "@2x")]:
        icon = generate_menu_bar_icon(scale, state)
        icon.save(os.path.join(MENUBAR_DIR, f"menubar_{state}{suffix}.png"), "PNG")
        print(f"  ✅ menubar_{state}{suffix}.png")

print("\n✅ All icons generated!")
