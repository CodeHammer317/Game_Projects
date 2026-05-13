extends Node2D
class_name DustTrail

@export var random_y_offset: float = 2.0
@export var random_scale_amount: float = 0.15

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if sprite == null:
		queue_free()
		return

	position.y += randf_range(-random_y_offset, random_y_offset)

	var scale_bonus: float = randf_range(-random_scale_amount, random_scale_amount)
	scale += Vector2(scale_bonus, scale_bonus)

	if not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	sprite.play()


func setup(facing_right: bool, dust_animation: StringName = &"dash") -> void:
	if sprite == null:
		return

	sprite.flip_h = not facing_right

	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(dust_animation):
			sprite.play(dust_animation)


func _on_animation_finished() -> void:
	queue_free()
