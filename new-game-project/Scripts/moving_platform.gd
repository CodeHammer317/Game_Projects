extends Node2D

@export var point_a: Vector2 = Vector2.ZERO
@export var point_b: Vector2 = Vector2(200, 0)
@export var speed: float = 60.0

var _target: Vector2
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	global_position = point_a
	_target = point_b


func _physics_process(delta: float) -> void:
	var dir := (_target - global_position).normalized()
	velocity = dir * speed
	global_position += velocity * delta

	# Switch direction when close enough
	if global_position.distance_to(_target) < 2.0:
		_target = point_a if _target == point_b else point_b
