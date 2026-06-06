extends Node2D
class_name UpgradeChamber

@export var upgrade_name: StringName = &"double_jump"
@export var move_player_to_stop: bool = true
@export var player_move_speed: float = 120.0
@export var beam_animation: StringName = &"beam"
@export var machine_animation: StringName = &"activate"

@onready var area: Area2D = $Area2D
@onready var stop_point: Node2D = $StopPoint
@onready var beam_sprite: AnimatedSprite2D = $Beam/AnimatedSprite2D
@onready var machine_sprite: AnimatedSprite2D = $UpgradeMachine/AnimatedSprite2D

var is_active: bool = false
var has_been_used: bool = false


func _ready() -> void:
	beam_sprite.visible = false

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if has_been_used:
		return

	if is_active:
		return

	if not body.is_in_group("player"):
		return

	start_upgrade_sequence(body)


func start_upgrade_sequence(player: Node) -> void:
	is_active = true
	has_been_used = true

	if player.has_method("set_control_locked"):
		player.set_control_locked(true)

	if move_player_to_stop:
		await _move_player_to_stop(player)

	await _play_upgrade_animation()

	if player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_name)

	if player.has_method("set_control_locked"):
		player.set_control_locked(false)

	is_active = false


func _move_player_to_stop(player: Node) -> void:
	if not player is Node2D:
		return

	var player_2d: Node2D = player

	while player_2d.global_position.distance_to(stop_point.global_position) > 2.0:
		var direction: Vector2 = player_2d.global_position.direction_to(stop_point.global_position)
		player_2d.global_position += direction * player_move_speed * get_process_delta_time()
		await get_tree().process_frame

	player_2d.global_position = stop_point.global_position


func _play_upgrade_animation() -> void:
	if machine_sprite.sprite_frames != null:
		if machine_sprite.sprite_frames.has_animation(machine_animation):
			machine_sprite.play(machine_animation)

	beam_sprite.visible = true

	if beam_sprite.sprite_frames != null:
		if beam_sprite.sprite_frames.has_animation(beam_animation):
			beam_sprite.play(beam_animation)
			await beam_sprite.animation_finished

	beam_sprite.visible = false
