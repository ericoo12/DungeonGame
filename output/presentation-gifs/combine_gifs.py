from pathlib import Path
from PIL import Image

out = Path(__file__).resolve().parent
left = Image.open(out / 'dr-mugg-dancing.gif')
right = Image.open(out / 'captain-filling-dancing.gif')
frames = []
for i in range(8):
    left.seek(i)
    right.seek(i)
    frame = Image.new('RGBA', (768, 512))
    frame.alpha_composite(left.convert('RGBA'), (0, 0))
    frame.alpha_composite(right.convert('RGBA'), (384, 0))
    frames.append(frame)
atlas = Image.new('RGB', (768, 512 * 8))
for i, frame in enumerate(frames):
    atlas.paste(frame.convert('RGB'), (0, i * 512))
palette = atlas.quantize(colors=255)
encoded = []
for frame in frames:
    pal = frame.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE)
    pal.paste(255, mask=frame.getchannel('A').point(lambda x: 255 if x < 128 else 0))
    encoded.append(pal)
target = out / 'dr-mugg-and-captain-filling-dancing.gif'
encoded[0].save(target, save_all=True, append_images=encoded[1:], duration=180,
                loop=0, transparency=255, disposal=2, optimize=False)
with Image.open(target) as check:
    assert check.n_frames == 8
    assert check.info['loop'] == 0
    assert 'transparency' in check.info
    print(target, check.size, check.n_frames, target.stat().st_size)
frames[2].save(out / 'duo-preview.png')
