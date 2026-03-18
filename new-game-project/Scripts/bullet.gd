# Bullet.gd
extends Projectile
class_name Bullet

@onready var sprite: Sprite2D = $Sprite2D
@export var direction_x: int = 1

func _ready() -> void:
	direction_x = -1 if direction_x < 0 else 1
	_velocity = Vector2(direction_x * speed, 0)

	if direction_x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	super._ready()
