extends Node2D
class_name DustTrail

@export var random_y_offset: float = 2.0
@export var random_scale_amount: float = 0.15
@export var whoosh_cooldown: float = 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var whoosh_sound: AudioStreamPlayer2D = $WhooshSound

static var _last_whoosh_time_msec: int = -1000000


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

	if dust_animation == &"dash":
		_play_whoosh()


func _play_whoosh() -> void:
	if whoosh_sound == null or whoosh_sound.stream == null:
		return

	var now_msec := Time.get_ticks_msec()
	var cooldown_msec := roundi(maxf(whoosh_cooldown, 0.0) * 1000.0)
	if now_msec - _last_whoosh_time_msec < cooldown_msec:
		return

	_last_whoosh_time_msec = now_msec
	whoosh_sound.play()


func _on_animation_finished() -> void:
	queue_free()
