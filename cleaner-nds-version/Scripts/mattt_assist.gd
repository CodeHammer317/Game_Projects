extends Node2D
class_name MatttAssist

@export var fire_column_scene: PackedScene
@export var enemy_group: StringName = &"enemies"

@export var spawn_offset: Vector2 = Vector2(0.0, 0.0)
@export_range(0.0, 1.0, 0.01) var spawn_screen_height_ratio: float = 1.0 / 3.0
@export var hover_offset: Vector2 = Vector2(0.0, -100.0)
@export var fallback_strike_distance: float = 96.0
@export var hover_move_time: float = 0.5
@export var head_shake_time: float = 0.75
@export var fire_column_z_index: int = 20
@export var windup_scale: Vector2 = Vector2(0.42, 0.42)
@export var windup_flash_color: Color = Color(1.6, 1.3, 0.85, 1.0)
@export var impact_shake_strength: float = 12.0
@export var impact_shake_time: float = 0.18
@export var impact_hitstop_time: float = 0.04
@export var impact_hitstop_scale: float = 0.08

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fire_spawn_point: Marker2D = $FireSpawnPoint

var owner_player: Node2D = null
var facing_left: bool = false
var target_enemy: Node2D = null
var fire_target_position: Vector2 = Vector2.ZERO
var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_modulate: Color = Color.WHITE


func setup(player: Node2D, player_facing_left: bool) -> void:
	owner_player = player
	facing_left = player_facing_left
	_place_at_screen_height_ratio()

	if facing_left:
		sprite_flip(true)
	else:
		sprite_flip(false)


func _place_at_screen_height_ratio() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var screen_position := viewport.get_canvas_transform() * global_position
	screen_position.y = viewport.get_visible_rect().size.y * spawn_screen_height_ratio
	global_position = viewport.get_canvas_transform().affine_inverse() * screen_position


func _ready() -> void:
	if sprite != null:
		_base_sprite_scale = sprite.scale
		_base_sprite_modulate = sprite.modulate

	await get_tree().process_frame
	# Reapply once the active camera has updated so the summon point is truly
	# one-third down the visible screen, regardless of the player's world Y.
	_place_at_screen_height_ratio()

	target_enemy = _find_closest_enemy()

	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("appear"):
			sprite.frame = 0
			sprite.play("appear")
			await sprite.animation_finished

	if target_enemy != null:
		fire_target_position = target_enemy.global_position + spawn_offset
		await _hover_to_enemy()
	else:
		fire_target_position = _get_fallback_strike_position()
		await _hover_to_position(fire_target_position + hover_offset)

	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("head_shake"):
			sprite.frame = 0
			sprite.play("head_shake")

	_pulse_windup()
	await get_tree().create_timer(head_shake_time).timeout

	_update_fire_target_position()
	_spawn_fire_column()
	_play_impact_feedback()

	if sprite != null:
		sprite.scale = _base_sprite_scale
		sprite.modulate = _base_sprite_modulate

		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("disappear"):
			sprite.frame = 0
			sprite.play("disappear")
			await sprite.animation_finished

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

	await _hover_to_position(target_enemy.global_position + hover_offset)


func _hover_to_position(target_pos: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, hover_move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _get_fallback_strike_position() -> Vector2:
	if owner_player == null:
		return global_position

	var facing_sign := -1.0 if facing_left else 1.0
	return owner_player.global_position + Vector2(fallback_strike_distance * facing_sign, 0.0) + spawn_offset


func _update_fire_target_position() -> void:
	if target_enemy != null and is_instance_valid(target_enemy):
		global_position = target_enemy.global_position + hover_offset
		fire_target_position = _get_fire_spawn_position()
		return

	global_position = _get_fallback_strike_position() + hover_offset
	fire_target_position = _get_fire_spawn_position()


func _get_fire_spawn_position() -> Vector2:
	if fire_spawn_point != null:
		return fire_spawn_point.global_position + spawn_offset

	return fire_target_position + spawn_offset


func _pulse_windup() -> void:
	if sprite == null:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", windup_scale, head_shake_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate", windup_flash_color, head_shake_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "scale", _base_sprite_scale, head_shake_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate", _base_sprite_modulate, head_shake_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _spawn_fire_column() -> void:
	if fire_column_scene == null:
		push_warning("MatttAssist: fire_column_scene is not assigned.")
		return

	var fire := fire_column_scene.instantiate() as Node2D
	if fire == null:
		return

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()

	if parent == null:
		push_warning("MatttAssist: Could not find a parent for the fire column.")
		return

	parent.add_child(fire)
	fire.global_position = fire_target_position
	fire.z_index = fire_column_z_index

	if fire.has_method("setup"):
		fire.setup(owner_player, facing_left)


func _play_impact_feedback() -> void:
	CombatFx.shake(impact_shake_strength, impact_shake_time, 24.0)

	if impact_hitstop_time > 0.0:
		CombatFx.hitstop(impact_hitstop_time, impact_hitstop_scale)


func sprite_flip(value: bool) -> void:
	if sprite == null:
		return

	sprite.flip_h = value
