#Control.gd
extends Control
class_name BriefingScreen

signal briefing_finished
signal dialogue_revealed

@export var chars_per_second: float = 25.0
@export var random_pitch_range: float = 0.1
@export var next_scene: String = "res://Scenes/HUD/title_screen.tscn"
@export var dialogue_start_delay: float = 0.0
@export var change_scene_when_finished: bool = true
@export var reveal_prompt_text: String = "Press A or Space to reveal"
@export var continue_prompt_text: String = "Press A or Space to play"
@export_node_path("AnimatedSprite2D") var speaker_sprite_path: NodePath
@export_range(0.01, 1.0, 0.01) var speech_frame_time_min: float = 0.08
@export_range(0.01, 1.0, 0.01) var speech_frame_time_max: float = 0.18

@onready var label = $TextLabel
@onready var audio = $AudioStreamPlayer
@onready var skip_label = $SkipLabel
@onready var speaker_sprite: AnimatedSprite2D = get_node_or_null(speaker_sprite_path) as AnimatedSprite2D

var is_typing: bool = false
var _speech_animation_token: int = 0
var _skipped: bool = false
var _dialogue_started: bool = false
var _typing_tween: Tween = null
var _auto_start_cancelled: bool = false
var _input_enabled: bool = true


func _ready():
	skip_label.visible = false
	audio.max_polyphony = 4

	if dialogue_start_delay > 0.0:
		await get_tree().create_timer(dialogue_start_delay).timeout
	if _auto_start_cancelled:
		return

	start_dialogue("NDS // Secure Channel 7
Clearance: Field Operative

Agent,

Your investigation at the Christian Library triggered multiple alerts across our network.
The symbols you uncovered match pre-Flood inscriptions found at three recent incident sites.

At 0430 hours, a civilian reported tremors beneath the Old District.
Local authorities dismissed it as construction noise.

Our sensors say otherwise.

A Nephilim signature — faint, but rising — is pulsing beneath the abandoned subway line
near the Standard Coffee Shop.

Your objectives are as follows:

1. Enter the Old District undetected.
2. Locate the source of the seismic activity.
3. Recover any relics, documents, or biological traces.
4. Neutralize hostile entities if encountered.
5. Extract before the area is quarantined by government forces.

Expect resistance.
Expect misinformation.
Expect the truth to fight back.

This is your first field deployment, Agent…
but you've seen more than most recruits ever will.

Trust your instincts.
Trust the signs.

And remember:

If the Nephilim are waking,
we are already behind.
")


func _process(_delta: float) -> void:
	if _skipped:
		return


func _input(event: InputEvent) -> void:
	if not _dialogue_started or not _input_enabled:
		return

	if event.is_action_pressed("skip") or event.is_action_pressed("accept"):
		if is_typing:
			_complete_typing()
			get_viewport().set_input_as_handled()
			return

		_skipped = true
		_go_to_next_scene()
		get_viewport().set_input_as_handled()


func _go_to_next_scene() -> void:
	is_typing = false
	_stop_speaker_animation()

	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null

	if not change_scene_when_finished:
		_dialogue_started = false
		hide()
		briefing_finished.emit()
		return

	get_tree().change_scene_to_file(next_scene)


func start_dialogue(new_text: String, allow_input: bool = true):
	_skipped = false
	_input_enabled = allow_input
	show()
	_dialogue_started = true
	label.text = new_text
	label.visible_characters = 0
	skip_label.visible = _input_enabled
	skip_label.text = reveal_prompt_text
	is_typing = true
	_start_speaker_animation()

	var duration = new_text.length() / chars_per_second
	_typing_tween = create_tween()
	_typing_tween.tween_property(label, "visible_characters", new_text.length(), duration)
	_typing_tween.finished.connect(_on_typing_finished)

	play_typing_sounds()


func cancel_auto_start() -> void:
	_auto_start_cancelled = true
	_dialogue_started = false
	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null
	_stop_speaker_animation()
	hide()


func dismiss_dialogue() -> void:
	if _dialogue_started:
		_go_to_next_scene()


func play_typing_sounds():
	if not is_typing:
		return

	var current_index = label.visible_characters
	if current_index < label.text.length():
		var current_char = label.text[current_index]

		if current_char != " " and current_char != "\n":
			audio.pitch_scale = randf_range(1.0 - random_pitch_range, 1.0 + random_pitch_range)
			audio.play()

		get_tree().create_timer(1.0 / chars_per_second).timeout.connect(play_typing_sounds)


func _on_typing_finished():
	is_typing = false
	_typing_tween = null
	_stop_speaker_animation()
	skip_label.visible = _input_enabled
	if _input_enabled:
		skip_label.text = continue_prompt_text
	dialogue_revealed.emit()


func _complete_typing() -> void:
	if _typing_tween:
		_typing_tween.kill()
		_typing_tween = null

	label.visible_characters = label.text.length()
	_on_typing_finished()


func _start_speaker_animation() -> void:
	if speaker_sprite == null:
		return

	_speech_animation_token += 1
	speaker_sprite.stop()
	speaker_sprite.frame = 0
	_animate_speaker(_speech_animation_token)


func _animate_speaker(token: int) -> void:
	var frame_count := speaker_sprite.sprite_frames.get_frame_count(speaker_sprite.animation)
	if frame_count <= 1:
		return

	while is_typing and token == _speech_animation_token:
		speaker_sprite.frame = (speaker_sprite.frame + 1) % frame_count
		var hold_time := randf_range(
			minf(speech_frame_time_min, speech_frame_time_max),
			maxf(speech_frame_time_min, speech_frame_time_max)
		)
		await get_tree().create_timer(hold_time).timeout


func _stop_speaker_animation() -> void:
	_speech_animation_token += 1
	if speaker_sprite == null:
		return

	speaker_sprite.stop()
	speaker_sprite.frame = 0
