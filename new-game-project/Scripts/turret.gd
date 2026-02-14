# Turret.gd (minimal, known-good)
extends Node2D

@export var detection_radius: float = 100.0
@export var rotate_speed_deg: float = 0.0
@export var fire_cooldown: float = 1.20
@export var lead_target: bool = false
@export var missile_scene: PackedScene

@onready var _barrel: Node2D = $Barrel
@onready var _muzzle: Marker2D = $Barrel/Muzzle
@onready var _timer: Timer = $FireTimer

var _current_target: Node2D

func _ready() -> void:
	if _timer != null:
		_timer.one_shot = true

func _physics_process(delta: float) -> void:
	_update_target()
	if _current_target == null:
		# print("TURRET: No target in range.")
		return

	var to_target := _current_target.global_position - _barrel.global_position
	if to_target == Vector2.ZERO:
		return

	var desired_angle := to_target.angle()
	var current_angle := _barrel.global_rotation
	var max_step := deg_to_rad(rotate_speed_deg) * delta
	_barrel.global_rotation = _rotate_toward(current_angle, desired_angle, max_step)

	if _timer.time_left <= 0.0:
		_fire()

func _update_target() -> void:
	var candidates := _get_player_candidates()
	if candidates.size() == 0:
		_current_target = null
		return

	var nearest = null
	var nearest_d2 := INF
	for i in candidates.size():
		var p = candidates[i]
		if p == null:
			continue
		if not is_instance_valid(p):
			continue
		var d2 := global_position.distance_squared_to(p.global_position)
		if d2 < nearest_d2:
			nearest_d2 = d2
			nearest = p
	_current_target = nearest

func _get_player_candidates() -> Array:
	var list: Array = []

	# Try GameManager first
	if has_node("/root/GameManager"):
		var gm := get_node("/root/GameManager")
		if "player" in gm:
			for p in gm.player:
				list.append(p)

	# Fallback: group "players"
	if list.size() == 0:
		var by_group := get_tree().get_nodes_in_group("player")
		for p in by_group:
			list.append(p)

	# Cull by distance
	var culled: Array = []
	for i in list.size():
		var n = list[i]
		if n == null:
			continue
		if not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d <= detection_radius:
			culled.append(n)
	return culled

func _fire() -> void:
	if missile_scene == null:
		push_error("TURRET: missile_scene not assigned!")
		return

	var missile := missile_scene.instantiate() as Area2D
	if missile == null:
		return

	get_tree().current_scene.add_child(missile)
	missile.global_position = _muzzle.global_position

	var dir := (_current_target.global_position - _muzzle.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	if lead_target:
		if "velocity" in _current_target:
			var vel = _current_target.velocity
			if vel.length() > 0.0:
				dir = (dir + vel.normalized() * 0.35).normalized()

	if "launch" in missile:
		missile.call("launch", dir, _current_target)

	_timer.start(fire_cooldown)

func _rotate_toward(current_angle: float, target_angle: float, max_step: float) -> float:
	var diff := wrapf(target_angle - current_angle, -PI, PI)
	if diff > max_step:
		diff = max_step
	else:
		if diff < -max_step:
			diff = -max_step
	return current_angle + diff
