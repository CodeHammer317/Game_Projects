extends Node2D

const DEBRIEF_TEXT: String = """NDS // AFTER-ACTION DEBRIEF

LOCAL ANCHOR: DESTROYED
GLITCH DEMON: NEUTRALIZED
ARCHIVIST FILES: RECOVERED

The Old District signal is dark.
The other anchors are not.

Azazel has a name.
The NDS has a war."""

const NANCY_FINAL_LINE: String = """NANCY:MUSTANG//

Did you remember to pickup my catfood?"""

@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 0.75
@export var player_scene: PackedScene
@export var player_scale: Vector2 = Vector2(2.0, 2.0)
@export var interaction_distance: float = 72.0
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/upgrade_chamber.tscn"
@export var end_card_duration: float = 3.0
@export var finale_fade_duration: float = 1.5
@export var credits_scroll_duration: float = 34.0
@export_file("*.tscn") var epilog_scene: String = "res://Scenes/World/epilog.tscn"

@onready var briefing: BriefingScreen = $Level01BriefingScreen
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
@onready var finale_layer: CanvasLayer = $FinaleLayer
@onready var finale_backdrop: ColorRect = $FinaleLayer/FinaleRoot/Backdrop
@onready var end_label: Label = $FinaleLayer/FinaleRoot/EndLabel
@onready var credits_text: Label = $FinaleLayer/FinaleRoot/CreditsClip/CreditsText
@onready var finale_music: AudioStreamPlayer = $FinaleMusic

var player: Node2D = null
var _is_leaving: bool = false
var _active_interaction: StringName = &""
var _message_token: int = 0
var _is_demo_finale: bool = false


func _ready() -> void:
	_is_demo_finale = PlayerState.demo_finale_pending
	finale_layer.visible = false

	if _is_demo_finale:
		briefing.cancel_auto_start()
		_spawn_player()
		if player != null and player.has_method("set_control_locked"):
			player.call("set_control_locked", true)
		exit_area.set_deferred("monitoring", false)
	else:
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

	if _is_demo_finale:
		await _play_demo_finale()


func _process(_delta: float) -> void:
	_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _is_demo_finale or player == null or _is_leaving or _active_interaction.is_empty():
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
	if _is_demo_finale or player == null or not is_instance_valid(player) or _is_leaving:
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


func _play_demo_finale() -> void:
	briefing.start_dialogue(DEBRIEF_TEXT)
	await briefing.briefing_finished

	briefing.start_dialogue(NANCY_FINAL_LINE, false)
	await briefing.dialogue_revealed
	await get_tree().create_timer(2.5).timeout
	briefing.dismiss_dialogue()

	finale_layer.visible = true
	finale_backdrop.modulate.a = 0.0
	end_label.visible = false
	end_label.modulate.a = 0.0
	credits_text.visible = false

	var fade_to_black := create_tween()
	fade_to_black.tween_property(
		finale_backdrop,
		"modulate:a",
		1.0,
		finale_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_to_black.finished
	briefing.hide()

	end_label.visible = true
	var end_fade_in := create_tween()
	end_fade_in.tween_property(end_label, "modulate:a", 1.0, 0.75)
	await end_fade_in.finished
	await get_tree().create_timer(end_card_duration).timeout

	var end_fade_out := create_tween()
	end_fade_out.tween_property(end_label, "modulate:a", 0.0, 0.75)
	await end_fade_out.finished
	end_label.visible = false

	credits_text.visible = true
	credits_text.position.y = 360.0
	finale_music.play()
	await get_tree().process_frame

	var credits_tween := create_tween()
	credits_tween.tween_property(
		credits_text,
		"position:y",
		-credits_text.size.y,
		credits_scroll_duration
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await credits_tween.finished
	finale_music.stop()
	await get_tree().create_timer(2.0).timeout

	var error := get_tree().change_scene_to_file(epilog_scene)
	if error != OK:
		push_error("Study: failed to open epilog after credits. Error: %s" % error)
		PlayerState.finish_demo_finale()
		get_tree().change_scene_to_file("res://Scenes/HUD/title_screen.tscn")
