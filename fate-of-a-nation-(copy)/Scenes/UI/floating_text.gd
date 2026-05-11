extends Node2D
class_name FloatingText

@export var float_distance: float = 24.0
@export var duration: float = 1.9
@export var random_x_range: float = 10.0

@onready var label: Label = $Label


func setup(text: String, text_color: Color = Color.WHITE) -> void:
	if label == null:
		return

	label.text = text
	label.modulate = text_color


func _ready() -> void:
	position.x += randf_range(-random_x_range, random_x_range)

	var start_position: Vector2 = position
	var end_position: Vector2 = position + Vector2(0.0, -float_distance)

	var tween: Tween = create_tween()
	tween.tween_property(self, "position", end_position, duration)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free)
