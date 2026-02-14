# PlayerBase.gd
extends CharacterBody2D
class_name PlayerBase

# -----------------------------
# EXPORTED SETTINGS
# -----------------------------
@export var player_id: int = 1
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail")


@export var stats: PlayerStats
@export var abilities: AbilitySet
@export var bullet_scene: PackedScene

@export var fire_cooldown: float = 0.1
@export var max_bullets_on_screen: int = 3

# -----------------------------
# INTERNAL RUNTIME STATE
# -----------------------------
var _fire_timer: float = 0.0
var _active_bullets: Array = []

var _facing_left := false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

var _dashing := false
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: int = 1

# -----------------------------
# NODE REFERENCES
# -----------------------------
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var anim: AnimationTree = get_node_or_null("AnimationTree")
@onready var muzzle: Marker2D = get_node_or_null("Muzzle")

# -----------------------------
# MAIN LOOP
# -----------------------------
func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_apply_gravity(delta)

	var horizontal_input := _read_input()
	_apply_horizontal(horizontal_input, delta)
	
	move_and_slide()

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

# -----------------------------
# GRAVITY
# -----------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor() and not _dashing:
		velocity.y += stats.gravity * delta
		
func _start_dash() -> void:
	if _dashing:
		return
	if _dash_cd > 0.0:
		return

	_dashing = true
	_dash_timer = stats.dash_time
	_dash_cd = stats.dash_cooldown

	# Enable dust and set direction
	if dust_trail:
		dust_trail.emitting = true

		

	# Dash direction
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

	# Jump activation
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

	# Shooting (abilities)
	if Input.is_action_just_pressed(prefix + "shoot"):
		if abilities != null:
			abilities.on_shoot_pressed(self)

	# Dash
	if Input.is_action_just_pressed(prefix + "dash"):
		_start_dash()

	var input_x := int(right_pressed) - int(left_pressed)
	return input_x

# -----------------------------
# DASH SYSTEM
# -----------------------------
'''func _start_dash() -> void:
	if _dashing:
		return
	if _dash_cd > 0.0:
		return

	_dashing = true
	_dash_timer = stats.dash_time
	_dash_cd = stats.dash_cooldown

	if _facing_left:
		_dash_dir = -1
	else:
		_dash_dir = 1

	velocity.x = float(_dash_dir) * stats.dash_speed'''

func _apply_horizontal(input_dir: int, delta: float) -> void:
	if _dashing:
		velocity.x = float(_dash_dir) * stats.dash_speed
		return

	var on_ground := is_on_floor()
	var target_speed := float(input_dir) * stats.max_speed
	var accel := stats.accel_air * stats.air_control

	if on_ground:
		accel = stats.accel_ground

	# Acceleration
	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		# Friction
		var fric := stats.friction_ground
		if not on_ground:
			fric = stats.friction_ground * 0.25
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

# -----------------------------
# FACING
# -----------------------------
func _update_facing() -> void:
	if absf(velocity.x) > 2.0:
		_facing_left = velocity.x < 0.0

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

	anim.set("parameters/StateMachine/conditions/idle", not moving and not airborne)
	anim.set("parameters/StateMachine/conditions/move", moving)
	anim.set("parameters/StateMachine/conditions/air", airborne)

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

	# MUST set position BEFORE add_child


	bullet.global_position = muzzle.global_position
	get_tree().current_scene.add_child(bullet)

	var dir_x := 1
	if _facing_left:
		dir_x = -1

	if bullet.has_method("set_owner_id"):
		bullet.set_owner_id(player_id)

	if bullet.has_method("set_direction_x"):
		bullet.set_direction_x(dir_x)

	_active_bullets.append(bullet)
	_fire_timer = fire_cooldown

# -----------------------------
# DAMAGE PLACEHOLDER
# -----------------------------
func apply_damage(_amount: int) -> void:
	# Hook for your health system
	pass
