extends Node2D

const COMMENTS := [
	{
		"speaker": "TOP LOBSTA //",
		"text": "Coffee's cold, street's cursed. Standard deployment.",
	},
	{
		"speaker": "MATTTTT //",
		"text": "Free coffee and it's still hot? That's the real anomaly.",
	},
]

@export var comment_start_delay: float = 0.8
@export var comment_hold_duration: float = 4.0
@export var comment_fade_duration: float = 0.35
@export var exit_sign_reveal_distance: float = 150.0
@export var exit_sign_fade_duration: float = 0.18

@onready var comment_panel: Control = $CommentLayer/CommentPanel
@onready var speaker_label: Label = $CommentLayer/CommentPanel/Margin/Content/Speaker
@onready var comment_label: Label = $CommentLayer/CommentPanel/Margin/Content/Comment
@onready var player: Node2D = $CoffeeShopLayers/Player
@onready var exit_sign: Label = $ExitSign

var exit_sign_tween: Tween = null
var exit_sign_target_visible: bool = false


func _ready() -> void:
	comment_panel.visible = false
	comment_panel.modulate.a = 0.0
	exit_sign.visible = false
	exit_sign.modulate.a = 0.0

	if comment_start_delay > 0.0:
		await get_tree().create_timer(comment_start_delay).timeout

	for comment: Dictionary in COMMENTS:
		speaker_label.text = str(comment["speaker"])
		comment_label.text = str(comment["text"])
		await _show_comment()


func _process(_delta: float) -> void:
	var sign_center := exit_sign.global_position + exit_sign.size * 0.5
	var should_show := player.global_position.distance_to(sign_center) <= exit_sign_reveal_distance
	if should_show != exit_sign_target_visible:
		_set_exit_sign_visible(should_show)


func _set_exit_sign_visible(should_show: bool) -> void:
	exit_sign_target_visible = should_show
	if exit_sign_tween != null:
		exit_sign_tween.kill()

	if should_show:
		exit_sign.visible = true

	exit_sign_tween = create_tween()
	exit_sign_tween.tween_property(
		exit_sign,
		"modulate:a",
		1.0 if should_show else 0.0,
		exit_sign_fade_duration
	)

	if not should_show:
		exit_sign_tween.tween_callback(exit_sign.hide)


func _show_comment() -> void:
	comment_panel.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(
		comment_panel,
		"modulate:a",
		1.0,
		comment_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished

	await get_tree().create_timer(comment_hold_duration).timeout

	var fade_out := create_tween()
	fade_out.tween_property(
		comment_panel,
		"modulate:a",
		0.0,
		comment_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	comment_panel.visible = false
