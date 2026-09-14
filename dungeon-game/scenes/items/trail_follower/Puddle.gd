## A damaging pool left behind by TrailFollower. Ticks damage on anything
## overlapping (same repeat-contact pattern as Orbital/TickBeamVisual), fades
## over its final half-second, then self-destructs.
extends Area2D
class_name Puddle

var damage: float = 2.0
var lifetime: float = 2.5
var tick_interval: float = 0.5

var tick_timer: float = 0.0
var timer: float = 0.0
var overlapping_bodies: Array[Node] = []

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func setup(dmg: float, life: float, radius: float) -> void:
	damage = dmg
	lifetime = life
	
	var circle := shape.shape as CircleShape2D
	if circle:
		circle.radius = radius
	
	if sprite.texture:
		var native_radius: float = sprite.texture.get_size().x / 2
		sprite.scale = Vector2.ONE * (radius / native_radius)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	timer += delta

	var fade_start: float = lifetime - 0.5
	if timer >= fade_start:
		modulate.a = 1.0 - clamp((timer - fade_start) / 0.5, 0.0, 1.0)

	if overlapping_bodies.size() > 0:
		tick_timer -= delta
		if tick_timer <= 0.0:
			tick_timer = tick_interval
			for body in overlapping_bodies:
				if is_instance_valid(body) and body.has_method("take_damage"):
					body.take_damage(damage)

	if timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	overlapping_bodies.append(body)
	if body.has_method("take_damage"):
		tick_timer = tick_interval
		body.take_damage(damage)


func _on_body_exited(body: Node) -> void:
	overlapping_bodies.erase(body)
