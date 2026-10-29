## Builds a rectangular room's art at any size from a room "quarter" texture (224x112,
## the room's top-left corner: wall bands 32 px thick, corner plate, floor - like
## tiles/sewer.png or tiles/special_rooms/*_224x112.png):
##   - floor: the quarter's floor patch repeated MIRRORED out from the centre, exactly
##     like a normal room (so a picture drawn into the floor corner, e.g. the challenge
##     room's ritual circle, comes out whole in the middle),
##   - a wall band along each side, a corner plate in each corner.
## Used by the challenge room and Dr Mugg's arena; ShapedRoom shares the floor.
class_name RoomArt
extends RefCounted

## Parts of the quarter (same layout as RoomBase.tscn's Background).
## Sized so the drawn wall edge (the trim line) sits where a normal room draws it.
const Q_CORNER := Rect2(0, 0, 38, 35)
const Q_TOP_BAND := Rect2(42, 0, 170, 35)
const Q_LEFT_BAND := Rect2(0, 40, 38, 72)
## The floor (no walls); its right/bottom edges are a normal room's centre lines.
const Q_FLOOR := Rect2i(40, 36, 184, 76)
const BAND_X := 38.0   # side wall thickness
const BAND_Y := 35.0   # top/bottom wall thickness

static var _floor_cache: Dictionary = {}   # texture path -> ImageTexture of Q_FLOOR


## Art for a room of `size` centred on (0, 0), drawn under everything (z -2).
static func build(tex: Texture2D, size: Vector2) -> Node2D:
	var art := Node2D.new()
	art.name = "RoomArt"
	art.z_index = -2
	var w := size.x / 2.0
	var h := size.y / 2.0
	art.add_child(mirrored_floor(tex, size, Vector2.ZERO))
	# Wall bands: top/bottom use the top band, left/right the left band (mirrored).
	for side in [[Vector2(-w, -h), Vector2(1, 1), true], [Vector2(-w, h), Vector2(1, -1), true],
			[Vector2(-w, -h), Vector2(1, 1), false], [Vector2(w, -h), Vector2(-1, 1), false]]:
		var holder := Node2D.new()
		holder.position = side[0]
		holder.scale = side[1]
		if side[2]:
			holder.add_child(tiled(tex, Q_TOP_BAND, Vector2.ZERO, Vector2(size.x, BAND_Y)))
		else:
			holder.add_child(tiled(tex, Q_LEFT_BAND, Vector2.ZERO, Vector2(BAND_X, size.y)))
		art.add_child(holder)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var holder := Node2D.new()
		holder.position = Vector2(c.x * w, c.y * h)
		holder.scale = -c  # the plate is drawn as the top-left corner
		holder.add_child(tiled(tex, Q_CORNER, Vector2.ZERO, Q_CORNER.size))
		art.add_child(holder)
	return art


## The floor of a `size` box centred on `center` (local): the quarter's floor patch
## repeated mirrored, with an unmirrored patch ending exactly at the centre lines.
static func mirrored_floor(tex: Texture2D, size: Vector2, center: Vector2) -> Sprite2D:
	var patch: Texture2D = _floor_cache.get(tex.resource_path)
	if patch == null:
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		patch = ImageTexture.create_from_image(img.get_region(Q_FLOOR))
		_floor_cache[tex.resource_path] = patch
	var spr := Sprite2D.new()
	spr.texture = patch
	spr.centered = false
	spr.region_enabled = true
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var tile := Vector2(Q_FLOOR.size)
	var start := Vector2.ZERO
	for axis in 2:
		var k := 1
		while k * tile[axis] < size[axis] / 2.0:
			k += 2
		start[axis] = -k * tile[axis]
	spr.position = center - size / 2.0
	spr.region_rect = Rect2(-size / 2.0 - start, size)
	return spr


static func tiled(tex: Texture2D, region: Rect2, pos: Vector2, size: Vector2) -> TextureRect:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = region
	var tr := TextureRect.new()
	tr.texture = at
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.position = pos
	tr.size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
