extends Node2D
class_name UpgradeChamber

@export var upgrade_name: StringName = &"double_jump"
@export var move_player_to_stop: bool = true
@export var player_move_speed: float = 120.0
@export var max_move_to_stop_time: float = 3.0
@export var beam_animation: StringName = &"beam"
@export var machine_animation: StringName = &"activate"
@export var fallback_animation_time: float = 1.0
@export_range(1.0, 4.0, 0.05) var animation_duration_multiplier: float = 1.0
@export_range(1, 6, 1) var animation_repeat_count: int = 3
@export var player_scene: PackedScene
@export var player_scale: Vector2 = Vector2(1.5, 1.5)
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/Level_01_Old_District.tscn"
@export var fade_in_duration: float = 0.75
@export var fade_out_duration: float = 0.75

@onready var area: Area2D = $Area2D
@onready var stop_point: Node2D = $StopPoint
@onready var beam_sprite: AnimatedSprite2D = $Beam/AnimatedSprite2D
@onready var machine_sprite: AnimatedSprite2D = $UpgradeMachine/AnimatedSprite2D
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: SimpleCamera = $Camera2D
@onready var tutorial_ui: CanvasLayer = $TutorialUI
@onready var tutorial_prompt: Label = $TutorialUI/TutorialPrompt
@onready var exit_prompt: Label = $TutorialUI/ExitPrompt
@onready var exit_area: Area2D = $TutorialExit
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var transition_overlay: ColorRect = $TransitionLayer/Overlay

var is_active: bool = false
var has_been_used: bool = false
var player: Node2D = null
var _is_leaving: bool = false
var _beam_base_speed_scale: float = 1.0
var _machine_base_speed_scale: float = 1.0


func _ready() -> void:
	_beam_base_speed_scale = beam_sprite.speed_scale
	_machine_base_speed_scale = machine_sprite.speed_scale
	beam_sprite.stop()
	beam_sprite.set_frame_and_progress(0, 0.0)
	beam_sprite.visible = false
	machine_sprite.stop()
	machine_sprite.set_frame_and_progress(0, 0.0)
	has_been_used = PlayerState.has_upgrade(upgrade_name)
	tutorial_ui.visible = false
	tutorial_prompt.visible = false
	exit_prompt.visible = false
	exit_area.monitoring = false

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not exit_area.body_entered.is_connected(_on_exit_body_entered):
		exit_area.body_entered.connect(_on_exit_body_entered)

	if has_been_used:
		area.set_deferred("monitoring", false)

	_spawn_player()
	await _fade_in()

	if has_been_used:
		_enable_tutorial_exit()


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
	_enable_tutorial_exit()


func _spawn_player() -> void:
	if player_scene == null:
		push_warning("UpgradeChamber: player_scene is not assigned.")
		return

	player = player_scene.instantiate() as Node2D
	if player == null:
		push_warning("UpgradeChamber: failed to instantiate player_scene.")
		return

	add_child(player)
	player.scale = player_scale
	player.global_position = player_spawn.global_position
	camera.target = player


func _enable_tutorial_exit() -> void:
	tutorial_ui.visible = true
	tutorial_prompt.visible = true
	exit_prompt.visible = true
	exit_area.set_deferred("monitoring", true)


func _on_exit_body_entered(body: Node) -> void:
	if _is_leaving or body != player:
		return

	if next_scene.is_empty():
		push_warning("UpgradeChamber: next_scene is not assigned.")
		return

	_is_leaving = true
	exit_area.set_deferred("monitoring", false)

	if player.has_method("set_control_locked"):
		player.call("set_control_locked", true)

	await _fade_out()

	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("UpgradeChamber: failed to open next scene. Error: %s" % error)
		_is_leaving = false
		_enable_tutorial_exit()


func _fade_in() -> void:
	transition_layer.visible = true
	transition_overlay.visible = true
	transition_overlay.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(
		transition_overlay,
		"modulate:a",
		0.0,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	transition_layer.visible = false


func _fade_out() -> void:
	transition_layer.visible = true
	transition_overlay.visible = true
	transition_overlay.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(
		transition_overlay,
		"modulate:a",
		1.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


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
	var safe_duration_multiplier := maxf(animation_duration_multiplier, 1.0)
	machine_sprite.speed_scale = _machine_base_speed_scale / safe_duration_multiplier
	beam_sprite.speed_scale = _beam_base_speed_scale / safe_duration_multiplier

	beam_sprite.visible = true
	var repeat_count := maxi(animation_repeat_count, 1)

	for cycle in repeat_count:
		var machine_duration := fallback_animation_time * safe_duration_multiplier
		var beam_duration := fallback_animation_time * safe_duration_multiplier

		if machine_sprite.sprite_frames != null:
			if machine_sprite.sprite_frames.has_animation(machine_animation):
				machine_sprite.stop()
				machine_sprite.set_frame_and_progress(0, 0.0)
				machine_sprite.play(machine_animation)
				machine_duration = _get_animation_duration(machine_sprite, machine_animation)

		if beam_sprite.sprite_frames != null:
			if beam_sprite.sprite_frames.has_animation(beam_animation):
				beam_sprite.stop()
				beam_sprite.set_frame_and_progress(0, 0.0)
				beam_sprite.play(beam_animation)
				beam_duration = _get_animation_duration(beam_sprite, beam_animation)

		await get_tree().create_timer(maxf(machine_duration, beam_duration)).timeout

	machine_sprite.stop()
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
