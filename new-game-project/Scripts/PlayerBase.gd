extends CharacterBody2D
class_name PlayerBase

# -----------------------------
# EXPORTED SETTINGS
# -----------------------------
@export var player_id: int = 1
@export var stats: PlayerStats
@export var abilities: AbilitySet
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.1
@export var max_bullets_on_screen: int = 3

# -----------------------------
# WALL MOVEMENT TUNING
# -----------------------------
const WALL_SLIDE_SPEED: float = 60.0
const WALL_JUMP_PUSH: float = 260.0
const WALL_JUMP_LOCK_TIME: float = 0.12

# -----------------------------
# INTERNAL RUNTIME STATE
# -----------------------------
var _fire_timer: float = 0.0
var _active_bullets: Array = []

var _facing_left: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

var _dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: int = 1

var _is_wall_sliding: bool = false
var _on_left_wall: bool = false
var _on_right_wall: bool = false
var _wall_jump_lock_timer: float = 0.0

# -----------------------------
# NODE REFERENCES
# -----------------------------
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim: AnimationTree = get_node_or_null("AnimationTree")
@onready var muzzle: Marker2D = get_node_or_null("Sockets/Muzzle")
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail")

# -----------------------------
# MAIN LOOP
# -----------------------------
func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)

	var horizontal_input := _read_input()
	_apply_horizontal(horizontal_input, delta)

	move_and_slide()

	_update_wall_state(horizontal_input)
	_update_facing()
	_update_animation()
	_cleanup_bullet_list()
	_cooldown_shoot(delta)

	if abilities != null:
		abilities.tick(self, delta)

# -----------------------------
# TIMER UPDATES
# -----------------------------
func _update_timers(delta: float) -> void:
	# Coyote
	if is_on_floor():
		_coyote_timer = stats.coyote_time
	else:
		_coyote_timer -= delta
		if _coyote_timer < 0.0:
			_coyote_timer = 0.0

	# Jump buffer
	_jump_buffer_timer -= delta
	if _jump_buffer_timer < 0.0:
		_jump_buffer_timer = 0.0

	# Dash cooldown
	if _dash_cd > 0.0:
		_dash_cd -= delta
		if _dash_cd < 0.0:
			_dash_cd = 0.0

	# Dash active window
	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dashing = false
			if dust_trail:
				dust_trail.emitting = false

	# Wall jump input lock
	if _wall_jump_lock_timer > 0.0:
		_wall_jump_lock_timer -= delta
		if _wall_jump_lock_timer < 0.0:
			_wall_jump_lock_timer = 0.0

# -----------------------------
# GRAVITY
# -----------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor() and not _dashing:
		velocity.y += stats.gravity * delta

# -----------------------------
# DASH SYSTEM
# -----------------------------
func _start_dash() -> void:
	if _dashing:
		return
	if _dash_cd > 0.0:
		return

	_dashing = true
	_dash_timer = stats.dash_time
	_dash_cd = stats.dash_cooldown

	if dust_trail:
		dust_trail.emitting = true

	if _facing_left:
		_dash_dir = -1
	else:
		_dash_dir = 1

	velocity.x = float(_dash_dir) * stats.dash_speed

# -----------------------------
# INPUT MAPPING
# -----------------------------
func _read_input() -> int:
	var prefix := ""
	if player_id == 1:
		prefix = "p1_"
	elif player_id == 2:
		prefix = "p2_"

	var left_pressed := Input.is_action_pressed(prefix + "left")
	var right_pressed := Input.is_action_pressed(prefix + "right")

	# Jump start
	if Input.is_action_just_pressed(prefix + "jump"):
		_jump_buffer_timer = stats.jump_buffer

		# Wall jump check (in air, on wall, pressing toward wall, not dashing)
		var can_wall_jump := false
		if not is_on_floor() and not _dashing and is_on_wall():
			var wall_normal := get_wall_normal()
			if left_pressed and wall_normal.x > 0.0:
				can_wall_jump = true
			elif right_pressed and wall_normal.x < 0.0:
				can_wall_jump = true

		if can_wall_jump:
			_perform_wall_jump()
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0

	# Jump activation (ground / coyote)
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0 or is_on_floor():
			velocity.y = stats.jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0

	# Variable jump height
	if Input.is_action_just_released(prefix + "jump"):
		if velocity.y < 0.0:
			velocity.y *= stats.variable_jump_cut

	# Melee (abilities)
	if Input.is_action_just_pressed(prefix + "attack"):
		if abilities != null:
			abilities.on_attack_pressed(self)

	# Shooting (abilities or direct)
	if Input.is_action_just_pressed(prefix + "shoot"):
		if abilities != null:
			abilities.on_shoot_pressed(self)
		else:
			spawn_bullet()

	# Dash
	if Input.is_action_just_pressed(prefix + "dash"):
		_start_dash()

	var input_x := 0
	if right_pressed:
		input_x += 1
	if left_pressed:
		input_x -= 1

	return input_x

