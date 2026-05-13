
extends Area2D
class_name DangerSign

@export var blink_count: int = 4
@export var blink_speed: float = 0.12
@export var play_once: bool = true
@export var destroy_after_finished: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var has_triggered: bool = false
var is_blinking: bool = false


func _ready() -> void:
	sprite.visible = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if play_once and has_triggered:
		return

	if not body.is_in_group("player"):
		return

	has_triggered = true
	start_warning()


func start_warning() -> void:
	if is_blinking:
		return

	is_blinking = true
	blink_sequence()


func blink_sequence() -> void:
	for i in blink_count:
		sprite.visible = true
		await get_tree().create_timer(blink_speed).timeout

		sprite.visible = false
		await get_tree().create_timer(blink_speed).timeout

	is_blinking = false

	if destroy_after_finished:
		queue_free()
	else:
		sprite.visible = false
