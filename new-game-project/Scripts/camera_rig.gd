# res://CameraRig.gd
extends Node2D

# -------------------------
# Tilemap / Level bounds
# -------------------------
@export var tilemap_path: NodePath
@export var use_tilemap_bounds: bool = true
@export var manual_level_bounds: Rect2 = Rect2(0, 0, 4096, 2304)

# -------------------------
# Player tracking
# -------------------------
@export var soft_margin: Vector2 = Vector2(80, 64) # 5x4 tiles

# -------------------------
# Position smoothing
# -------------------------
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 8.0

# -------------------------
# Zoom
# -------------------------
@export var zoom_enabled: bool = true
@export var single_player_zoom: Vector2 = Vector2(1.2, 1.2) # single player

@export var zoom_in: Vector2 = Vector2(1.0, 1.0)   # players close
@export var zoom_out: Vector2 = Vector2(1.8, 1.8)  # players far apart
@export var separation_for_max_zoom: float = 320.0  # 20 tiles

@export var zoom_smoothing_enabled: bool = true
@export var zoom_smoothing_speed: float = 6.0

# -------------------------
# Vertical lock
# -------------------------
@export var lock_vertical_if_close: bool = true
@export var vertical_lock_threshold: float = 32.0 # 2 tiles

# -------------------------
# References
# -------------------------
@onready var cam: Camera2D = $Camera2D

# -------------------------
# Internal
# -------------------------
var _level_bounds: Rect2
var _target_pos: Vector2
var _target_zoom: Vector2

# ==========================================================
# READY
# ==========================================================
func _ready() -> void:
	_level_bounds = _compute_level_bounds()
	cam.enabled = true
	_target_pos = global_position
	_target_zoom = cam.zoom

	if has_node("/root/PlayerManager"):
		var pm = get_node("/root/PlayerManager")
		pm.connect("players_changed", Callable(self, "_on_players_changed"))

# ==========================================================
# MAIN LOOP
# ==========================================================
func _process(delta: float) -> void:
	var players := PlayerManager.players
	if players.is_empty():
		return

	var center := _compute_player_center(players)
	var target_zoom := _compute_target_zoom(players)
	center = _clamp_to_players(center, target_zoom)

	# Smooth position
	var new_pos := center
	if position_smoothing_enabled:
		new_pos = cam.global_position.lerp(center, _exp_smooth_factor(position_smoothing_speed, delta))

	# Smooth zoom
	var new_zoom := target_zoom
	if zoom_smoothing_enabled:
		new_zoom = cam.zoom.lerp(target_zoom, _exp_smooth_factor(zoom_smoothing_speed, delta))

	_target_pos = new_pos
	_target_zoom = new_zoom

	cam.global_position = _target_pos
	cam.zoom = _target_zoom

# ==========================================================
# PLAYER CENTER
# ==========================================================
func _compute_player_center(players: Array) -> Vector2:
	if players.size() == 1:
		return players[0].global_position

	var p1 = players[0].global_position
	var p2 = players[1].global_position

	var left = min(p1.x, p2.x) - soft_margin.x
	var right = max(p1.x, p2.x) + soft_margin.x
	var top = min(p1.y, p2.y) - soft_margin.y
	var bottom = max(p1.y, p2.y) + soft_margin.y

	var center := Vector2(
		(left + right) * 0.5,
		(top + bottom) * 0.5
	)

	if lock_vertical_if_close:
		var vertical_dist = abs(p1.y - p2.y)
		if vertical_dist < vertical_lock_threshold:
			center.y = lerp(cam.global_position.y, center.y, 0.1)

	return center

# ==========================================================
# ZOOM
# ==========================================================
func _compute_target_zoom(players: Array) -> Vector2:
	if not zoom_enabled:
		return cam.zoom

	if players.size() == 1:
		return single_player_zoom

	var separation = players[0].global_position.distance_to(players[1].global_position)
	var t = clamp(separation / separation_for_max_zoom, 0.0, 1.0)

	return Vector2(
		lerp(zoom_in.x, zoom_out.x, t),
		lerp(zoom_in.y, zoom_out.y, t)
	)

# ==========================================================
# PLAYER CLAMPING
# ==========================================================
func _clamp_to_players(center: Vector2, zoom: Vector2) -> Vector2:
	var vp_size := get_viewport_rect().size
	var half_w := (vp_size.x * 0.5) * zoom.x
	var half_h := (vp_size.y * 0.5) * zoom.y

	var players := PlayerManager.players
	if players.size() > 0:
		var min_x = players[0].global_position.x
		var max_x = min_x
		var min_y = players[0].global_position.y
		var max_y = min_y

		for p in players:
			min_x = min(min_x, p.global_position.x)
			max_x = max(max_x, p.global_position.x)
			min_y = min(min_y, p.global_position.y)
			max_y = max(max_y, p.global_position.y)

		# Add soft margin
		min_x -= soft_margin.x
		max_x += soft_margin.x
		min_y -= soft_margin.y
		max_y += soft_margin.y

		center.x = clamp(center.x, min_x + half_w, max_x - half_w)
		center.y = clamp(center.y, min_y + half_h, max_y - half_h)

	return center

# ==========================================================
# LEVEL BOUNDS (optional)
# ==========================================================
func _compute_level_bounds() -> Rect2:
	if use_tilemap_bounds and tilemap_path != NodePath():
		var tm := get_node_or_null(tilemap_path)
		if tm != null:
			var used = tm.get_used_rect()
			var tile_size = tm.tile_set.tile_size
			var world_pos = tm.to_global(Vector2(used.position.x * tile_size.x, used.position.y * tile_size.y))
			var world_size := Vector2(used.size.x * tile_size.x, used.size.y * tile_size.y)
			return Rect2(world_pos, world_size)
	return manual_level_bounds

# ==========================================================
# SMOOTHING HELPER
# ==========================================================
func _exp_smooth_factor(speed: float, delta: float) -> float:
	return clamp(1.0 - pow(0.001, delta * speed), 0.0, 1.0)

# ==========================================================
# SIGNAL CALLBACK
# ==========================================================
func _on_players_changed() -> void:
	if PlayerManager.players.size() > 0:
		_target_pos = PlayerManager.players[0].global_position
