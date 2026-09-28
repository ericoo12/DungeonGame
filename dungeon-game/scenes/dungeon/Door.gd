extends Area2D
class_name Door

## Which texture pair the door uses. Set by RoomBase each time a room loads,
## based on the room on the other side (or this room, if it's the special one).
enum Style { NORMAL, ITEM, BOSS }

@export var direction: Vector2i = Vector2i.ZERO

# Normal door — names kept the same so existing values set in the editor aren't lost.
@export_group("Normal")
@export var closed_texture: Texture2D
@export var open_texture: Texture2D

# Item/boss textures fall back to the normal ones if left empty,
# so doors keep working before the new art is assigned.
@export_group("Item Room")
@export var item_closed_texture: Texture2D
@export var item_open_texture: Texture2D

@export_group("Boss Room")
@export var boss_closed_texture: Texture2D
@export var boss_open_texture: Texture2D

@export_group("")

var unlocked: bool = true
var style: Style = Style.NORMAL

@onready var sprite: Sprite2D = $Sprite2D
@onready var physical_blocker: CollisionShape2D = $PhysicalBlocker/CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_unlocked(unlocked)
	_update_visual()


func set_unlocked(value: bool) -> void:
	unlocked = value
	monitoring = value
	if physical_blocker:
		physical_blocker.set_deferred("disabled", value)
	_update_visual()


func set_style(value: Style) -> void:
	style = value
	_update_visual()


func _update_visual() -> void:
	if not is_node_ready():
		return  # _ready() calls this again once the sprite exists

	var closed := closed_texture
	var open := open_texture
	match style:
		Style.ITEM:
			if item_closed_texture: closed = item_closed_texture
			if item_open_texture: open = item_open_texture
		Style.BOSS:
			if boss_closed_texture: closed = boss_closed_texture
			if boss_open_texture: open = boss_open_texture

	sprite.texture = open if unlocked else closed


func _on_body_entered(body: Node) -> void:
	if not unlocked or not body.is_in_group("player"):
		return
	var dungeon := get_tree().get_first_node_in_group("dungeon")
	if dungeon:
		dungeon.call_deferred("travel", direction)
