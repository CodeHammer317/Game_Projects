extends Node2D

@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.75
@export var player_scene: PackedScene
@export var player_scale: Vector2 = Vector2(2.0, 2.0)
@export var interaction_distance: float = 72.0
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/upgrade_chamber.tscn"

@onready var briefing: Control = $Level01BriefingScreen
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: SimpleCamera = $Camera2D
@onready var exit_area: Area2D = $StudyExit
@onready var exit_prompt: Label = $ExitPrompt
@onready var teammate_interaction: Node2D = $AnimatedSprite2D3
@onready var coffee_interaction: Node2D = $CoffeeCupBeige
@onready var interaction_layer: CanvasLayer = $InteractionLayer
@onready var interaction_prompt: Label = $InteractionLayer/Prompt
@onready var interaction_message: Label = $InteractionLayer/Message
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var transition_overlay: ColorRect = $TransitionLayer/Overlay

var player: Node2D = null
var _is_leaving: bool = false
var _active_interaction: StringName = &""
var _message_token: int = 0


func _ready() -> void:
	if briefing.has_signal("briefing_finished"):
		briefing.connect("briefing_finished", _on_briefing_finished)
	exit_area.body_entered.connect(_on_exit_body_entered)
	exit_prompt.visible = false
	interaction_layer.visible = false

	transition_layer.visible = true
	transition_overlay.modulate.a = 1.0

	var fade_tween := create_tween()
	fade_tween.tween_property(
		transition_overlay,
		"modulate:a",
		0.0,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_tween.finished

	transition_overlay.visible = false
	transition_layer.visible = false


func _process(_delta: float) -> void:
	_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or _is_leaving or _active_interaction.is_empty():
		return

	if event.is_action_pressed("attack"):
		_show_interaction_message(_active_interaction)
		get_viewport().set_input_as_handled()


func _on_briefing_finished() -> void:
	await get_tree().process_frame
	_spawn_player()
	exit_prompt.visible = true
	interaction_layer.visible = true


func _spawn_player() -> void:
	if player != null and is_instance_valid(player):
		return

	if player_scene == null:
		push_warning("Study: player_scene is not assigned.")
		return

	player = player_scene.instantiate() as Node2D
	if player == null:
		push_warning("Study: failed to instantiate player_scene.")
		return

	add_child(player)
	player.scale = player_scale
	player.global_position = player_spawn.global_position
	if player.has_method("set_combat_enabled"):
		player.call("set_combat_enabled", false)
	camera.target = player


func _update_interaction_prompt() -> void:
	if player == null or not is_instance_valid(player) or _is_leaving:
		interaction_prompt.visible = false
		_active_interaction = &""
		return

	var teammate_distance := player.global_position.distance_to(teammate_interaction.global_position)
	var coffee_distance := player.global_position.distance_to(coffee_interaction.global_position)

	if teammate_distance <= interaction_distance and teammate_distance <= coffee_distance:
		_active_interaction = &"teammate"
	elif coffee_distance <= interaction_distance:
		_active_interaction = &"coffee"
	else:
		_active_interaction = &""

	interaction_prompt.visible = not _active_interaction.is_empty()


func _show_interaction_message(interaction: StringName) -> void:
	match interaction:
		&"teammate":
			interaction_message.text = "TOP LOBSTA: First deployment? Try not to make the paperwork interesting."
		&"coffee":
			interaction_message.text = "The coffee has gone cold. The tremors have not."
		_:
			return

	_message_token += 1
	var token := _message_token
	interaction_message.visible = true
	_hide_interaction_message_after_delay(token)


func _hide_interaction_message_after_delay(token: int) -> void:
	await get_tree().create_timer(3.0).timeout
	if token == _message_token:
		interaction_message.visible = false


func _on_exit_body_entered(body: Node) -> void:
	if _is_leaving or body != player:
		return

	if next_scene.is_empty():
		push_warning("Study: next_scene is not assigned.")
		return

	_is_leaving = true
	if player.has_method("set_control_locked"):
		player.call("set_control_locked", true)

	transition_layer.visible = true
	transition_overlay.visible = true
	transition_overlay.modulate.a = 0.0

	var fade_tween := create_tween()
	fade_tween.tween_property(
		transition_overlay,
		"modulate:a",
		1.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_tween.finished

	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("Study: failed to open next scene. Error: %s" % error)
		_is_leaving = false
		transition_layer.visible = false
