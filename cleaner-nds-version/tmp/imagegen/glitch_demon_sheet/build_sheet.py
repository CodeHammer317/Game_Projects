from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(r"C:\Users\blazi\Game_Projects\cleaner-nds-version")
SOURCE = ROOT / "tmp/imagegen/glitch_demon_sheet/keyposes-transparent.png"
OUTPUT_DIR = ROOT / "Assets/sprites/GlitchDemon"
SHEET_PATH = OUTPUT_DIR / "GlitchDemon_16x16_256_Sheet.png"
GUIDE_PATH = OUTPUT_DIR / "GlitchDemon_16x16_256_LabeledGuide.png"
METADATA_PATH = OUTPUT_DIR / "GlitchDemon_16x16_256_Animations.json"
FONT_PATH = ROOT / "Assets/Fonts/pixy/PIXY.ttf"

FRAME_SIZE = 256
GRID_COLUMNS = 16
GRID_ROWS = 16
ACTIVE_ROWS = [
    {"name": "Idle", "fps": 8, "loop": True},
    {"name": "Forward", "fps": 10, "loop": True},
    {"name": "Grow", "fps": 8, "loop": True},
    {"name": "Fire1", "fps": 12, "loop": False},
    {"name": "Fire2", "fps": 14, "loop": False},
    {"name": "Fire3", "fps": 15, "loop": False},
    {"name": "GlitchBurst", "fps": 14, "loop": False},
    {"name": "Hit", "fps": 14, "loop": False},
    {"name": "Death", "fps": 8, "loop": False},
]


def remove_green_residue(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    cleaned = []
    for red, green, blue, alpha in image.getdata():
        is_green = green > 72 and green > red * 1.16 and green > blue * 1.16
        cleaned.append((red, green, blue, 0 if is_green else alpha))
    image.putdata(cleaned)
    return image


def extract_key_poses() -> list[Image.Image]:
    source = remove_green_residue(Image.open(SOURCE))
    cell_width = source.width // 3
    cell_height = source.height // 3
    poses: list[Image.Image] = []

    for row in range(3):
        for column in range(3):
            cell = source.crop(
                (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
            bounds = cell.getchannel("A").getbbox()
            if bounds is None:
                poses.append(Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE)))
                continue

            subject = cell.crop(bounds)
            subject.thumbnail((238, 238), Image.Resampling.NEAREST)
            frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
            x = (FRAME_SIZE - subject.width) // 2
            y = FRAME_SIZE - subject.height - 8
            frame.alpha_composite(subject, (x, y))
            poses.append(frame)

    return poses


def transform_pose(
    pose: Image.Image,
    scale_x: float = 1.0,
    scale_y: float = 1.0,
    offset_x: int = 0,
    offset_y: int = 0,
    opacity: float = 1.0,
) -> Image.Image:
    width = max(1, round(FRAME_SIZE * scale_x))
    height = max(1, round(FRAME_SIZE * scale_y))
    transformed = pose.resize((width, height), Image.Resampling.NEAREST)

    if opacity < 1.0:
        alpha = transformed.getchannel("A").point(
            lambda value: round(value * max(0.0, min(opacity, 1.0)))
        )
        transformed.putalpha(alpha)

    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE))
    x = (FRAME_SIZE - width) // 2 + offset_x
    y = FRAME_SIZE - height + offset_y
    frame.alpha_composite(transformed, (x, y))
    return frame


def add_glitch_shift(image: Image.Image, row: int, frame_index: int, strength: int) -> Image.Image:
    if strength <= 0:
        return image

    rng = random.Random(1907 + row * 101 + frame_index * 17)
    result = image.copy()
    for _ in range(strength):
        height = rng.randint(2, 7)
        y = rng.randint(18, FRAME_SIZE - height - 8)
        shift = rng.choice((-3, -2, 2, 3))
        strip = image.crop((0, y, FRAME_SIZE, y + height))
        result.alpha_composite(strip, (shift, y))
    return result


