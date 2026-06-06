extends CharacterBody2D
class_name Player

signal fired_bullet(bullet: Node)
signal died

@export var move_speed: float = 120.0
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

@export var punch_hitbox_scene: PackedScene
@export var punch_cooldown: float = 0.28
@export var punch_anim_duration: float = 0.18
@export var punch_offset_right: Vector2 = Vector2(16.0, -2.0)

@export var hitstun_duration: float = 0.14
@export var damage_invuln_duration: float = 0.30
@export var hit_friction: float = 700.0

@export var hit_flash_color: Color = Color(1.0, 1.0, 0.031, 0.671)
@export var hit_flash_count: int = 2
@export var hit_flash_interval: float = 0.25

@export var death_blink_duration: float = 0.60
@export var death_blink_interval: float = 0.1

@export var dash_speed: float = 240.0
@export var dash_time: float = 0.14
@export var dash_cooldown: float = 0.35
@export var allow_air_dash: bool = true
@export var dash_stops_vertical_velocity: bool = true

@export var wall_slide_speed: float = 60.0
@export var wall_jump_force: Vector2 = Vector2(240.0, -340.0)
@export var wall_jump_horizontal_lock_time: float = 0.12

@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.10
@export var jump_cut_multiplier: float = 0.5

@export var snap_visuals_to_pixel: bool = true

@export_group("Dust Trail")
@export var dust_trail_scene: PackedScene
@export var dash_dust_offset: Vector2 = Vector2(-12.0, 12.0)
@export var wall_slide_dust_offset: Vector2 = Vector2(8.0, -4.0)
@export var dust_spawn_interval: float = 0.08

@export_group("Special Assist")
@export var mattt_assist_scene: PackedScene
@export var special_meter_max: int = 100
@export var special_meter: int = 0
@export var mattt_spawn_offset: Vector2 = Vector2(-40.0, -20.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var health: Health = $Health

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _input_dir: float = 0.0
var control_locked: bool = false

var has_double_jump: bool = false
var has_wall_slide: bool = false
var has_charge_shot: bool = false
var _punch_timer: float = 0.0
var _punch_anim_timer: float = 0.0

var _is_dead: bool = false
var _is_dying: bool = false
var _is_hit_flashing: bool = false

var _hitstun_timer: float = 0.0
var _invuln_timer: float = 0.0

var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _has_air_dashed: bool = false

var _is_wall_sliding: bool = false
var _wall_dir: int = 0
var _wall_jump_lock_timer: float = 0.0

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false

var _dust_spawn_timer: float = 0.0
var _sprite_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_sprite_base_position = sprite.position

	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)

	_update_muzzle_position()
	_snap_visuals_to_pixel()


func _physics_process(delta: float) -> void:
	if control_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if _is_dead:
		return

	_capture_jump_input()
	_update_timers(delta)
	_refresh_floor_state()

	if _hitstun_timer > 0.0:
		_process_hitstun(delta)
	else:
		_process_normal_movement(delta)

	move_and_slide()

	_cleanup_after_move()
	_update_facing()
	_update_animation()
	_snap_visuals_to_pixel()
	_handle_dust_trail(delta)

	_was_on_floor = is_on_floor()


func _capture_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _update_timers(delta: float) -> void:
	_fire_timer = max(_fire_timer - delta, 0.0)
	_shoot_anim_timer = max(_shoot_anim_timer - delta, 0.0)
	_hitstun_timer = max(_hitstun_timer - delta, 0.0)
	_invuln_timer = max(_invuln_timer - delta, 0.0)
	_dash_timer = max(_dash_timer - delta, 0.0)
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)
	_wall_jump_lock_timer = max(_wall_jump_lock_timer - delta, 0.0)
	_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
	_dust_spawn_timer = max(_dust_spawn_timer - delta, 0.0)
	_punch_timer = max(_punch_timer - delta, 0.0)
	_punch_anim_timer = max(_punch_anim_timer - delta, 0.0)


func _refresh_floor_state() -> void:
	if is_on_floor():
		_has_air_dashed = false
		_coyote_timer = coyote_time
	elif _was_on_floor:
		_coyote_timer = coyote_time


func _process_hitstun(delta: float) -> void:
	_input_dir = 0.0
	_is_dashing = false
	_is_wall_sliding = false

	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, hit_friction * delta)


func _process_normal_movement(delta: float) -> void:
	_handle_dash()
	_handle_punch()
	_handle_shoot()
	_handle_wall_slide()
	_apply_gravity(delta)
	_handle_jump()
	_handle_special_assist()
	_handle_variable_jump_height()
	_handle_horizontal_movement(delta)


