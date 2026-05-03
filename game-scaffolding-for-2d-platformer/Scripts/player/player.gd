extends CharacterBody2D
class_name Player

signal fired_bullet(bullet: Node)
signal died

@export var move_speed: float = 145.0
@export var acceleration: float = 900.0
@export var air_acceleration: float = 700.0
@export var friction: float = 1000.0

@export var jump_velocity: float = -300.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0

@export var fire_cooldown: float = 0.18
@export var shoot_anim_duration: float = 0.10
@export var bullet_scene: PackedScene

@export var muzzle_offset_right: Vector2 = Vector2(10.0, -2.0)

@export var hitstun_duration: float = 0.14
@export var damage_invuln_duration: float = 0.30
@export var hit_friction: float = 700.0

@export var hit_flash_color: Color = Color(1.0, 1.0, 0.031, 0.671)
@export var hit_flash_count: int = 2
@export var hit_flash_interval: float = 0.25

@export var death_blink_duration: float = 0.60
@export var death_blink_interval: float = 0.1

# --- DASH ---
@export var dash_speed: float = 260.0
@export var dash_time: float = 0.14
@export var dash_cooldown: float = 0.35
@export var allow_air_dash: bool = true
@export var dash_stops_vertical_velocity: bool = true

# --- WALL MOVEMENT ---
@export var wall_slide_speed: float = 55.0
@export var wall_jump_force: Vector2 = Vector2(220.0, -340.0)
@export var wall_jump_horizontal_lock_time: float = 0.12

# --- JUMP FEEL ---
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.10
@export var jump_cut_multiplier: float = 0.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var health: Health = $Health

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _is_dead: bool = false
var _input_dir: float = 0.0

var _hitstun_timer: float = 0.0
var _invuln_timer: float = 0.0
var _is_dying: bool = false
var _is_hit_flashing: bool = false

# --- DASH STATE ---
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _has_air_dashed: bool = false

# --- WALL STATE ---
var _is_wall_sliding: bool = false
var _wall_dir: int = 0 # -1 = left wall, 1 = right wall
var _wall_jump_lock_timer: float = 0.0

# --- JUMP FEEL STATE ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	#print("hitstun: ", _hitstun_timer, " dead: ", _is_dead, " dying: ", _is_dying)
	_capture_jump_input()
	_update_timers(delta)
	_refresh_floor_state()
	_handle_dash(delta)

	if _hitstun_timer > 0.0:
		_apply_gravity(delta)
		_handle_hitstun(delta)
	else:
		_handle_shoot()
		_handle_wall_slide()
		_apply_gravity(delta)
		_handle_jump()
		_handle_variable_jump_height()
		_handle_horizontal_movement(delta)
		
		_update_facing()

	move_and_slide()
	_was_on_floor = is_on_floor()
	_update_animation()


func _capture_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _update_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = max(_fire_timer - delta, 0.0)

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer = max(_shoot_anim_timer - delta, 0.0)

	if _hitstun_timer > 0.0:
		_hitstun_timer = max(_hitstun_timer - delta, 0.0)

	if _invuln_timer > 0.0:
		_invuln_timer = max(_invuln_timer - delta, 0.0)

	if _dash_timer > 0.0:
		_dash_timer = max(_dash_timer - delta, 0.0)

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)

	if _wall_jump_lock_timer > 0.0:
		_wall_jump_lock_timer = max(_wall_jump_lock_timer - delta, 0.0)

	if _coyote_timer > 0.0:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)


func _refresh_floor_state() -> void:
	if is_on_floor():
		_has_air_dashed = false
		_coyote_timer = coyote_time
	elif _was_on_floor and not is_on_floor():
		_coyote_timer = coyote_time


func _apply_gravity(delta: float) -> void:
	if _is_dashing and dash_stops_vertical_velocity:
		velocity.y = 0.0
		return

	if _is_wall_sliding:
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, wall_slide_speed)
		return

	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_hitstun(delta: float) -> void:
	_input_dir = 0.0
	velocity.x = move_toward(velocity.x, 0.0, hit_friction * delta)


func _handle_dash(delta: float) -> void:
	if _is_dashing:
		if _dash_timer <= 0.0:
			_end_dash()
		return

	if Input.is_action_just_pressed("dash") and _can_start_dash():
		_start_dash()


