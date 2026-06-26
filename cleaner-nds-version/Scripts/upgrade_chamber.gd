extends Node2D
class_name UpgradeChamber

@export var upgrade_name: StringName = &"double_jump"
@export var move_player_to_stop: bool = true
@export var player_move_speed: float = 120.0
@export var max_move_to_stop_time: float = 3.0
@export var beam_animation: StringName = &"beam"
@export var machine_animation: StringName = &"activate"
@export var fallback_animation_time: float = 1.0

@onready var area: Area2D = $Area2D
@onready var stop_point: Node2D = $StopPoint
@onready var beam_sprite: AnimatedSprite2D = $Beam/AnimatedSprite2D
@onready var machine_sprite: AnimatedSprite2D = $UpgradeMachine/AnimatedSprite2D

var is_active: bool = false
var has_been_used: bool = false


func _ready() -> void:
	beam_sprite.stop()
	beam_sprite.set_frame_and_progress(0, 0.0)
	beam_sprite.visible = false
	has_been_used = PlayerState.has_upgrade(upgrade_name)

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)

	if has_been_used:
		area.set_deferred("monitoring", false)


func _on_body_entered(body: Node) -> void:
	if has_been_used:
		return

	if is_active:
		return

	if not body.is_in_group("player"):
		return

	start_upgrade_sequence(body)


func start_upgrade_sequence(player: Node) -> void:
	if not is_node_ready():
		await ready

	if PlayerState.has_upgrade(upgrade_name):
		has_been_used = true
		if area != null:
			area.set_deferred("monitoring", false)
		return

	is_active = true
	has_been_used = true

	if player.has_method("set_control_locked"):
		player.set_control_locked(true)

	if move_player_to_stop:
		await _move_player_to_stop(player)

	if player.has_method("play_idle_animation"):
		player.play_idle_animation()

	await _play_upgrade_animation()

	if player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_name)

	if player.has_method("set_control_locked"):
		player.set_control_locked(false)

	if area != null:
		area.set_deferred("monitoring", false)
	is_active = false


func _move_player_to_stop(player: Node) -> void:
	if not player is Node2D:
		return

	if stop_point == null:
		return

	var player_2d: Node2D = player
	var move_timer: float = 0.0

	while is_instance_valid(player_2d) and player_2d.global_position.distance_to(stop_point.global_position) > 2.0:
		if move_timer >= max_move_to_stop_time:
			break

		var direction: Vector2 = player_2d.global_position.direction_to(stop_point.global_position)
		var delta := get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0

		move_timer += delta
		player_2d.global_position += direction * player_move_speed * delta
		await get_tree().process_frame

	if is_instance_valid(player_2d):
		player_2d.global_position = stop_point.global_position


func _play_upgrade_animation() -> void:
	if machine_sprite != null and machine_sprite.sprite_frames != null:
		if machine_sprite.sprite_frames.has_animation(machine_animation):
			machine_sprite.stop()
			machine_sprite.set_frame_and_progress(0, 0.0)
			machine_sprite.play(machine_animation)

	if beam_sprite == null:
		return

	beam_sprite.visible = true

	if beam_sprite.sprite_frames != null:
		if beam_sprite.sprite_frames.has_animation(beam_animation):
			beam_sprite.stop()
			beam_sprite.set_frame_and_progress(0, 0.0)
			beam_sprite.play(beam_animation)
			await get_tree().create_timer(_get_animation_duration(beam_sprite, beam_animation)).timeout

	beam_sprite.stop()
	beam_sprite.visible = false


func _get_animation_duration(sprite: AnimatedSprite2D, animation_name: StringName) -> float:
	if sprite.sprite_frames == null:
		return fallback_animation_time

	if not sprite.sprite_frames.has_animation(animation_name):
		return fallback_animation_time

	var speed := sprite.sprite_frames.get_animation_speed(animation_name) * absf(sprite.speed_scale)
	if speed <= 0.0:
		return fallback_animation_time

	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var total_duration: float = 0.0

	for frame_index in frame_count:
		total_duration += sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / speed

	return maxf(total_duration, 0.05)
