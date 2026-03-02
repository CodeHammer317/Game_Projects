# res://CameraRig.gd
extends Node2D

@export var tilemap_path: NodePath
@export var use_tilemap_bounds: bool = true
@export var manual_level_bounds: Rect2 = Rect2(0, 0, 4096, 2304)

@export var soft_margin: Vector2 = Vector2(200, 120)
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 8.0

@export var zoom_enabled: bool = true
@export var min_zoom: Vector2 = Vector2(2.0, 2.0)
@export var max_zoom: Vector2 = Vector2(1.5, 1.5)
@export var separation_for_max_zoom: float = 800.0
@export var zoom_smoothing_enabled: bool = true
@export var zoom_smoothing_speed: float = 6.0

@export var lock_vertical_if_close: bool = true
@export var vertical_lock_threshold: float = 32.0

@onready var cam: Camera2D = $Camera2D
var _level_bounds: Rect2
var _target_pos: Vector2
var _target_zoom: Vector2

func _ready() -> void:
	_level_bounds = _compute_level_bounds()
	cam.enabled = true
	_target_pos = global_position
	_target_zoom = cam.zoom

	# Listen for player join/leave
	if has_node("/root/PlayerManager"):
		var pm = get_node("/root/PlayerManager")
		pm.connect("players_changed", Callable(self, "_on_players_changed"))

func _process(delta: float) -> void:
	var players := PlayerManager.players
	if players.size() == 0:
		return

	var center := _compute_player_center(players)
	var target_zoom := _compute_target_zoom(players)

	center = _clamp_to_bounds(center, target_zoom)

	# Smooth position
	var new_pos := center
	if position_smoothing_enabled:
		var s := _exp_smooth_factor(position_smoothing_speed, delta)
		new_pos = cam.global_position.lerp(center, s)

	# Smooth zoom
	var new_zoom := target_zoom
	if zoom_smoothing_enabled:
		var zs := _exp_smooth_factor(zoom_smoothing_speed, delta)
		new_zoom = cam.zoom.lerp(target_zoom, zs)

	_target_pos = new_pos
	_target_zoom = new_zoom

	cam.global_position = _target_pos
	cam.zoom = _target_zoom

# ==========================================================
# PLAYER CENTER & ZOOM
# ==========================================================
func _compute_player_center(players: Array) -> Vector2:
	if players.size() == 1:
		return players[0].global_position

	var p1_pos = players[0].global_position
	var p2_pos = players[1].global_position

	var left = min(p1_pos.x, p2_pos.x) - soft_margin.x
	var right = max(p1_pos.x, p2_pos.x) + soft_margin.x
	var top = min(p1_pos.y, p2_pos.y) - soft_margin.y
	var bottom = max(p1_pos.y, p2_pos.y) + soft_margin.y

	var center = Vector2((left + right) * 0.5, (top + bottom) * 0.5)

	if lock_vertical_if_close:
		var vertical_dist = abs(p1_pos.y - p2_pos.y)
		if vertical_dist < vertical_lock_threshold:
			center.y = lerp(cam.global_position.y, center.y, 0.1)

	return center

func _compute_target_zoom(players: Array) -> Vector2:
	if not zoom_enabled or players.size() == 1:
		return cam.zoom

	var separation = players[0].global_position.distance_to(players[1].global_position)
	var t = separation / separation_for_max_zoom

	if t < 0.0:
		t = 0.0
	elif t > 1.0:
		t = 1.0

	var zx = lerp(min_zoom.x, max_zoom.x, t)
	var zy = lerp(min_zoom.y, max_zoom.y, t)
	var zoom_vec = Vector2(zx, zy)

	var resonance = PlayerManager.resonance_strength
	if resonance < 0.0:
		resonance = 0.0
	elif resonance > 1.0:
		resonance = 1.0

	zoom_vec = zoom_vec * lerp(1.0, 0.95, 1.0 - resonance)
	return zoom_vec

# ==========================================================
# LEVEL BOUNDS
# ==========================================================
func _compute_level_bounds() -> Rect2:
	if use_tilemap_bounds and tilemap_path != NodePath():
		var tm = get_node_or_null(tilemap_path)
		if tm != null:
			return _compute_bounds_from_tilemap(tm)
	return manual_level_bounds