func _can_start_dash() -> bool:
	if _is_dead or _is_dying:
		return false

	if _hitstun_timer > 0.0:
		return false

	if _dash_cooldown_timer > 0.0:
		return false

	if is_on_floor():
		return true

	return allow_air_dash and not _has_air_dashed


func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = dash_time
	_shoot_anim_timer = 0.0
	_is_wall_sliding = false
	_wall_dir = 0

	var dir: int = _get_facing_sign_from_input()
	velocity.x = dir * dash_speed

	if dash_stops_vertical_velocity:
		velocity.y = 0.0

	if not is_on_floor():
		_has_air_dashed = true


func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	_dash_cooldown_timer = dash_cooldown


func _handle_wall_slide() -> void:
	_is_wall_sliding = false
	_wall_dir = 0

	if _is_dashing:
		return

	if is_on_floor():
		return

	if velocity.y < 0.0:
		return

	if not is_on_wall():
		return

	var wall_input := Input.get_axis("move_left", "move_right")
	if wall_input == 0.0:
		return

	var input_sign := int(sign(wall_input))
	if input_sign == 0:
		return

	_wall_dir = input_sign

	if is_on_wall_only():
		_is_wall_sliding = true
		_coyote_timer = 0.0


func _handle_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if _is_dashing:
		_end_dash()

	if _is_wall_sliding:
		_wall_jump()
		_jump_buffer_timer = 0.0
		return

	if is_on_floor() or _coyote_timer > 0.0:
		_do_jump()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _do_jump() -> void:
	velocity.y = jump_velocity
	_is_wall_sliding = false
	_wall_dir = 0


func _wall_jump() -> void:
	var jump_dir := -_wall_dir
	if jump_dir == 0:
		jump_dir = 1 if _facing_left else -1

	velocity.x = jump_dir * wall_jump_force.x
	velocity.y = wall_jump_force.y

	_is_wall_sliding = false
	_wall_dir = 0
	_wall_jump_lock_timer = wall_jump_horizontal_lock_time
	_facing_left = jump_dir < 0


func _handle_variable_jump_height() -> void:
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_horizontal_movement(delta: float) -> void:
	if _is_dashing:
		return

	_input_dir = Input.get_axis("move_left", "move_right")

	if _wall_jump_lock_timer > 0.0:
		return

	if _input_dir != 0.0:
		var accel := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, _input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if Input.is_action_just_pressed("shoot"):
		print("SHOOT INPUT DETECTED")

	if not Input.is_action_just_pressed("shoot"):
		return

	if _fire_timer > 0.0:
		print("SHOT BLOCKED: fire cooldown")
		return

	if _hitstun_timer > 0.0:
		print("SHOT BLOCKED: hitstun")
		return

	if bullet_scene == null:
		print("SHOT BLOCKED: bullet_scene is null")
		push_warning("Player bullet_scene is not assigned.")
		return

	if muzzle == null:
		print("SHOT BLOCKED: muzzle is null")
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		print("SHOT BLOCKED: bullet failed to instantiate")
		return

	print("BULLET INSTANTIATED")

	_fire_timer = fire_cooldown
	_shoot_anim_timer = shoot_anim_duration

	var direction := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	print("BULLET ADDED AT: ", bullet.global_position)

	if bullet.has_method("setup"):
		print("CALLING BULLET SETUP")
		bullet.setup(direction, self)
	else:
		print("BULLET HAS NO SETUP METHOD")

	fired_bullet.emit(bullet)
	print("SHOT COMPLETE")

func _update_facing() -> void:
	if _is_dashing:
		sprite.flip_h = _facing_left
		_update_muzzle_position()
		return

	if _input_dir < 0.0:
		_facing_left = true
	elif _input_dir > 0.0:
		_facing_left = false

	sprite.flip_h = _facing_left
	_update_muzzle_position()


func _update_muzzle_position() -> void:
	if muzzle != null:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)


func _update_animation() -> void:
	if _is_dead:
		_play_animation_if_available("death")
		return

	if _is_dashing:
		_play_animation_with_fallback("dash", "run")
		return

	if _is_wall_sliding:
		_play_animation_with_fallback("wall_slide", "fall")
		return

	var is_shooting := _shoot_anim_timer > 0.0
	var is_running := absf(velocity.x) > 8.0

	if not is_on_floor():
		if velocity.y < 0.0:
			if is_shooting:
				_play_animation_with_fallback("shoot_jump", "jump")
			else:
				_play_animation_if_available("jump")
		else:
			if is_shooting:
				_play_animation_with_fallback("shoot_fall", "fall")
			else:
				_play_animation_if_available("fall")
		return

	if is_running:
		if is_shooting:
			_play_animation_with_fallback("shoot_run", "run")
		else:
			_play_animation_if_available("run")
	else:
		if is_shooting:
			_play_animation_with_fallback("shoot_idle", "idle")
		else:
			_play_animation_if_available("idle")


