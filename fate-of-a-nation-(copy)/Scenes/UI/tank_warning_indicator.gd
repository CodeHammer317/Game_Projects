extends Node2D
class_name TankWarningIndicator

signal finished

@export var animation_name: StringName = &"warning"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer


func _ready() -> void:
	if sprite != null:
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
			sprite.play(animation_name)

	if timer != null:
		timer.one_shot = true

		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)

		timer.start()


func _on_timer_timeout() -> void:
	finished.emit()
	queue_free()
