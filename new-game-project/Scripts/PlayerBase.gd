extends CharacterBody2D
class_name PlayerBase

# -----------------------------
# EXPORTED SETTINGS
# -----------------------------
@export var player_id: int = 1
@export var stats: PlayerStats
@export var abilities: AbilitySet
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.2
@export var max_bullets_on_screen: int = 3
#@export var player_num: int = 1

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
var _is_wall_jumping: bool = false
var _shooting: bool = false
var _attacking: bool = false
var input_device: int = -1
# -----------------------------
# POSE NODES (Sprite2D)
# -----------------------------
@onready var pose_idle: Sprite2D        = $Poses/Idle
@onready var pose_run: Sprite2D         = $Poses/Run
@onready var pose_dash: Sprite2D        = $Poses/Dash
@onready var pose_wall_slide: Sprite2D  = $Poses/WallSlide
@onready var pose_wall_jump: Sprite2D   = $Poses/WallJump
@onready var pose_shoot: Sprite2D       = $Poses/Shoot
@onready var pose_attack: Sprite2D      = $Poses/Attack
@onready var pose_jump: Sprite2D        = $Poses/Jump
@onready var pose_falling: Sprite2D     = $Poses/Falling
@onready var muzzle: Marker2D           = get_node_or_null("Sockets/Muzzle")
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail")

# -----------------------------
# READY
# -----------------------------
func _ready() -> void:
	if PlayerManager:
		PlayerManager.register_player(self, player_id)

	input_device = player_id
'''func _ready() -> void:
	# Register with PlayerManager for co-op tracking
	if Engine.has_singleton("PlayerManager"):
		var pm := Engine.get_singleton("PlayerManager")
		if pm != null:
			pm.register_player(self, 0) # device 0 for now, will bind in GameManager
	if InputBindings.player_devices.has(player_num):
		input_device = InputBindings.player_devices[player_num]
	else:
		input_device = -1  # fallback to keyboard'''
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
	_update_pose_visibility()
	_cleanup_bullet_list()
	_cooldown_shoot(delta)

	if abilities != null:
		abilities.tick(self, delta)

# -----------------------------
# TIMERS
# -----------------------------
func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = stats.coyote_time
	else:
		_coyote_timer -= delta
		if _coyote_timer < 0.0:
			_coyote_timer = 0.0

	_jump_buffer_timer -= delta
	if _jump_buffer_timer < 0.0:
		_jump_buffer_timer = 0.0

	if _dash_cd > 0.0:
		_dash_cd -= delta
		if _dash_cd < 0.0:
			_dash_cd = 0.0

	if _dash_timer > 0.0:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_dashing = false
			if dust_trail:
				dust_trail.emitting = false

	if _wall_jump_lock_timer > 0.0:
		_wall_jump_lock_timer -= delta
		if _wall_jump_lock_timer < 0.0:
			_wall_jump_lock_timer = 0.0

	if is_on_floor():
		_is_wall_jumping = false

# -----------------------------
# GRAVITY
# -----------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor() and not _dashing:
		velocity.y += stats.gravity * delta

# -----------------------------
# DASH
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
# INPUT
# -----------------------------
func _read_input() -> int:
	var prefix: String = "p1_" 
	if player_id == 2:
		prefix = "p2_"

	var left_pressed := Input.is_action_pressed(prefix + "left")
	var right_pressed := Input.is_action_pressed(prefix + "right")

	# Jump pressed
	if Input.is_action_just_pressed(prefix + "jump"):
		_jump_buffer_timer = stats.jump_buffer

		# Wall jump check
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

	# Jump activation
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0 or is_on_floor():
			velocity.y = stats.jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0

	# Variable jump height
	if Input.is_action_just_released(prefix + "jump") and velocity.y < 0.0:
		velocity.y *= stats.variable_jump_cut

	# Attack
	if Input.is_action_just_pressed(prefix + "attack"):
		_attacking = true
		if abilities != null:
			abilities.on_attack_pressed(self)
	if Input.is_action_just_released(prefix + "attack"):
		_attacking = false

	# Shoot
	if Input.is_action_pressed(prefix + "shoot"):
		_shooting = true
		if abilities != null:
			abilities.on_shoot_pressed(self)
		else:
			spawn_bullet()
	if Input.is_action_just_released(prefix + "shoot"):
		_shooting = false

	# Dash
	if Input.is_action_just_pressed(prefix + "dash"):
		_start_dash()

	# Horizontal input
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
			fric *= 0.25
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

# -----------------------------
# WALL STATE
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
		if _dashing:
			_dashing = false
			_dash_timer = 0.0
			if dust_trail:
				dust_trail.emitting = false
		if velocity.y > WALL_SLIDE_SPEED:
			velocity.y = WALL_SLIDE_SPEED
		velocity.x = 0.0

# -----------------------------
# WALL JUMP
# -----------------------------
func _perform_wall_jump() -> void:
	var wall_normal := get_wall_normal()
	var push_dir := 0
	if wall_normal.x > 0.0:
		push_dir = 1
		_facing_left = false
	elif wall_normal.x < 0.0:
		push_dir = -1
		_facing_left = true

	if push_dir == 0:
		return

	velocity.x = float(push_dir) * WALL_JUMP_PUSH
	velocity.y = stats.jump_velocity
	_wall_jump_lock_timer = WALL_JUMP_LOCK_TIME
	_is_wall_sliding = false
	_is_wall_jumping = true
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

	for pose in $Poses.get_children():
		if pose is Sprite2D:
			pose.flip_h = _facing_left
	if muzzle and muzzle.has_method("set_facing_left"):
		muzzle.set_facing_left(_facing_left)
# -----------------------------
# POSE VISIBILITY
# -----------------------------
func _hide_all_poses() -> void:
	for pose in $Poses.get_children():
		if pose is Sprite2D:
			pose.visible = false

func _update_pose_visibility() -> void:
	_hide_all_poses()
	if _attacking and pose_attack:
		pose_attack.visible = true
		return
	if _shooting and pose_shoot:
		pose_shoot.visible = true
		return
	if _is_wall_jumping and pose_wall_jump:
		pose_wall_jump.visible = true
		return
	if _is_wall_sliding and pose_wall_slide:
		pose_wall_slide.visible = true
		return
	if _dashing and pose_dash:
		pose_dash.visible = true
		return
	if velocity.y < -6.0 and not is_on_floor() and pose_jump:
		pose_jump.visible = true
		return
	if velocity.y > 6.0 and not is_on_floor() and pose_falling:
		pose_falling.visible = true
		return
	if absf(velocity.x) > 6.0 and is_on_floor() and pose_run:
		pose_run.visible = true
		return
	if pose_idle:
		pose_idle.visible = true

# -----------------------------
# BULLETS
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

func spawn_bullet() -> void:
	if _fire_timer > 0.0 or _active_bullets.size() >= max_bullets_on_screen:
		return
	if muzzle == null or bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return

	bullet.global_position = muzzle.global_position

	var dir := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_tree().current_scene.add_child(bullet)

	if bullet is Projectile:
		bullet.team = 1
		bullet.launch(dir, null, self)
	elif bullet.has_method("launch"):
		bullet.launch(dir)

	_active_bullets.append(bullet)
	_fire_timer = fire_cooldown
# -----------------------------
# DAMAGE
# -----------------------------
func apply_damage(_amount: int) -> void:
	pass
