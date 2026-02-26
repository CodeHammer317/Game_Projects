# Bullet.gd
extends Projectile
class_name Bullet

@export var direction_x: int = 1

func _ready() -> void:
	_velocity = Vector2(direction_x * speed, 0)
	super._ready()