func _play_animation_if_available(anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)


func _play_animation_with_fallback(anim_name: String, fallback_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation(fallback_name):
		if sprite.animation != fallback_name:
			sprite.play(fallback_name)


func apply_damage(info: DamageInfo) -> void:
	if _is_dead or _is_dying:
		return

	if _invuln_timer > 0.0:
		return

	if health == null:
		push_warning("Player has no Health node.")
		return

	health.apply_damage(info)


func _on_damaged(info: DamageInfo) -> void:
	if _is_dead or _is_dying:
		return

	_is_dashing = false
	_is_wall_sliding = false
	_dash_timer = 0.0
	_wall_dir = 0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0

	_hitstun_timer = hitstun_duration
	_invuln_timer = damage_invuln_duration
	_shoot_anim_timer = 0.0

	if info != null:
		velocity += info.knockback

	sprite.flip_h = _facing_left
	_update_muzzle_position()

	CombatFX.hitstop(0.035, 0.08)
	CombatFX.shake(3.5, 0.10, 28.0)

	if not _is_hit_flashing:
		call_deferred("_run_hit_flash")


func _on_health_died() -> void:
	kill()


func is_facing_left() -> bool:
	return _facing_left


func kill() -> void:
	if _is_dead or _is_dying:
		return

	_is_dead = true
	_is_dying = true
	_is_dashing = false
	_is_wall_sliding = false
	_hitstun_timer = 0.0
	_invuln_timer = 0.0
	_fire_timer = 0.0
	_shoot_anim_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	velocity = Vector2.ZERO

	_play_animation_if_available("death")
	died.emit()
	CombatFX.hitstop(0.06, 0.04)
	CombatFX.shake(6.0, 0.18, 22.0)
	call_deferred("_run_death_blink")


func _run_hit_flash() -> void:
	if _is_dead or _is_dying:
		return

	var target: CanvasItem = sprite if sprite != null else self
	if target == null:
		return

	_is_hit_flashing = true
	var normal := target.modulate

	for i in range(hit_flash_count):
		if not is_instance_valid(target) or _is_dead or _is_dying:
			break

		target.modulate = hit_flash_color
		await get_tree().create_timer(hit_flash_interval).timeout

		if not is_instance_valid(target) or _is_dead or _is_dying:
			break

		target.modulate = normal
		await get_tree().create_timer(hit_flash_interval).timeout

	if is_instance_valid(target) and not _is_dead and not _is_dying:
		target.modulate = normal

	_is_hit_flashing = false


func _run_death_blink() -> void:
	var target: CanvasItem = sprite if sprite != null else self
	if target == null:
		queue_free()
		return

	var elapsed: float = 0.0
	var visible_state: bool = false

	while elapsed < death_blink_duration and is_instance_valid(target):
		visible_state = not visible_state

		var c := target.modulate
		c.a = 0.2 if visible_state else 1.0
		target.modulate = c

		await get_tree().create_timer(death_blink_interval).timeout
		elapsed += death_blink_interval

	if is_instance_valid(target):
		var reset_color := target.modulate
		reset_color.a = 1.0
		target.modulate = reset_color

	queue_free()


func _get_facing_sign_from_input() -> int:
	if _input_dir < 0.0:
		return -1
	if _input_dir > 0.0:
		return 1
	return -1 if _facing_left else 1
func _can_shoot() -> bool:
	if _is_dead or _is_dying:
		return false

	if _hitstun_timer > 0.0:
		return false

	if _fire_timer > 0.0:
		return false

	if bullet_scene == null:
		push_warning("Player bullet_scene is not assigned.")
		return false

	if muzzle == null:
		push_warning("Player muzzle node is missing.")
		return false

	return true



func _spawn_bullet() -> void:
	var bullet := bullet_scene.instantiate()
	if bullet == null:
		push_warning("Failed to instantiate bullet_scene.")
		return

	_fire_timer = fire_cooldown
	_shoot_anim_timer = shoot_anim_duration

	var direction := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)
