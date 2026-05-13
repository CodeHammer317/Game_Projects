extends CharacterBody2D
class_name PlayerBase

@export var player_id: int = 1
@export var stats: PlayerStats
@export var abilities: AbilitySet
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.2
@export var max_bullets_on_screen: int = 3

@export var max_health: int = 5
@export var invuln_time: float = 0.25
@export var hurt_knockback: Vector2 = Vector2(140.0, -180.0)

@export var shoot_pose_time: float = 0.12
@export var attack_pose_time: float = 0.18

const WALL_SLIDE_SPEED: float = 60.0
const WALL_JUMP_PUSH: float = 260.0
const WALL_JUMP_LOCK_TIME: float = 0.12

var _fire_timer: float = 0.0
var _active_bullets: Array = []

var _facing_left: bool = false
var _input_x: int = 0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

var _dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: int = 1

var _is_wall_sliding: bool = false
var _is_wall_jumping: bool = false
var _wall_jump_lock_timer: float = 0.0

var _shoot_pose_timer: float = 0.0
var _attack_pose_timer: float = 0.0

var input_device: int = -1
var current_health: int = 0
var _is_dead: bool = false
var _invuln_timer: float = 0.0

@onready var pose_idle: Sprite2D = $Poses/Idle
@onready var pose_run: Sprite2D = $Poses/Run
@onready var pose_dash: Sprite2D = $Poses/Dash
@onready var pose_wall_slide: Sprite2D = $Poses/WallSlide
@onready var pose_wall_jump: Sprite2D = $Poses/WallJump
@onready var pose_shoot: Sprite2D = $Poses/Shoot
@onready var pose_attack: Sprite2D = $Poses/Attack
@onready var pose_jump: Sprite2D = $Poses/Jump
@onready var pose_falling: Sprite2D = $Poses/Falling
@onready var muzzle: Marker2D = get_node_or_null("Sockets/Muzzle")
@onready var dust_trail: CPUParticles2D = get_node_or_null("DustTrail")


func _ready() -> void:
	if PlayerManager:
		PlayerManager.register_player(self, player_id)

	input_device = player_id
	current_health = max_health
	_hide_all_poses()

	if pose_idle != null:
		pose_idle.visible = true


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_read_input()
	_apply_gravity(delta)
	_apply_horizontal(delta)

	move_and_slide()

	_cleanup_after_move()
	_update_wall_state()
	_update_facing()
	_update_pose_visibility()
	_cleanup_bullet_list()

	if abilities != null:
		abilities.tick(self, delta)


func _get_input_prefix() -> String:
	if player_id == 2:
		return "p2_"

	return "p1_"