# -----------------------------
# HORIZONTAL MOVEMENT
# -----------------------------
func _apply_horizontal(input_dir: int, delta: float) -> void:
	if _dashing:
		velocity.x = float(_dash_dir) * stats.dash_speed
		return

	# During wall jump lock, preserve horizontal velocity
	if _wall_jump_lock_timer > 0.0:
		return

	var on_ground := is_on_floor()
	var target_speed := float(input_dir) * stats.max_speed
	var accel := stats.accel_air * stats.air_control

	if on_ground:
		accel = stats.accel_ground

	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		var fric := stats.friction_ground
		if not on_ground:
			fric = stats.friction_ground * 0.25
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

# -----------------------------
# WALL STATE + SLIDE
# -----------------------------
func _update_wall_state(input_dir: int) -> void:
	_on_left_wall = false
	_on_right_wall = false
	_is_wall_sliding = false

	if is_on_wall() and not is_on_floor():
		var wall_normal := get_wall_normal()
		if wall_normal.x > 0.0:
			_on_left_wall = true
		elif wall_normal.x < 0.0:
			_on_right_wall = true

	var pressing_left := input_dir < 0
	var pressing_right := input_dir > 0

	if not is_on_floor() and not _dashing:
		if _on_left_wall and pressing_left:
			_is_wall_sliding = true
		elif _on_right_wall and pressing_right:
			_is_wall_sliding = true

	if _is_wall_sliding:
		# Cancel dash if somehow still active
		if _dashing:
			_dashing = false
			_dash_timer = 0.0
			if dust_trail:
				dust_trail.emitting = false

		# Slow downward slide
		if velocity.y > WALL_SLIDE_SPEED:
			velocity.y = WALL_SLIDE_SPEED

		# Stick to wall horizontally
		velocity.x = 0.0

# -----------------------------
# WALL JUMP
# -----------------------------
func _perform_wall_jump() -> void:
	var wall_normal := get_wall_normal()
	var push_dir := 0

	if wall_normal.x > 0.0:
		# Wall is on the left, push to the right
		push_dir = 1
		_facing_left = false
	elif wall_normal.x < 0.0:
		# Wall is on the right, push to the left
		push_dir = -1
		_facing_left = true

	if push_dir == 0:
		return

	velocity.x = float(push_dir) * WALL_JUMP_PUSH
	velocity.y = stats.jump_velocity

	_wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
	_is_wall_sliding = false

	if dust_trail:
		dust_trail.emitting = false

# -----------------------------
# FACING
# -----------------------------
func _update_facing() -> void:
	if absf(velocity.x) > 2.0:
		if velocity.x < 0.0:
			_facing_left = true
		elif velocity.x > 0.0:
			_facing_left = false

	if sprite != null:
		sprite.flip_h = _facing_left

# -----------------------------
# ANIMATION HOOK
# -----------------------------
func _update_animation() -> void:
	if anim == null:
		return

	var moving := absf(velocity.x) > 6.0 and is_on_floor()
	var airborne := not is_on_floor()

	# Basic three-state setup, with wall slide treated as its own case if you wire it
	var idle_state := not moving and not airborne and not _is_wall_sliding
	var move_state := moving and not _is_wall_sliding
	var air_state := airborne and not _is_wall_sliding

	anim.set("parameters/StateMachine/conditions/idle", idle_state)
	anim.set("parameters/StateMachine/conditions/move", move_state)
	anim.set("parameters/StateMachine/conditions/air", air_state)
	# If you add a "wall" condition in your AnimationTree, you can drive it with:
	# anim.set("parameters/StateMachine/conditions/wall", _is_wall_sliding)

# -----------------------------
# BULLET CLEANUP + COOLDOWN
# -----------------------------
func _cleanup_bullet_list() -> void:
	for i in range(_active_bullets.size() - 1, -1, -1):
		if not is_instance_valid(_active_bullets[i]):
			_active_bullets.remove_at(i)

func _cooldown_shoot(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
		if _fire_timer < 0.0:
			_fire_timer = 0.0

# -----------------------------
# BULLET SPAWNER (Muzzle)
# -----------------------------
func spawn_bullet() -> void:
	if _fire_timer > 0.0:
		return
	if _active_bullets.size() >= max_bullets_on_screen:
		return
	if muzzle == null:
		return
	if bullet_scene == null:
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	# Position BEFORE add_child
	bullet.global_position = muzzle.global_position
	get_tree().current_scene.add_child(bullet)

	var dir_x := 1
	if _facing_left:
		dir_x = -1

	if bullet.has_method("set_direction_x"):
		bullet.set_direction_x(dir_x)

	if bullet.has_method("set_instigator"):
		bullet.set_instigator(self)

	if bullet.has_node("Sprite2D"):
		var bs: Sprite2D = bullet.get_node("Sprite2D")
		bs.flip_h = _facing_left

	_active_bullets.append(bullet)
	_fire_timer = fire_cooldown

# -----------------------------
# DAMAGE PLACEHOLDER
# -----------------------------
func apply_damage(_amount: int) -> void:
	# Hook for your health system
	pass
