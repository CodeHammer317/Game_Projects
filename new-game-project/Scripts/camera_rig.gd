# camera_rig.gd (Godot 4.x)
extends Node2D

@export var player1_path: NodePath
@export var player2_path: NodePath

# Optional: auto-calc level bounds from a TileMap (set to empty to use manual bounds)
@export var tilemap_path: NodePath
@export var use_tilemap_bounds: bool = true

# Manual bounds fallback if you don't provide a TileMap (pixels, in world space)
@export var manual_level_bounds: Rect2 = Rect2(0, 0, 4096, 2304)

# Follow behavior
@export var soft_margin: Vector2 = Vector2(200.0, 120.0)  # expanded area around players before camera starts moving
@export var position_smoothing_enabled: bool = true
@export var position_smoothing_speed: float = 8.0

# Zoom behavior (rubber band)
@export var zoom_enabled: bool = true
@export var min_zoom: Vector2 = Vector2(1.0, 1.0)     # normal zoom
@export var max_zoom: Vector2 = Vector2(0.6, 0.6)     # further out = see more
@export var separation_for_max_zoom: float = 1600.0   # distance between players for max zoom
@export var zoom_smoothing_enabled: bool = true
@export var zoom_smoothing_speed: float = 6.0

# Optional vertical clamp (platformers often limit vertical camera drift)
@export var lock_vertical_if_close: bool = true
@export var vertical_lock_threshold: float = 32.0

@onready var cam: Camera2D = $Camera2D

var _p1: Node2D
var _p2: Node2D
var _level_bounds: Rect2

var _target_pos: Vector2
var _target_zoom: Vector2

func _ready() -> void:
	# Resolve players
	if player1_path != NodePath():
		_p1 = get_node_or_null(player1_path)
	if player2_path != NodePath():
		_p2 = get_node_or_null(player2_path)

	if _p1 == null:
		push_error("CameraRig: player1_path not set or node not found.")
	if _p2 == null:
		push_error("CameraRig: player2_path not set or node not found.")

	# Determine level bounds
	if use_tilemap_bounds == true and tilemap_path != NodePath():
		var tm: TileMapLayer = get_node_or_null(tilemap_path)
		if tm != null:
			_level_bounds = _compute_bounds_from_tilemap(tm)
		else:
			push_warning("CameraRig: tilemap_path set but TileMap not found. Falling back to manual_level_bounds.")
			_level_bounds = manual_level_bounds
	else:
		_level_bounds = manual_level_bounds

	# Camera must be current
	cam.enabled = true

	# Initialize targets
	_target_pos = global_position
	_target_zoom = cam.zoom

func _process(delta: float) -> void:
	if _p1 == null or _p2 == null:
		return

	var p1_pos: Vector2 = _p1.global_position
	var p2_pos: Vector2 = _p2.global_position

	# Build a bounding rect around players + soft margin
	var left: float = min(p1_pos.x, p2_pos.x) - soft_margin.x
	var right: float = max(p1_pos.x, p2_pos.x) + soft_margin.x
	var top: float = min(p1_pos.y, p2_pos.y) - soft_margin.y
	var bottom: float = max(p1_pos.y, p2_pos.y) + soft_margin.y
	var center: Vector2 = Vector2((left + right) * 0.5, (top + bottom) * 0.5)

	# Optionally reduce vertical camera movement when players are close vertically
	if lock_vertical_if_close == true:
		var vertical_dist: float = abs(p1_pos.y - p2_pos.y)
		if vertical_dist < vertical_lock_threshold:
			center.y = lerp(cam.global_position.y, center.y, 0.1)

	# Compute target zoom (rubber-band)
	var target_zoom: Vector2 = cam.zoom
	if zoom_enabled == true:
		var separation: float = p1_pos.distance_to(p2_pos)
		var t: float = separation / separation_for_max_zoom
		if t < 0.0:
			t = 0.0
		if t > 1.0:
			t = 1.0
		var zx: float = lerp(min_zoom.x, max_zoom.x, t)
		var zy: float = lerp(min_zoom.y, max_zoom.y, t)
		target_zoom = Vector2(zx, zy)

	# Clamp center so the camera never shows outside level bounds
	#center = _clamp_to_bounds(center, target_zoom)

	# Smooth position
	var new_pos: Vector2 = center
	if position_smoothing_enabled == true:
		var s: float = _exp_smooth_factor(position_smoothing_speed, delta)
		new_pos = cam.global_position.lerp(center, s)

	# Smooth zoom
	var new_zoom: Vector2 = target_zoom
	if zoom_smoothing_enabled == true:
		var zs: float = _exp_smooth_factor(zoom_smoothing_speed, delta)
		new_zoom = cam.zoom.lerp(target_zoom, zs)

	_target_pos = new_pos
	_target_zoom = new_zoom

	cam.global_position = _target_pos
	cam.zoom = _target_zoom

func _clamp_to_bounds(center: Vector2, zoom: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	# Visible world half-size in pixels (zoom > 1 means we see more world)
	var half_w: float = (vp_size.x * 0.5) * zoom.x
	var half_h: float = (vp_size.y * 0.5) * zoom.y

	var min_x: float = _level_bounds.position.x + half_w
	var max_x: float = _level_bounds.position.x + _level_bounds.size.x - half_w
	var min_y: float = _level_bounds.position.y + half_h
	var max_y: float = _level_bounds.position.y + _level_bounds.size.y - half_h

	# If level smaller than viewport, center within bounds
	if min_x > max_x:
		center.x = _level_bounds.position.x + (_level_bounds.size.x * 0.5)
	else:
		center.x = clamp(center.x, min_x, max_x)

	if min_y > max_y:
		center.y = _level_bounds.position.y + (_level_bounds.size.y * 0.5)
	else:
		center.y = clamp(center.y, min_y, max_y)

	return center

func _compute_bounds_from_tilemap(tm: TileMapLayer) -> Rect2:
	# This assumes a regular grid and TileMap with no scaling/rotation.
	# For most side-scrollers this is fine.
	var used: Rect2i = tm.get_used_rect()
	var tile_size: Vector2i = tm.tile_set.tile_size

	var world_pos: Vector2 = tm.to_global(Vector2(used.position.x * tile_size.x, used.position.y * tile_size.y))
	var world_size: Vector2 = Vector2(used.size.x * tile_size.x, used.size.y * tile_size.y)

	return Rect2(world_pos, world_size)

func _exp_smooth_factor(speed: float, delta: float) -> float:
	# Convert speed (units/sec) into an exponential smoothing weight 0..1
	# Higher speed -> snappier camera.
	var s: float = 1.0 - pow(0.001, delta * speed)
	if s < 0.0:
		s = 0.0
	if s > 1.0:
		s = 1.0
	return s
