extends Node2D
class_name Turret

@export var detection_radius: float = 400.0
@export var fire_cooldown: float = 1.2
@export var missile_scene: PackedScene
@export var horizontal_only: bool = true
@export var target_group: StringName = &"player"
@export var team: int = 2

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


func _update_target() -> void:
	var nearest: Node2D = null
	var nearest_d2 := INF
	var radius_sq := detection_radius * detection_radius

	for p in get_tree().get_nodes_in_group(target_group):
		if not (p is Node2D) or not is_instance_valid(p):
			continue

		var candidate := p as Node2D
		var d2 := global_position.distance_squared_to(candidate.global_position)
		if d2 <= radius_sq and d2 < nearest_d2:
			nearest_d2 = d2
			nearest = candidate

	_current_target = nearest


func _fire() -> void:
	if missile_scene == null or _current_target == null:
		return

	var missile = missile_scene.instantiate()
	if missile == null:
		return

	get_parent().add_child(missile)

	if missile is Node2D:
		missile.global_position = _muzzle.global_position

	var dir: Vector2
	if horizontal_only:
		var direction = sign(_current_target.global_position.x - global_position.x)
		if direction == 0:
			direction = 1
		dir = Vector2(direction, 0)
	else:
		dir = (_current_target.global_position - _muzzle.global_position).normalized()

	if missile is Projectile:
		missile.team = team
		missile.launch(dir, _current_target, self)
	elif missile is EnemyMissile:
		missile.team = team
		missile.launch(dir, _current_target, self)
	elif missile.has_method("launch"):
		missile.launch(dir, _current_target)

	_timer.start(fire_cooldown)
