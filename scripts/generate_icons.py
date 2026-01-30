#!/usr/bin/env python3
"""
Generate macOS app icons for Claude Trace menu bar app.
Creates a sunburst design matching the github-banner.png logo.
"""

import math
from PIL import Image, ImageDraw

# Colors from the banner
BACKGROUND_COLOR = (248, 245, 240)  # Cream/off-white
SUNBURST_COLOR = (204, 102, 68)     # Orange/coral (#CC6644)
CENTER_DOT_COLOR = (204, 102, 68)   # Same orange


def draw_sunburst(size: int) -> Image.Image:
    """Draw the sunburst logo at the given size."""
    # Create image with some padding
    img = Image.new('RGBA', (size, size), BACKGROUND_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    center_x = size / 2
    center_y = size / 2

    # Scale factors based on size
    # The sunburst should fill most of the icon with some margin
    margin = size * 0.1
    available = size - (margin * 2)

    # Center dot radius (relative to available space)
    center_radius = available * 0.06

    # Inner ring of rays
    inner_ray_start = available * 0.12
    inner_ray_end = available * 0.22
    inner_ray_width = max(1, size * 0.015)
    num_inner_rays = 16

    # Outer ring of rays
    outer_ray_start = available * 0.25
    outer_ray_end = available * 0.48
    outer_ray_width = max(1, size * 0.025)
    num_outer_rays = 16

    # Draw outer rays first
    for i in range(num_outer_rays):
        angle = (i * 360 / num_outer_rays) - 90  # Start from top
        rad = math.radians(angle)

        x1 = center_x + outer_ray_start * math.cos(rad)
        y1 = center_y + outer_ray_start * math.sin(rad)
        x2 = center_x + outer_ray_end * math.cos(rad)
        y2 = center_y + outer_ray_end * math.sin(rad)

        draw.line([(x1, y1), (x2, y2)], fill=SUNBURST_COLOR, width=int(outer_ray_width))

    # Draw inner rays (offset by half the angle between outer rays)
    for i in range(num_inner_rays):
        angle = (i * 360 / num_inner_rays) + (180 / num_inner_rays) - 90
        rad = math.radians(angle)

        x1 = center_x + inner_ray_start * math.cos(rad)
        y1 = center_y + inner_ray_start * math.sin(rad)
        x2 = center_x + inner_ray_end * math.cos(rad)
        y2 = center_y + inner_ray_end * math.sin(rad)

        draw.line([(x1, y1), (x2, y2)], fill=SUNBURST_COLOR, width=int(inner_ray_width))

    # Draw center dot
    dot_bbox = [
        center_x - center_radius,
        center_y - center_radius,
        center_x + center_radius,
        center_y + center_radius
    ]
    draw.ellipse(dot_bbox, fill=SUNBURST_COLOR)

    return img


def main():
    import os

    # Output directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    output_dir = os.path.join(
        project_dir,
        'apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar/Assets.xcassets/AppIcon.appiconset'
    )

    # macOS icon sizes: (base_size, scale, pixel_size)
    icon_specs = [
        (16, 1, 16),
        (16, 2, 32),
        (32, 1, 32),
        (32, 2, 64),
        (128, 1, 128),
        (128, 2, 256),
        (256, 1, 256),
        (256, 2, 512),
        (512, 1, 512),
        (512, 2, 1024),
    ]

    print(f"Generating icons in: {output_dir}")

    # Generate each icon size
    filenames = []
    for base_size, scale, pixel_size in icon_specs:
        filename = f"icon_{base_size}x{base_size}{'@2x' if scale == 2 else ''}.png"
        filepath = os.path.join(output_dir, filename)

        print(f"  Generating {filename} ({pixel_size}x{pixel_size} pixels)...")
        img = draw_sunburst(pixel_size)
        img.save(filepath, 'PNG')
        filenames.append((base_size, scale, filename))

    # Generate updated Contents.json
    images = []
    for base_size, scale, filename in filenames:
        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": f"{scale}x",
            "size": f"{base_size}x{base_size}"
        })

    contents = {
        "images": images,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

    import json
    contents_path = os.path.join(output_dir, 'Contents.json')
    with open(contents_path, 'w') as f:
        json.dump(contents, f, indent=2)
    print(f"  Updated Contents.json")

    print("\nDone! Icons generated successfully.")


if __name__ == '__main__':
    main()
