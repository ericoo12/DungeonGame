"""Package generated 4x2 dance sheets as transparent, looping slide GIFs."""
from pathlib import Path
import sys
from PIL import Image

OUT = Path(__file__).resolve().parent

def assemble(source, name):
    sheet = Image.open(source).convert('RGBA')
    frames = []
    for i in range(8):
        col, row = i % 4, i // 4
        frame = sheet.crop((col * sheet.width // 4, row * sheet.height // 2,
                            (col + 1) * sheet.width // 4, (row + 1) * sheet.height // 2))
        frames.append(frame)
    # Register generated rows to a common foot baseline before GIF encoding.
    boxes = [frame.getchannel('A').point(lambda x: 255 if x >= 128 else 0).getbbox() for frame in frames]
    scale = min(400 / max(b[3] - b[1] for b in boxes), 340 / max(b[2] - b[0] for b in boxes))
    registered = []
    for i, (frame, box) in enumerate(zip(frames, boxes)):
        sprite = frame.crop(box)
        sprite = sprite.resize((round(sprite.width * scale), round(sprite.height * scale)), Image.Resampling.NEAREST)
        canvas = Image.new('RGBA', (384, 512))
        # The lifted-arm frame also has a small hop.
        canvas.alpha_composite(sprite, ((384 - sprite.width) // 2, 466 - sprite.height - (14 if i == 6 else 0)))
        registered.append(canvas)
    frames = registered
    # Reserve palette index 255 exclusively for full GIF transparency.
    rgb_sheet = sheet.convert('RGB').quantize(colors=255)
    encoded = []
    for frame in frames:
        pal = frame.convert('RGB').quantize(palette=rgb_sheet, dither=Image.Dither.NONE)
        alpha = frame.getchannel('A')
        pal.paste(255, mask=alpha.point(lambda x: 255 if x < 128 else 0))
        pal.info['transparency'] = 255
        encoded.append(pal)
    target = OUT / f'{name}-dancing.gif'
    encoded[0].save(target, save_all=True, append_images=encoded[1:], duration=180,
                    loop=0, transparency=255, disposal=2, optimize=False)
    frames[0].save(OUT / f'{name}-preview.png')
    with Image.open(target) as check:
        assert check.n_frames == 8, check.n_frames
        assert check.info['loop'] == 0
        print(f'{target}: {check.n_frames} frames, {check.size}, {target.stat().st_size} bytes')

if __name__ == '__main__':
    assemble(sys.argv[1], sys.argv[2])