func _handle_dash() -> void:
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

	if allow_air_dash and not _has_air_dashed:
		return true

	return false


func _start_dash() -> void:
	_is_dashing = true
	_dash_timer = dash_time
	_shoot_anim_timer = 0.0
	_is_wall_sliding = false
	_wall_dir = 0

	var dir := _get_facing_sign_from_input()
	velocity.x = float(dir) * dash_speed

	if dash_stops_vertical_velocity:
		velocity.y = 0.0

	if not is_on_floor():
		_has_air_dashed = true

	_spawn_dust_trail(dash_dust_offset, &"dash")
	_dust_spawn_timer = dust_spawn_interval


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

	if not is_on_wall_only():
		return

	var wall_input := Input.get_axis("move_left", "move_right")
	if wall_input == 0.0:
		return

	_wall_dir = int(sign(wall_input))
	_is_wall_sliding = true
	_coyote_timer = 0.0


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
		return

	if velocity.y > 0.0:
		velocity.y = 0.0


func _handle_jump() -> void:
	if _jump_buffer_timer <= 0.0:
		return

	if _is_wall_sliding:
		_wall_jump()
		_jump_buffer_timer = 0.0
		return

	if is_on_floor() or _coyote_timer > 0.0:
		_do_jump()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _do_jump() -> void:
	if _is_dashing:
		_end_dash()

	velocity.y = jump_velocity
	_is_wall_sliding = false
	_wall_dir = 0


func _wall_jump() -> void:
	var jump_dir := -_wall_dir

	if jump_dir == 0:
		if _facing_left:
			jump_dir = 1
		else:
			jump_dir = -1

	velocity.x = float(jump_dir) * wall_jump_force.x
	velocity.y = wall_jump_force.y

	_is_wall_sliding = false
	_wall_dir = 0
	_wall_jump_lock_timer = wall_jump_horizontal_lock_time
	_facing_left = jump_dir < 0

	_spawn_dust_trail(wall_slide_dust_offset, &"wall_slide")


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
		var accel := acceleration

		if not is_on_floor():
			accel = air_acceleration

		velocity.x = move_toward(velocity.x, _input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_just_pressed("shoot"):
		return

	if not _can_shoot():
		return

	_spawn_bullet()


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

	var direction := Vector2.RIGHT

	if _facing_left:
		direction = Vector2.LEFT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)


func _handle_punch() -> void:
	if not Input.is_action_just_pressed("punch"):
		return

	if not _can_punch():
		return

	_spawn_punch_hitbox()


func _can_punch() -> bool:
	if _is_dead or _is_dying:
		return false

	if _hitstun_timer > 0.0:
		return false

	if _punch_timer > 0.0:
		return false

	if punch_hitbox_scene == null:
		push_warning("Player punch_hitbox_scene is not assigned.")
		return false

	return true


func _spawn_punch_hitbox() -> void:
	var punch := punch_hitbox_scene.instantiate() as Area2D
	if punch == null:
		return

	_punch_timer = punch_cooldown
	_punch_anim_timer = punch_anim_duration
	_shoot_anim_timer = 0.0

	get_parent().add_child(punch)

	var x_offset := punch_offset_right.x
	if _facing_left:
		x_offset = -punch_offset_right.x

	punch.global_position = global_position + Vector2(x_offset, punch_offset_right.y)

	if punch.has_method("setup"):
		punch.setup(self, _facing_left)


func _handle_special_assist() -> void:
	if not Input.is_action_just_pressed("special"):
		return

	if special_meter < special_meter_max:
		return

	if mattt_assist_scene == null:
		return

	special_meter = special_meter_max

	var assist := mattt_assist_scene.instantiate() as Node2D
	if assist == null:
		return

	get_parent().add_child(assist)

	var x_offset := mattt_spawn_offset.x

	if _facing_left:
		x_offset = -mattt_spawn_offset.x

	assist.global_position = global_position + Vector2(x_offset, mattt_spawn_offset.y)

	if assist.has_method("setup"):
		assist.setup(self, _facing_left)


@warning_ignore("unused_parameter")
func _handle_dust_trail(delta: float) -> void:
	if dust_trail_scene == null:
		return

	if _dust_spawn_timer > 0.0:
		return

	if _is_dashing:
		_spawn_dust_trail(dash_dust_offset, &"dash")
		_dust_spawn_timer = dust_spawn_interval
		return

	if _is_wall_sliding:
		_spawn_wall_slide_dust()
		_dust_spawn_timer = dust_spawn_interval


