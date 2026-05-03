extends Camera2D
class_name CameraShake

@export var decay_speed: float = 18.0
@export var max_offset: float = 25.0

var trauma: float = 0.0
var base_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	base_offset = offset
	randomize()


func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma -= decay_speed * delta

		if trauma < 0.0:
			trauma = 0.0

		var amount: float = trauma * trauma
		var shake_x: float = randf_range(-max_offset, max_offset) * amount
		var shake_y: float = randf_range(-max_offset, max_offset) * amount

		offset = base_offset + Vector2(shake_x, shake_y)
	else:
		offset = base_offset


func shake(strength: float = 0.35) -> void:
	trauma += strength

	if trauma > 1.0:
		trauma = 1.0