func _update_timers(delta: float) -> void:
	_fire_timer = max(_fire_timer - delta, 0.0)
	_invuln_timer = max(_invuln_timer - delta, 0.0)
	_dash_cd = max(_dash_cd - delta, 0.0)
	_dash_timer = max(_dash_timer - delta, 0.0)
	_wall_jump_lock_timer = max(_wall_jump_lock_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	_shoot_pose_timer = max(_shoot_pose_timer - delta, 0.0)
	_attack_pose_timer = max(_attack_pose_timer - delta, 0.0)

	if is_on_floor():
		_coyote_timer = stats.coyote_time
		_is_wall_jumping = false
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if _dashing and _dash_timer <= 0.0:
		_end_dash()


func _read_input() -> void:
	var prefix := _get_input_prefix()

	var left_pressed := Input.is_action_pressed(prefix + "left")
	var right_pressed := Input.is_action_pressed(prefix + "right")

	_input_x = 0

	if right_pressed:
		_input_x += 1

	if left_pressed:
		_input_x -= 1

	if Input.is_action_just_pressed(prefix + "jump"):
		_jump_buffer_timer = stats.jump_buffer
		_try_wall_jump()

	if _jump_buffer_timer > 0.0:
		_try_ground_jump()

	if Input.is_action_just_released(prefix + "jump") and velocity.y < 0.0:
		velocity.y *= stats.variable_jump_cut

	if Input.is_action_just_pressed(prefix + "attack"):
		_attack_pose_timer = attack_pose_time

		if abilities != null:
			abilities.on_attack_pressed(self)

	if Input.is_action_just_pressed(prefix + "heavey_attack"):
		_attack_pose_timer = attack_pose_time

		if abilities != null:
			abilities.on_attack_pressed(self)

	if Input.is_action_just_pressed(prefix + "shoot"):
		_try_shoot()

	if Input.is_action_just_pressed(prefix + "dash"):
		_start_dash()


func _try_ground_jump() -> void:
	if is_on_floor() or _coyote_timer > 0.0:
		velocity.y = stats.jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_wall_sliding = false
		_is_wall_jumping = false

		if _dashing:
			_end_dash()


func _try_wall_jump() -> void:
	if is_on_floor():
		return

	if _dashing:
		return

	if not is_on_wall():
		return

	var wall_normal := get_wall_normal()
	var pressing_into_left_wall := _input_x < 0 and wall_normal.x > 0.0
	var pressing_into_right_wall := _input_x > 0 and wall_normal.x < 0.0

	if pressing_into_left_wall or pressing_into_right_wall:
		_perform_wall_jump()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _apply_gravity(delta: float) -> void:
	if _dashing:
		velocity.y = 0.0
		return

	if _is_wall_sliding:
		velocity.y += stats.gravity * delta
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)
		return

	if not is_on_floor():
		velocity.y += stats.gravity * delta
		return

	if velocity.y > 0.0:
		velocity.y = 0.0


func _apply_horizontal(delta: float) -> void:
	if _dashing:
		velocity.x = float(_dash_dir) * stats.dash_speed
		return

	if _wall_jump_lock_timer > 0.0:
		return

	var target_speed := float(_input_x) * stats.max_speed
	var accel := stats.accel_air * stats.air_control

	if is_on_floor():
		accel = stats.accel_ground

	if absf(target_speed) > 0.01:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		var fric := stats.friction_ground

		if not is_on_floor():
			fric *= 0.25

		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _start_dash() -> void:
	if _dashing:
		return

	if _dash_cd > 0.0:
		return

	_dashing = true
	_dash_timer = stats.dash_time
	_dash_cd = stats.dash_cooldown
	_is_wall_sliding = false
	_is_wall_jumping = false
	_shoot_pose_timer = 0.0
	_attack_pose_timer = 0.0

	if _facing_left:
		_dash_dir = -1
	else:
		_dash_dir = 1

	velocity.x = float(_dash_dir) * stats.dash_speed
	velocity.y = 0.0

	if dust_trail != null:
		dust_trail.emitting = true


func _end_dash() -> void:
	_dashing = false
	_dash_timer = 0.0

	if dust_trail != null:
		dust_trail.emitting = false


func _update_wall_state() -> void:
	_is_wall_sliding = false

	if is_on_floor():
		return

	if _dashing:
		return

	if velocity.y < 0.0:
		return

	if not is_on_wall_only():
		return

	var wall_normal := get_wall_normal()

	if wall_normal.x > 0.0 and _input_x < 0:
		_is_wall_sliding = true
	elif wall_normal.x < 0.0 and _input_x > 0:
		_is_wall_sliding = true

	if _is_wall_sliding:
		_is_wall_jumping = false
		velocity.x = 0.0

		if velocity.y > WALL_SLIDE_SPEED:
			velocity.y = WALL_SLIDE_SPEED


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

	if dust_trail != null:
		dust_trail.emitting = false


func _try_shoot() -> void:
	_shoot_pose_timer = shoot_pose_time

	if abilities != null:
		abilities.on_shoot_pressed(self)
	else:
		spawn_bullet()


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

	var dir := Vector2.RIGHT

	if _facing_left:
		dir = Vector2.LEFT

	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet is Projectile:
		bullet.team = 1
		bullet.launch(dir, null, self)
	elif bullet.has_method("launch"):
		bullet.launch(dir)

	_active_bullets.append(bullet)
	_fire_timer = fire_cooldown


