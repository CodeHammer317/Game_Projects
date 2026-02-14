## File: CoopCamera2D.gd
## Godot 4.6, GDScript 2.0
## Co-op camera with midpoint follow, safe-zone, dynamic zoom, rubber-band tether, and bounds clamping.
## No ternary operators. Uses queue_redraw() (Godot 4) for debug draw.

extends Camera2D

@export_node_path("Node2D") var player1_path: NodePath
@export_node_path("Node2D") var player2_path: NodePath

# Follow & smoothing
@export var position_smooth_speed: float = 6.0

# Safe-zone (dead-zone) to reduce micro-jitter
@export var safe_zone_size: Vector2 = Vector2(220.0, 140.0) # world pixels (for 320x180 internal)
@export var safe_zone_softness: float = 0.25 # 0..1 how gently we pull after crossing

# Dynamic zoom
@export var min_zoom: Vector2 = Vector2(1.0, 1.0)
@export var max_zoom: Vector2 = Vector2(1.6, 1.6)
@export var distance_for_max_zoom: float = 900.0
@export var zoom_lerp_speed: float = 3.5

# Rubber-band tether
@export var max_player_separation: float = 1200.0
@export var tether_accel: float = 900.0        # acceleration toward midpoint (px/s^2)
@export var tether_max_push_speed: float = 420.0

# Optional debug
@export var debug_draw_safe_zone: bool = true
@export var debug_color: Color = Color(0.2, 0.8, 1.0, 0.35)

var _p1: Node2D
var _p2: Node2D

func _ready() -> void:
	# Acquire players via NodePath if provided
	if player1_path != NodePath():
		_p1 = get_node(player1_path) as Node2D
	if player2_path != NodePath():
		_p2 = get_node(player2_path) as Node2D

	# Fallback: try to find by "players" group if not set
	if _p1 == null or _p2 == null:
		var by_group := get_tree().get_nodes_in_group("player")
		if _p1 == null:
			if by_group.size() >= 1:
				_p1 = by_group[0] as Node2D
		if _p2 == null:
			if by_group.size() >= 2:
				_p2 = by_group[1] as Node2D

	# Ensure smoothing is active (Inspector settings are also applied)
	position_smoothing_enabled = true
	position_smoothing_speed = position_smooth_speed
	rotation_smoothing_enabled = false

	# ✅ Correct enum in Godot 4.x:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

func _physics_process(delta: float) -> void:
	var have_p1 := _p1 != null
	var have_p2 := _p2 != null

	if not have_p1 and not have_p2:
		return

	if have_p1 and have_p2:
		var p1_pos: Vector2 = _p1.global_position
		var p2_pos: Vector2 = _p2.global_position
		var midpoint: Vector2 = (p1_pos + p2_pos) * 0.5

		_apply_safe_zone_and_move(midpoint, delta)

		var separation: float = p1_pos.distance_to(p2_pos)
		_apply_dynamic_zoom(separation, delta)
		_apply_rubber_band_if_needed(delta)
	else:
		# Follow whichever player exists
		var lone: Node2D = null
		if have_p1:
			lone = _p1
		else:
			lone = _p2

		if lone != null:
			var target_pos: Vector2 = lone.global_position
			var alpha: float = delta * position_smooth_speed
			if alpha < 0.0:
				alpha = 0.0
			if alpha > 1.0:
				alpha = 1.0
			global_position = global_position.lerp(target_pos, alpha)

			var z_alpha: float = delta * zoom_lerp_speed
			if z_alpha < 0.0:
				z_alpha = 0.0
			if z_alpha > 1.0:
				z_alpha = 1.0
			zoom = zoom.lerp(min_zoom, z_alpha)

	_clamp_to_limits()

	if debug_draw_safe_zone:
		# Godot 4: request a redraw of _draw()
		queue_redraw()