func _compute_bounds_from_tilemap(tm: TileMapLayer) -> Rect2:
	var used = tm.get_used_rect()
	var tile_size = tm.tile_set.tile_size
	var world_pos = tm.to_global(Vector2(used.position.x * tile_size.x, used.position.y * tile_size.y))
	var world_size = Vector2(used.size.x * tile_size.x, used.size.y * tile_size.y)
	return Rect2(world_pos, world_size)

func _clamp_to_bounds(center: Vector2, zoom: Vector2) -> Vector2:
	var vp_size = get_viewport_rect().size
	var half_w = (vp_size.x * 0.5) * zoom.x
	var half_h = (vp_size.y * 0.5) * zoom.y

	var min_x = _level_bounds.position.x + half_w
	var max_x = _level_bounds.position.x + _level_bounds.size.x - half_w
	var min_y = _level_bounds.position.y + half_h
	var max_y = _level_bounds.position.y + _level_bounds.size.y - half_h

	if min_x > max_x:
		center.x = _level_bounds.position.x + (_level_bounds.size.x * 0.5)
	else:
		if center.x < min_x:
			center.x = min_x
		elif center.x > max_x:
			center.x = max_x

	if min_y > max_y:
		center.y = _level_bounds.position.y + (_level_bounds.size.y * 0.5)
	else:
		if center.y < min_y:
			center.y = min_y
		elif center.y > max_y:
			center.y = max_y

	return center

# ==========================================================
# SMOOTHING
# ==========================================================
func _exp_smooth_factor(speed: float, delta: float) -> float:
	var s = 1.0 - pow(0.001, delta * speed)
	if s < 0.0:
		s = 0.0
	elif s > 1.0:
		s = 1.0
	return s

# ==========================================================
# SIGNAL CALLBACK
# ==========================================================
func _on_players_changed() -> void:
	# Optional: immediately center on first player when players list changes
	if PlayerManager.players.size() > 0:
		_target_pos = PlayerManager.players[0].global_position





