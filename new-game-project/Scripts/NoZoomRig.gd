# res://CameraRig.gd
extends Node2D

# ==========================================================
# Player tracking
# ==========================================================
@export var use_player_manager: bool = true
@export var player_group: StringName = &"players"

# Optional manual fallback if you want to assign players directly
@export var player_1_path: NodePath
@export var player_2_path: NodePath

# ==========================================================
# Follow
# ==========================================================
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 8.0

# ==========================================================
# Look ahead
# ==========================================================
@export var lookahead_enabled: bool = true
@export var lookahead_distance: float = 48.0
@export var lookahead_smoothing_speed: float = 6.0
@export var minimum_velocity_for_lookahead: float = 5.0

# ==========================================================
# Optional vertical soft lock
# ==========================================================
@export var lock_vertical_if_close: bool = true
@export var vertical_lock_threshold: float = 32.0
@export var vertical_lock_blend: float = 0.10

# ==========================================================
# References
# ==========================================================
@onready var cam: Camera2D = $Camera2D

# ==========================================================
# Internal
# ==========================================================
var _lookahead_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	cam.enabled = true

func _process(delta: float) -> void:
	var players := _get_players()
	if players.is_empty():
		return

	var center := _compute_players_center(players)

	if lock_vertical_if_close and players.size() == 2:
		var p1: Node2D = players[0]
		var p2: Node2D = players[1]
		var vertical_dist = abs(p1.global_position.y - p2.global_position.y)
		if vertical_dist < vertical_lock_threshold:
			center.y = lerp(cam.global_position.y, center.y, vertical_lock_blend)

	_lookahead_offset = _compute_lookahead(players, delta)
	var target_pos := center + _lookahead_offset

	if position_smoothing_enabled:
		cam.global_position = cam.global_position.lerp(
			target_pos,
			_exp_smooth_factor(position_smoothing_speed, delta)
		)
	else:
		cam.global_position = target_pos

func _get_players() -> Array[Node2D]:
	var result: Array[Node2D] = []

	if use_player_manager and has_node("/root/PlayerManager"):
		var pm = get_node("/root/PlayerManager")
		if "players" in pm:
			for p in pm.players:
				if is_instance_valid(p) and p is Node2D:
					result.append(p)
			if not result.is_empty():
				return result

	if player_1_path != NodePath():
		var p1 := get_node_or_null(player_1_path)
		if p1 is Node2D:
			result.append(p1)

	if player_2_path != NodePath():
		var p2 := get_node_or_null(player_2_path)
		if p2 is Node2D and p2 not in result:
			result.append(p2)

	if not result.is_empty():
		return result

	for node in get_tree().get_nodes_in_group(player_group):
		if node is Node2D:
			result.append(node)

	return result

func _compute_players_center(players: Array[Node2D]) -> Vector2:
	if players.size() == 1:
		return players[0].global_position

	var sum := Vector2.ZERO
	for p in players:
		sum += p.global_position

	return sum / float(players.size())

func _compute_lookahead(players: Array[Node2D], delta: float) -> Vector2:
	if not lookahead_enabled:
		return Vector2.ZERO

	var avg_velocity := Vector2.ZERO
	var valid_velocity_count := 0

	for p in players:
		if "velocity" in p:
			avg_velocity += p.velocity
			valid_velocity_count += 1

	if valid_velocity_count == 0:
		return _lookahead_offset.lerp(
			Vector2.ZERO,
			_exp_smooth_factor(lookahead_smoothing_speed, delta)
		)

	avg_velocity /= float(valid_velocity_count)

	if avg_velocity.length() < minimum_velocity_for_lookahead:
		return _lookahead_offset.lerp(
			Vector2.ZERO,
			_exp_smooth_factor(lookahead_smoothing_speed, delta)
		)

	var dir := avg_velocity.normalized()
	var target_offset := dir * lookahead_distance

	return _lookahead_offset.lerp(
		target_offset,
		_exp_smooth_factor(lookahead_smoothing_speed, delta)
	)

func _exp_smooth_factor(speed: float, delta: float) -> float:
	return clamp(1.0 - pow(0.001, delta * speed), 0.0, 1.0)