func _spawn_wall_slide_dust() -> void:
	var offset := wall_slide_dust_offset

	if _wall_dir < 0:
		offset.x = -absf(wall_slide_dust_offset.x)
	elif _wall_dir > 0:
		offset.x = absf(wall_slide_dust_offset.x)

	_spawn_dust_trail(offset, &"wall_slide")


func _spawn_dust_trail(offset: Vector2, animation_name: StringName = &"dash") -> void:
	if dust_trail_scene == null:
		return

	var dust := dust_trail_scene.instantiate() as Node2D
	if dust == null:
		return

	get_parent().add_child(dust)

	var facing_multiplier: float = 1.0
	if _facing_left:
		facing_multiplier = -1.0

	var final_offset := Vector2(offset.x * facing_multiplier, offset.y)

	if animation_name == &"wall_slide":
		final_offset = offset

	dust.global_position = global_position + final_offset

	if dust.has_method("setup"):
		dust.setup(not _facing_left, animation_name)


func _cleanup_after_move() -> void:
	if is_on_floor():
		_is_wall_sliding = false
		_wall_dir = 0
		_has_air_dashed = false

		if _is_dashing and _dash_timer <= 0.0:
			_is_dashing = false

	if _is_dashing and _dash_timer <= 0.0:
		_end_dash()


func _update_facing() -> void:
	if sprite == null:
		return

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
	if muzzle == null:
		return

	var x_offset := muzzle_offset_right.x

	if _facing_left:
		x_offset = -muzzle_offset_right.x

	muzzle.position = Vector2(x_offset, muzzle_offset_right.y)


func _update_animation() -> void:
	if sprite == null:
		return

	if _is_dead:
		_play_animation_if_available("death")
		return

	if _is_dashing:
		_play_animation_with_fallback("dash", "run")
		return

	if _is_wall_sliding:
		_play_animation_with_fallback("wall_slide", "fall")
		return

	var is_shooting := _shoot_anim_timer > 0.01
	var is_running := absf(velocity.x) > 8.0
	var is_punching := _punch_anim_timer > 0.01

	if is_punching:
		if not is_on_floor():
			_play_animation_with_fallback("punch_C", "jump")
		else:
			_play_animation_with_fallback("punch_C", "idle")
		return

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
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_animation_with_fallback(anim_name: String, fallback_name: String) -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		return

	if sprite.sprite_frames.has_animation(fallback_name):
		if sprite.animation != fallback_name:
			sprite.play(fallback_name)


func _snap_visuals_to_pixel() -> void:
	if not snap_visuals_to_pixel:
		return

	if sprite == null:
		return

	sprite.position = _sprite_base_position.round()


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

	if sprite != null:
		sprite.flip_h = _facing_left

	_update_muzzle_position()

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

	call_deferred("_run_death_blink")


func _run_hit_flash() -> void:
	if _is_dead or _is_dying:
		return

	var target: CanvasItem = sprite

	if target == null:
		target = self

	_is_hit_flashing = true
	var normal := target.modulate

	for i in range(hit_flash_count):
		if not is_instance_valid(target):
			break

		if _is_dead or _is_dying:
			break

		target.modulate = hit_flash_color
		await get_tree().create_timer(hit_flash_interval).timeout

		if not is_instance_valid(target):
			break

		if _is_dead or _is_dying:
			break

		target.modulate = normal
		await get_tree().create_timer(hit_flash_interval).timeout

	if is_instance_valid(target):
		if not _is_dead and not _is_dying:
			target.modulate = normal

	_is_hit_flashing = false


func _run_death_blink() -> void:
	var target: CanvasItem = sprite

	if target == null:
		target = self

	var elapsed: float = 0.0
	var visible_state: bool = false

	while elapsed < death_blink_duration and is_instance_valid(target):
		visible_state = not visible_state

		var c := target.modulate

		if visible_state:
			c.a = 0.2
		else:
			c.a = 1.0

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

	if _facing_left:
		return -1

	return 1
func set_control_locked(value: bool) -> void:
	control_locked = value
	velocity = Vector2.ZERO


func apply_upgrade(upgrade_name: StringName) -> void:
	if upgrade_name == &"double_jump":
		has_double_jump = true
		print("Upgrade acquired: Double Jump")

	elif upgrade_name == &"wall_slide":
		has_wall_slide = true
		print("Upgrade acquired: Wall Slide")

	elif upgrade_name == &"charge_shot":
		has_charge_shot = true
		print("Upgrade acquired: Charge Shot")