def animation_frame(poses: list[Image.Image], row: int, index: int) -> Image.Image:
    phase = index / GRID_COLUMNS
    wave = math.sin(phase * math.tau)
    base = poses[0]
    key = poses[row]

    if row == 0:  # Idle
        frame = transform_pose(base, 1.0 + 0.006 * wave, 1.0 - 0.008 * wave, 0, round(-2 * wave))
        return add_glitch_shift(frame, row, index, 1 if index in (3, 11) else 0)

    if row == 1:  # Forward
        frame = transform_pose(key, 1.0 + 0.012 * wave, 1.0 - 0.012 * wave, round(2 * wave), -abs(round(3 * wave)))
        return add_glitch_shift(frame, row, index, 1)

    if row == 2:  # Grow
        pulse = 0.5 - 0.5 * math.cos(phase * math.tau)
        frame = transform_pose(key, 0.9 + 0.1 * pulse, 0.84 + 0.16 * pulse, 0, round(-3 * pulse))
        return add_glitch_shift(frame, row, index, 1 + int(pulse > 0.65))

    if row in (3, 4, 5):  # Fire variants: wind-up, discharge, recovery
        if index < 4:
            charge = index / 4.0
            frame = transform_pose(base, 1.0 - charge * 0.025, 1.0 + charge * 0.025, 0, round(-2 * charge))
        elif index < 13:
            recoil = math.sin((index - 4) / 9.0 * math.pi)
            frame = transform_pose(key, 1.0 + 0.015 * recoil, 1.0 - 0.012 * recoil, round(-2 * recoil), -round(recoil))
        else:
            recovery = (index - 13) / 3.0
            frame = transform_pose(base, 0.985 + recovery * 0.015, 1.015 - recovery * 0.015)
        return add_glitch_shift(frame, row, index, 1 + int(5 <= index <= 11))

    if row == 6:  # Glitch Burst
        burst = math.sin(min(1.0, index / 12.0) * math.pi * 0.5)
        opacity = 1.0 if index < 13 else max(0.35, 1.0 - (index - 12) * 0.16)
        frame = transform_pose(key, 0.88 + 0.12 * burst, 0.88 + 0.12 * burst, 0, -round(2 * burst), opacity)
        return add_glitch_shift(frame, row, index, 1 + int(3 <= index <= 13) * 2)

    if row == 7:  # Hit
        if index < 3 or index > 12:
            frame = transform_pose(base)
        else:
            recoil = math.sin((index - 3) / 9.0 * math.pi)
            frame = transform_pose(key, 1.0 + 0.025 * recoil, 1.0 - 0.025 * recoil, round(7 * recoil), round(2 * recoil))
        return add_glitch_shift(frame, row, index, 2 if 3 <= index <= 12 else 0)

    # Death
    if index < 2:
        return transform_pose(base)
    progress = (index - 2) / 13.0
    opacity = 1.0 if progress < 0.65 else max(0.0, 1.0 - (progress - 0.65) / 0.35)
    frame = transform_pose(
        key,
        1.0 - progress * 0.08,
        1.0 - progress * 0.12,
        round(progress * 5),
        round(progress * 16),
        opacity,
    )
    return add_glitch_shift(frame, row, index, 1 + round(progress * 4))


def build_runtime_sheet(poses: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE * GRID_COLUMNS, FRAME_SIZE * GRID_ROWS),
        (0, 0, 0, 0),
    )

    for row in range(len(ACTIVE_ROWS)):
        for column in range(GRID_COLUMNS):
            frame = animation_frame(poses, row, column)
            sheet.alpha_composite(frame, (column * FRAME_SIZE, row * FRAME_SIZE))

    return sheet


def draw_labeled_guide(sheet: Image.Image) -> Image.Image:
    guide_cell = 64
    gutter = 210
    grid_width = guide_cell * GRID_COLUMNS
    grid_height = guide_cell * GRID_ROWS
    guide = Image.new("RGB", (gutter + grid_width, grid_height), (8, 10, 17))
    draw = ImageDraw.Draw(guide)

    # Checkerboard makes transparency visible without altering the runtime sheet.
    for row in range(GRID_ROWS):
        for column in range(GRID_COLUMNS):
            shade = (28, 31, 43) if (row + column) % 2 == 0 else (19, 22, 32)
            x0 = gutter + column * guide_cell
            y0 = row * guide_cell
            draw.rectangle((x0, y0, x0 + guide_cell - 1, y0 + guide_cell - 1), fill=shade)

    preview = sheet.resize((grid_width, grid_height), Image.Resampling.NEAREST)
    guide.paste(preview, (gutter, 0), preview)

    font = ImageFont.truetype(str(FONT_PATH), 18)
    small_font = ImageFont.truetype(str(FONT_PATH), 12)
    for row in range(GRID_ROWS):
        y0 = row * guide_cell
        draw.line((0, y0, gutter + grid_width, y0), fill=(82, 42, 116), width=1)
        if row < len(ACTIVE_ROWS):
            item = ACTIVE_ROWS[row]
            draw.text((12, y0 + 10), f"{row:02d}  {item['name'].upper()}", font=font, fill=(223, 124, 255))
            loop_text = "LOOP" if item["loop"] else "ONCE"
            draw.text((12, y0 + 36), f"16 FRAMES // {item['fps']} FPS // {loop_text}", font=small_font, fill=(139, 221, 255))
        else:
            draw.text((12, y0 + 20), f"{row:02d}  UNUSED", font=font, fill=(86, 91, 110))

    for column in range(GRID_COLUMNS + 1):
        x = gutter + column * guide_cell
        draw.line((x, 0, x, grid_height), fill=(62, 66, 86), width=1)
    draw.line((gutter - 1, 0, gutter - 1, grid_height), fill=(190, 86, 255), width=2)
    return guide


def write_metadata() -> None:
    metadata = {
        "image": SHEET_PATH.name,
        "frame_size": [FRAME_SIZE, FRAME_SIZE],
        "grid": {"columns": GRID_COLUMNS, "rows": GRID_ROWS},
        "animations": [
            {
                "name": item["name"],
                "row": row,
                "first_column": 0,
                "frame_count": GRID_COLUMNS,
                "fps": item["fps"],
                "loop": item["loop"],
            }
            for row, item in enumerate(ACTIVE_ROWS)
        ],
        "unused_rows": list(range(len(ACTIVE_ROWS), GRID_ROWS)),
    }
    METADATA_PATH.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    poses = extract_key_poses()
    sheet = remove_green_residue(build_runtime_sheet(poses))
    sheet.save(SHEET_PATH, optimize=True)
    draw_labeled_guide(sheet).save(GUIDE_PATH, optimize=True)
    write_metadata()
    print(
        {
            "sheet": str(SHEET_PATH),
            "sheet_size": sheet.size,
            "active_rows": len(ACTIVE_ROWS),
            "frames_per_row": GRID_COLUMNS,
            "total_animation_frames": len(ACTIVE_ROWS) * GRID_COLUMNS,
        }
    )


if __name__ == "__main__":
    main()