func _cleanup_after_move() -> void:
	if is_on_floor():
		_is_wall_sliding = false
		_is_wall_jumping = false

	if _dashing and _dash_timer <= 0.0:
		_end_dash()


func _update_facing() -> void:
	if absf(velocity.x) > 2.0:
		if velocity.x < 0.0:
			_facing_left = true
		elif velocity.x > 0.0:
			_facing_left = false

	var poses_node := get_node_or_null("Poses")
	if poses_node != null:
		for pose in poses_node.get_children():
			if pose is Sprite2D:
				pose.flip_h = _facing_left

	if muzzle != null and muzzle.has_method("set_facing_left"):
		muzzle.set_facing_left(_facing_left)


func _hide_all_poses() -> void:
	var poses_node := get_node_or_null("Poses")
	if poses_node == null:
		return

	for pose in poses_node.get_children():
		if pose is Sprite2D:
			pose.visible = false


func _update_pose_visibility() -> void:
	_hide_all_poses()

	if _attack_pose_timer > 0.0 and pose_attack != null:
		pose_attack.visible = true
		return

	if _shoot_pose_timer > 0.0 and pose_shoot != null:
		pose_shoot.visible = true
		return

	if _is_wall_jumping and pose_wall_jump != null:
		pose_wall_jump.visible = true
		return

	if _is_wall_sliding and pose_wall_slide != null:
		pose_wall_slide.visible = true
		return

	if _dashing and pose_dash != null:
		pose_dash.visible = true
		return

	if not is_on_floor():
		if velocity.y < -6.0 and pose_jump != null:
			pose_jump.visible = true
			return

		if velocity.y >= -6.0 and pose_falling != null:
			pose_falling.visible = true
			return

	if absf(velocity.x) > 6.0 and is_on_floor() and pose_run != null:
		pose_run.visible = true
		return

	if pose_idle != null:
		pose_idle.visible = true


func _cleanup_bullet_list() -> void:
	for i in range(_active_bullets.size() - 1, -1, -1):
		if not is_instance_valid(_active_bullets[i]):
			_active_bullets.remove_at(i)


func apply_damage(amount: int, knockback: Vector2 = Vector2.ZERO, instigator: Node = null) -> void:
	if _is_dead:
		return

	if amount <= 0:
		return

	if _invuln_timer > 0.0:
		return

	current_health -= amount
	current_health = max(current_health, 0)

	_invuln_timer = invuln_time
	_apply_damage(knockback, instigator)
	_flash_hurt()

	if current_health <= 0:
		_die()


func _apply_damage(knockback: Vector2 = Vector2.ZERO, instigator: Node = null) -> void:
	_shoot_pose_timer = 0.0
	_attack_pose_timer = 0.0
	_dashing = false
	_dash_timer = 0.0
	_is_wall_sliding = false
	_is_wall_jumping = false
	_wall_jump_lock_timer = 0.0

	if dust_trail != null:
		dust_trail.emitting = false

	var final_knockback := knockback

	if final_knockback == Vector2.ZERO:
		var hit_dir := -1.0

		if instigator != null and instigator is Node2D:
			hit_dir = sign(global_position.x - instigator.global_position.x)

			if hit_dir == 0.0:
				if _facing_left:
					hit_dir = -1.0
				else:
					hit_dir = 1.0
		else:
			if _facing_left:
				hit_dir = -1.0
			else:
				hit_dir = 1.0

		final_knockback = Vector2(hurt_knockback.x * hit_dir, hurt_knockback.y)

	velocity = final_knockback


func _flash_hurt() -> void:
	modulate = Color(1.35, 0.4, 0.4, 1.0)

	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and not _is_dead:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _die() -> void:
	_is_dead = true
	_shoot_pose_timer = 0.0
	_attack_pose_timer = 0.0
	_dashing = false
	_is_wall_sliding = false
	_is_wall_jumping = false
	velocity = Vector2.ZERO
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	queue_free()


func _on_heavy_attack() -> void:
	_attack_pose_timer = attack_pose_time
