extends Node2D

const SERVANT_LINE: String = "Should we neutralize\nthe Death Squad,\nMy Lord?"
const CATLORD_LINE: String = "Perhaps,,,,,,,,,,"

@export var chars_per_second: float = 25.0
@export var line_hold_duration: float = 2.0
@export var final_hold_duration: float = 3.0
@export var fade_in_duration: float = 1.0
@export var fade_out_duration: float = 1.25
@export_file("*.tscn") var next_scene: String = "res://Scenes/HUD/title_screen.tscn"

@onready var servant_bubble: Control = $DialogueLayer/DialogueRoot/ServantBubble
@onready var servant_text: RichTextLabel = $DialogueLayer/DialogueRoot/ServantBubble/Margin/Content/Text
@onready var catlord_tail_outer: Polygon2D = $DialogueLayer/DialogueRoot/CatlordTailOuter
@onready var catlord_tail_inner: Polygon2D = $DialogueLayer/DialogueRoot/CatlordTailInner
@onready var catlord_bubble: Control = $DialogueLayer/DialogueRoot/CatlordBubble
@onready var catlord_text: RichTextLabel = $DialogueLayer/DialogueRoot/CatlordBubble/Margin/Content/Text
@onready var prompt: Label = $DialogueLayer/DialogueRoot/Prompt
@onready var typing_audio: AudioStreamPlayer = $TypingAudio
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay

var _is_typing: bool = false
var _is_finishing: bool = false
var _typing_tween: Tween = null
var _typing_token: int = 0


func _ready() -> void:
	catlord_bubble.visible = false
	catlord_tail_outer.visible = false
	catlord_tail_inner.visible = false
	prompt.visible = false
	fade_overlay.visible = true
	fade_overlay.modulate.a = 1.0

	var fade_in := create_tween()
	fade_in.tween_property(
		fade_overlay,
		"modulate:a",
		0.0,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	fade_overlay.visible = false

	await _start_line(servant_text, SERVANT_LINE)
	await get_tree().create_timer(line_hold_duration).timeout

	catlord_bubble.visible = true
	catlord_tail_outer.visible = true
	catlord_tail_inner.visible = true
	await _start_line(catlord_text, CATLORD_LINE)
	await get_tree().create_timer(final_hold_duration).timeout

	await _finish_epilog()


func _start_line(label: RichTextLabel, dialogue: String) -> void:
	_typing_token += 1
	var token := _typing_token
	label.text = dialogue
	label.visible_characters = 0
	_is_typing = true

	var duration := dialogue.length() / maxf(chars_per_second, 1.0)
	_typing_tween = create_tween()
	_typing_tween.tween_property(label, "visible_characters", dialogue.length(), duration)
	_play_typing_sounds(label, token)
	await _typing_tween.finished
	_is_typing = false
	_typing_tween = null
	_typing_token += 1


func _play_typing_sounds(label: RichTextLabel, token: int) -> void:
	while _is_typing and token == _typing_token:
		var character_index := label.visible_characters
		if character_index >= 0 and character_index < label.text.length():
			var character := label.text[character_index]
			if character != " " and character != "\n":
				typing_audio.pitch_scale = randf_range(0.9, 1.1)
				typing_audio.play()
		await get_tree().create_timer(1.0 / maxf(chars_per_second, 1.0)).timeout


func _finish_epilog() -> void:
	_is_finishing = true
	prompt.visible = false
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0

	var fade_out := create_tween()
	fade_out.tween_property(
		fade_overlay,
		"modulate:a",
		1.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished

	PlayerState.finish_demo_finale()
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("Epilog: failed to open next scene. Error: %s" % error)
		_is_finishing = false
		fade_overlay.visible = false