# res://CameraRig.gd
'''extends Node2D

# --------------------------------------------------
# LEVEL BOUNDS
# --------------------------------------------------

@export var tilemap_path: NodePath
@export var use_tilemap_bounds: bool = true
@export var manual_level_bounds: Rect2 = Rect2(0, 0, 4096, 2304)

# --------------------------------------------------
# FOLLOW SETTINGS
# --------------------------------------------------

@export var soft_margin: Vector2 = Vector2(200, 120)
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 8.0

# --------------------------------------------------
# ZOOM SETTINGS
# --------------------------------------------------

@export var zoom_enabled: bool = true
@export var min_zoom: Vector2 = Vector2(1.1, 1.1)
@export var max_zoom: Vector2 = Vector2(0.9, 0.9)
@export var separation_for_max_zoom: float = 800.0
@export var zoom_smoothing_enabled: bool = true
@export var zoom_smoothing_speed: float = 6.0

# --------------------------------------------------
# PLATFORMER STABILITY
# --------------------------------------------------

@export var lock_vertical_if_close: bool = true
@export var vertical_lock_threshold: float = 32.0

# --------------------------------------------------
# INTERNALS
# --------------------------------------------------

@onready var cam: Camera2D = $Camera2D

var _level_bounds: Rect2
var _target_pos: Vector2
var _target_zoom: Vector2


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	_level_bounds = _compute_level_bounds()
	print("Level Bounds: ",_level_bounds)
	print("Connected joypads: ", Input.get_connected_joypads())
	cam.enabled = true
	_target_pos = cam.global_position
	_target_zoom = cam.zoom


# ==================================================
# MAIN LOOP
# ==================================================

func _process(delta: float) -> void:
	
	if not Engine.has_singleton("PlayerManager"):
		return

	var players := PlayerManager.players

	if players.size() == 0:
		return

	var center := _compute_target_center(players)
	var target_zoom := _compute_target_zoom(players)

	center = _clamp_to_bounds(center, target_zoom)

	# Smooth position
	if position_smoothing_enabled:
		var s := _exp_smooth_factor(position_smoothing_speed, delta)
		_target_pos = cam.global_position.lerp(center, s)
	else:
		_target_pos = center

	# Smooth zoom
	if zoom_smoothing_enabled:
		var zs := _exp_smooth_factor(zoom_smoothing_speed, delta)
		_target_zoom = cam.zoom.lerp(target_zoom, zs)
	else:
		_target_zoom = target_zoom

	cam.global_position = _target_pos
	cam.zoom = _target_zoom


# ==================================================
# CENTER LOGIC
# ==================================================

func _compute_target_center(players: Array) -> Vector2:

	# 1 PLAYER
	if players.size() == 1:
		return players[0].global_position

	# 2+ PLAYERS (uses first two)
	var p1_pos = players[0].global_position
	var p2_pos = players[1].global_position

	var left = min(p1_pos.x, p2_pos.x) - soft_margin.x
	var right = max(p1_pos.x, p2_pos.x) + soft_margin.x
	var top = min(p1_pos.y, p2_pos.y) - soft_margin.y
	var bottom = max(p1_pos.y, p2_pos.y) + soft_margin.y

	var center := Vector2(
		(left + right) * 0.5,
		(top + bottom) * 0.5
	)

	# Vertical stability for platformers
	if lock_vertical_if_close:
		var vertical_dist = abs(p1_pos.y - p2_pos.y)
		if vertical_dist < vertical_lock_threshold:
			center.y = lerp(cam.global_position.y, center.y, 0.1)

	return center


# ==================================================
# ZOOM LOGIC
# ==================================================

func _compute_target_zoom(players: Array) -> Vector2:

	if not zoom_enabled:
		return cam.zoom

	if players.size() < 2:
		return min_zoom  # default zoom in single player

	var separation = players[0].global_position.distance_to(
		players[1].global_position
	)

	var t = clamp(separation / separation_for_max_zoom, 0.0, 1.0)

	var zx = lerp(min_zoom.x, max_zoom.x, t)
	var zy = lerp(min_zoom.y, max_zoom.y, t)

	var target_zoom := Vector2(zx, zy)

	# Optional resonance effect
	if Engine.has_singleton("PlayerManager"):
		var resonance := PlayerManager.resonance_strength
		target_zoom *= lerp(1.0, 0.95, 1.0 - resonance)

	return target_zoom


# ==================================================
# LEVEL BOUNDS
# ==================================================

func _compute_level_bounds() -> Rect2:

	if use_tilemap_bounds and tilemap_path != NodePath():
		var tm := get_node_or_null(tilemap_path)
		if tm != null and tm is TileMapLayer:
			return _compute_bounds_from_tilemap(tm)

	return manual_level_bounds


func _compute_bounds_from_tilemap(tm: TileMapLayer) -> Rect2:

	var used: Rect2i = tm.get_used_rect()
	var tile_size: Vector2i = tm.tile_set.tile_size

	var world_pos := tm.to_global(
		Vector2(
			used.position.x * tile_size.x,
			used.position.y * tile_size.y
		)
	)

	var world_size := Vector2(
		used.size.x * tile_size.x,
		used.size.y * tile_size.y
	)

	return Rect2(world_pos, world_size)


# ==================================================
# CLAMPING
# ==================================================

func _clamp_to_bounds(center: Vector2, zoom: Vector2) -> Vector2:

	var vp_size := get_viewport_rect().size
	var half_w := (vp_size.x * 0.5) * zoom.x
	var half_h := (vp_size.y * 0.5) * zoom.y

	var min_x := _level_bounds.position.x + half_w
	var max_x := _level_bounds.position.x + _level_bounds.size.x - half_w
	var min_y := _level_bounds.position.y + half_h
	var max_y := _level_bounds.position.y + _level_bounds.size.y - half_h

	# Horizontal
	if min_x > max_x:
		center.x = _level_bounds.position.x + (_level_bounds.size.x * 0.5)
	else:
		center.x = clamp(center.x, min_x, max_x)

	# Vertical
	if min_y > max_y:
		center.y = _level_bounds.position.y + (_level_bounds.size.y * 0.5)
	else:
		center.y = clamp(center.y, min_y, max_y)

	return center


# ==================================================
# SMOOTHING
# ==================================================

func _exp_smooth_factor(speed: float, delta: float) -> float:
	var s := 1.0 - pow(0.001, delta * speed)
	return clamp(s, 0.0, 1.0)'''
