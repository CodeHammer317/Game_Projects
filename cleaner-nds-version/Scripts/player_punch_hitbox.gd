extends Area2D
class_name PlayerPunchHitbox

@export var damage: int = 1
@export var lifetime: float = 0.10
@export var knockback: Vector2 = Vector2(90.0, -20.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var owner_player: Node = null
var hit_targets: Dictionary = {}
var attack_name: StringName = &""


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite != null:
		if sprite.sprite_frames != null:
			if sprite.sprite_frames.has_animation("claw"):
				sprite.play("claw")

	await get_tree().create_timer(lifetime).timeout

	if is_inside_tree():
		queue_free()


func setup(
	player: Node,
	facing_left: bool,
	new_attack_name: StringName = &""
) -> void:
	owner_player = player
	set_attack_name(new_attack_name)

	if facing_left:
		knockback.x = -absf(knockback.x)

		if sprite != null:
			sprite.flip_h = true
	else:
		knockback.x = absf(knockback.x)

		if sprite != null:
			sprite.flip_h = false


func set_attack_name(new_attack_name: StringName) -> void:
	attack_name = new_attack_name


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	var damage_target: Node = _get_damage_target(target)

	if damage_target == null:
		return

	if damage_target == owner_player:
		return

	if hit_targets.has(damage_target):
		return

	hit_targets[damage_target] = true

	var info := DamageInfo.new(damage, knockback, owner_player)

	if damage_target.has_method("apply_damage"):
		damage_target.apply_damage(info)
		return

	if damage_target.has_method("take_damage"):
		damage_target.take_damage(damage, owner_player)


func _get_damage_target(target: Node) -> Node:
	if target == null:
		return null

	if target == owner_player:
		return null

	if target.has_method("apply_damage"):
		return target

	if target.has_method("take_damage"):
		return target

	if target.has_meta("owner_enemy"):
		var owner_enemy: Node = target.get_meta("owner_enemy")

		if owner_enemy != null:
			return owner_enemy

	var parent := target.get_parent()

	while parent != null:
		if parent.has_method("apply_damage"):
			return parent

		if parent.has_method("take_damage"):
			return parent

		parent = parent.get_parent()

	return null
