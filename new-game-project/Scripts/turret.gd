# Turret.gd (minimal, known-good)
extends Node2D

@export var detection_radius: float = 400.0
@export var fire_cooldown: float = 1.2
@export var missile_scene: PackedScene

@onready var _muzzle: Marker2D = $Barrel/Muzzle
@onready var _timer: Timer = $FireTimer

var _current_target: Node2D = null


func _ready() -> void:
	if _timer:
		_timer.one_shot = true


func _physics_process(_delta: float) -> void:
	_update_target()

	if _current_target == null:
		return

	if _timer.time_left <= 0.0:
		_fire()


# --------------------------------------------------
# Targeting
# --------------------------------------------------

func _update_target() -> void:
	var nearest: Node2D = null
	var nearest_d2 := INF

	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p):
			continue

		var d2 := global_position.distance_squared_to(p.global_position)

		if d2 <= detection_radius * detection_radius and d2 < nearest_d2:
			nearest_d2 = d2
			nearest = p

	_current_target = nearest


# --------------------------------------------------
# Fire
# --------------------------------------------------

func _fire() -> void:
	if missile_scene == null:
		push_error("Missile scene not assigned.")
		return

	var missile = missile_scene.instantiate()
	get_tree().current_scene.add_child(missile)

	missile.global_position = _muzzle.global_position

	# Pure horizontal direction
	var direction = sign(_current_target.global_position.x - global_position.x)
	if direction == 0:
		direction = 1

	var dir := Vector2(direction, 0)

	if "launch" in missile:
		missile.call("launch", dir, _current_target)

	_timer.start(fire_cooldown)
