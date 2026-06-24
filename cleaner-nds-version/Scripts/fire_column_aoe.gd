extends Area2D
class_name FireColumnAOE

@export var damage: int = 10
@export var lifetime: float = 0.8
@export var knockback: Vector2 = Vector2(80.0, -120.0)
@export var animation_name: StringName = &"fire_column"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var owner_player: Node = null
var hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite != null:
		sprite.visible = true

		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
			sprite.frame = 0
			sprite.frame_progress = 0.0
			sprite.play(animation_name)

	await get_tree().physics_frame
	_hit_overlapping_targets()

	await get_tree().create_timer(lifetime).timeout

	if is_inside_tree():
		queue_free()


func setup(player: Node, facing_left: bool) -> void:
	owner_player = player

	if facing_left:
		knockback.x = -absf(knockback.x)
	else:
		knockback.x = absf(knockback.x)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	var damage_target := _get_damage_target(target)

	if damage_target == null:
		return

	if hit_targets.has(damage_target):
		return

	hit_targets[damage_target] = true

	var info := DamageInfo.new(damage, knockback, owner_player)

	if damage_target.has_method("apply_damage"):
		damage_target.apply_damage(info)


func _hit_overlapping_targets() -> void:
	for body in get_overlapping_bodies():
		_try_hit(body)

	for area in get_overlapping_areas():
		_try_hit(area)


func _get_damage_target(target: Node) -> Node:
	if target == null:
		return null

	if target == owner_player:
		return null

	if target.has_method("apply_damage"):
		return target

	if target.has_meta("owner_enemy"):
		return target.get_meta("owner_enemy")

	var parent := target.get_parent()

	while parent != null:
		if parent.has_method("apply_damage"):
			return parent

		parent = parent.get_parent()

	return null
