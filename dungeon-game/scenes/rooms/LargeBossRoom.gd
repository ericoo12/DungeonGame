extends RoomController

func _apply_floor_variant(variant: RoomFloorVariant) -> void:
	if not variant or not variant.texture:
		return
	var floor_patch := AtlasTexture.new()
	floor_patch.atlas = variant.texture
	floor_patch.region = Rect2(80, 48, 64, 48)
	$QuarterArt/FloorFill.texture = floor_patch
	for name in ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]:
		var atlas := AtlasTexture.new()
		atlas.atlas = variant.texture
		atlas.region = Rect2(10, 0, 202, 112)
		get_node("QuarterArt/" + name + "/Art").texture = atlas