func _apply_safe_zone_and_move(target_midpoint: Vector2, delta: float) -> void:
	var cam_center: Vector2 = global_position
	var half: Vector2 = safe_zone_size * 0.5
	var safe_rect := Rect2(cam_center - half, safe_zone_size)
	var pull := Vector2.ZERO

	# Guard: both players must exist when this is called
	if _p1 == null or _p2 == null:
		return

	var positions: Array = [_p1.global_position, _p2.global_position]
	for i in positions.size():
		var p: Vector2 = positions[i]
		if not safe_rect.has_point(p):
			var dx := 0.0
			var dy := 0.0
			if p.x < safe_rect.position.x:
				dx = p.x - safe_rect.position.x
			else:
				if p.x > safe_rect.position.x + safe_rect.size.x:
					dx = p.x - (safe_rect.position.x + safe_rect.size.x)

			if p.y < safe_rect.position.y:
				dy = p.y - safe_rect.position.y
			else:
				if p.y > safe_rect.position.y + safe_rect.size.y:
					dy = p.y - (safe_rect.position.y + safe_rect.size.y)

			pull += Vector2(dx, dy)

	var desired: Vector2 = target_midpoint
	if pull != Vector2.ZERO:
		desired = cam_center + pull.lerp(Vector2.ZERO, 1.0 - safe_zone_softness)

	var alpha: float = delta * position_smooth_speed
	if alpha < 0.0:
		alpha = 0.0
	if alpha > 1.0:
		alpha = 1.0
	global_position = global_position.lerp(desired, alpha)

func _apply_dynamic_zoom(separation: float, delta: float) -> void:
	var t: float = separation / distance_for_max_zoom
	if t < 0.0:
		t = 0.0
	if t > 1.0:
		t = 1.0

	var z: Vector2 = min_zoom.lerp(max_zoom, t)

	var z_alpha: float = delta * zoom_lerp_speed
	if z_alpha < 0.0:
		z_alpha = 0.0
	if z_alpha > 1.0:
		z_alpha = 1.0

	zoom = zoom.lerp(z, z_alpha)

func _apply_rubber_band_if_needed(delta: float) -> void:
	if _p1 == null or _p2 == null:
		return

	var p1_pos: Vector2 = _p1.global_position
	var p2_pos: Vector2 = _p2.global_position
	var sep: float = p1_pos.distance_to(p2_pos)
	if sep <= max_player_separation:
		return

	var midpoint: Vector2 = (p1_pos + p2_pos) * 0.5
	var v1: Vector2 = midpoint - p1_pos
	var v2: Vector2 = midpoint - p2_pos

	var farther_is_p1: bool = false
	if v1.length_squared() > v2.length_squared():
		farther_is_p1 = true

	var target_player: Node2D = null
	if farther_is_p1:
		target_player = _p1
	else:
		target_player = _p2

	if target_player == null:
		return

	var dir: Vector2 = (midpoint - target_player.global_position)
	if dir != Vector2.ZERO:
		dir = dir.normalized()

	var push_speed: float = tether_accel * delta
	if push_speed > tether_max_push_speed:
		push_speed = tether_max_push_speed
	if push_speed < 0.0:
		push_speed = 0.0

	var push: Vector2 = dir * push_speed

	# Prefer using a player API (cleaner than teleporting)
	if "apply_tether_impulse" in target_player:
		target_player.call("apply_tether_impulse", push, tether_max_push_speed)
	else:
		# Tiny positional nudge fallback
		target_player.global_position += push * 0.25

func _clamp_to_limits() -> void:
	var pos: Vector2 = global_position
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view: Vector2 = (viewport_size * 0.5) * zoom

	var left: float = limit_left + half_view.x
	var right: float = limit_right - half_view.x
	var top: float = limit_top + half_view.y
	var bottom: float = limit_bottom - half_view.y

	if pos.x < left:
		pos.x = left
	else:
		if pos.x > right:
			pos.x = right

	if pos.y < top:
		pos.y = top
	else:
		if pos.y > bottom:
			pos.y = bottom

	global_position = pos

func _draw() -> void:
	if not debug_draw_safe_zone:
		return
	var half: Vector2 = safe_zone_size * 0.5
	var rect := Rect2(-half, safe_zone_size)
	draw_rect(rect, debug_color, false, 2.0)
