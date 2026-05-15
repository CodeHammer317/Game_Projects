extends Node2D
class_name MatttAssist

@export var fire_column_scene: PackedScene
@export var enemy_group: StringName = &"enemies"

@export var spawn_offset: Vector2 = Vector2(-40.0, -20.0)
@export var hover_offset: Vector2 = Vector2(0.0, -100.0)
@export var hover_move_time: float = 0.35
@export var head_shake_time: float = 0.75

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var owner_player: Node2D = null
var facing_left: bool = false
var target_enemy: Node2D = null


func setup(player: Node2D, player_facing_left: bool) -> void:
	owner_player = player
	facing_left = player_facing_left

	if facing_left:
		sprite_flip(true)
	else:
		sprite_flip(false)


func _ready() -> void:
	await get_tree().process_frame

	target_enemy = _find_closest_enemy()

	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("appear"):
			sprite.play("appear")

	if target_enemy != null:
		await _hover_to_enemy()
	else:
		push_warning("MatttAssist: No enemy found in group '%s'." % enemy_group)

	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("head_shake"):
			sprite.play("head_shake")

	await get_tree().create_timer(head_shake_time).timeout

	if target_enemy != null and is_instance_valid(target_enemy):
		_spawn_fire_column()

	queue_free()


func _find_closest_enemy() -> Node2D:
	if owner_player == null:
		push_warning("MatttAssist: owner_player is null.")
		return null

	var enemies := get_tree().get_nodes_in_group(enemy_group)

	if enemies.is_empty():
		return null

	var closest: Node2D = null
	var closest_dist: float = INF

	for enemy in enemies:
		if enemy is Node2D:
			var enemy_node := enemy as Node2D

			if "is_dead" in enemy_node:
				if enemy_node.is_dead:
					continue

			var dist := owner_player.global_position.distance_to(enemy_node.global_position)

			if dist < closest_dist:
				closest_dist = dist
				closest = enemy_node

	return closest


func _hover_to_enemy() -> void:
	if target_enemy == null:
		return

	if not is_instance_valid(target_enemy):
		return

	var target_pos := target_enemy.global_position + hover_offset

	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, hover_move_time)
	await tween.finished


func _spawn_fire_column() -> void:
	if fire_column_scene == null:
		push_warning("MatttAssist: fire_column_scene is not assigned.")
		return

	var fire := fire_column_scene.instantiate() as Node2D
	if fire == null:
		return

	get_tree().current_scene.add_child(fire)
	fire.global_position = target_enemy.global_position

	if fire.has_method("setup"):
		fire.setup(owner_player, facing_left)


func sprite_flip(value: bool) -> void:
	if sprite == null:
		return

	sprite.flip_h = value
