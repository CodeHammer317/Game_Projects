extends CharacterBody2D
class_name Player

signal fired_bullet(bullet: Node)
signal shot_charge_changed(ratio: float, charging: bool)
signal died
signal game_over


@export var move_speed: float = 200.0
@export var acceleration: float = 900.0
@export var air_acceleration: float = 700.0
@export var friction: float = 1000.0

@export var jump_velocity: float = -350.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0

@export var fire_cooldown: float = 0.18
@export var shoot_anim_duration: float = 0.10
@export var bullet_scene: PackedScene
@export var muzzle_offset_right: Vector2 = Vector2(20.0, -4.0)

@export_group("Charged Throw")
@export var minimum_charge_time: float = 0.0
@export var maximum_charge_time: float = 1.0

@export_group("Attack Combo")
@export var attack_action: StringName = &"attack"
@export var attack_hitbox_scene: PackedScene
@export var attack_cooldown: float = 0.18
@export var attack_anim_lock_time: float = 0.22
@export var combo_timeout: float = 0.45
@export var aerial_attack_cooldown: float = 0.18
@export var attack_offset_right: Vector2 = Vector2(40.0, -6.0)

@export var hitstun_duration: float = 0.14
@export var damage_invuln_duration: float = 0.30
@export var hit_friction: float = 700.0

@export var hit_flash_color: Color = Color(2.181, 1.907, 1.283, 0.863)
@export var hit_flash_count: int = 2
@export var hit_flash_interval: float = 0.25

@export var death_blink_duration: float = 0.60
@export var death_blink_interval: float = 0.1

@export_group("Respawn")
@export var max_deaths_before_game_over: int = 3
@export var respawn_invuln_duration: float = 2.0
@export var respawn_flash_interval: float = 0.12
@export var restore_health_on_respawn: bool = true

@export var dash_speed: float = 350.0
@export var dash_time: float = 0.20
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
@export var special_meter: int = 100
@export var mattt_spawn_offset: Vector2 = Vector2(-40.0, -20.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var health: Health = $Health

var ground_combo: Array[StringName] = [
	&"left_punch",
	&"right_punch",
	&"roundhouse_kick",
	&"side_kick"
]

var aerial_attacks: Array[StringName] = [
	&"flying_side_kick",
	&"flying_spin_kick"
]

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _charge_time: float = 0.0
var _is_charging_shot: bool = false
var _input_dir: float = 0.0
var control_locked: bool = false

var has_double_jump: bool = false
var has_wall_slide: bool = false
var has_charge_shot: bool = false

var _attack_timer: float = 0.0
var _attack_anim_timer: float = 0.0
var _combo_timer: float = 0.0
var _combo_index: int = 0
var _aerial_attack_timer: float = 0.0
var _last_aerial_attack: StringName = &""

var _is_dead: bool = false
var _is_dying: bool = false
var _is_game_over: bool = false
var _is_hit_flashing: bool = false
var _is_respawn_flashing: bool = false

var _death_count: int = 0
var _death_position: Vector2 = Vector2.ZERO

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

	if _is_game_over:
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
	_attack_timer = max(_attack_timer - delta, 0.0)
	_attack_anim_timer = max(_attack_anim_timer - delta, 0.0)
	_combo_timer = max(_combo_timer - delta, 0.0)
	_aerial_attack_timer = max(_aerial_attack_timer - delta, 0.0)

	if _combo_timer <= 0.0:
		_combo_index = 0


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
	_handle_attack()
	_handle_dash()
	_handle_shoot(delta)
	_handle_wall_slide()
	_apply_gravity(delta)
	_handle_jump()
	_handle_special_assist()
	_handle_variable_jump_height()
	_handle_horizontal_movement(delta)


func _handle_attack() -> void:
	if _is_dead or _is_dying or _is_game_over:
		return

	if _hitstun_timer > 0.0:
		return

	if not Input.is_action_just_pressed(attack_action):
		return

	if is_on_floor():
		_play_ground_combo_attack()
	else:
		_play_random_aerial_attack()


func _play_ground_combo_attack() -> void:
	if _attack_timer > 0.0:
		return

	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if ground_combo.is_empty():
		return

	var anim_name: StringName = ground_combo[_combo_index]

	if not sprite.sprite_frames.has_animation(anim_name):
		push_warning("Missing ground attack animation: " + str(anim_name))
		return

	sprite.play(anim_name)
	_spawn_attack_hitbox(anim_name)

	_attack_timer = attack_cooldown
	_attack_anim_timer = attack_anim_lock_time
	_combo_timer = combo_timeout

	_combo_index += 1

	if _combo_index >= ground_combo.size():
		_combo_index = 0


func _play_random_aerial_attack() -> void:
	if _aerial_attack_timer > 0.0:
		return

	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if aerial_attacks.is_empty():
		return

	var valid_attacks: Array[StringName] = []

	for anim_name in aerial_attacks:
		if sprite.sprite_frames.has_animation(anim_name):
			valid_attacks.append(anim_name)

	if valid_attacks.is_empty():
		return

	var chosen: StringName = valid_attacks.pick_random()

	if valid_attacks.size() > 1:
		while chosen == _last_aerial_attack:
			chosen = valid_attacks.pick_random()

	_last_aerial_attack = chosen

	sprite.play(chosen)
	_spawn_attack_hitbox(chosen)

	_aerial_attack_timer = aerial_attack_cooldown
	_attack_timer = attack_cooldown
	_attack_anim_timer = attack_anim_lock_time


func _spawn_attack_hitbox(attack_name: StringName) -> void:
	if attack_hitbox_scene == null:
		return

	var hitbox := attack_hitbox_scene.instantiate() as Area2D
	if hitbox == null:
		return

	get_parent().add_child(hitbox)

	var x_offset := attack_offset_right.x

	if _facing_left:
		x_offset = -attack_offset_right.x

	hitbox.global_position = global_position + Vector2(x_offset, attack_offset_right.y)

	if hitbox.has_method("setup"):
		hitbox.setup(self, _facing_left, attack_name)
		return

	if hitbox.has_method("set_attack_name"):
		hitbox.set_attack_name(attack_name)


func _handle_dash() -> void:
	if _is_dashing:
		if _dash_timer <= 0.0:
			_end_dash()
		return

	if Input.is_action_just_pressed("dash") and _can_start_dash():
		_start_dash()


func _can_start_dash() -> bool:
	if _is_dead or _is_dying or _is_game_over:
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
	_attack_anim_timer = 0.0
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


func _handle_shoot(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and _can_shoot():
		_is_charging_shot = true
		_charge_time = 0.0
		shot_charge_changed.emit(0.0, true)

	if _is_charging_shot and Input.is_action_pressed("shoot"):
		_charge_time = minf(_charge_time + delta, maximum_charge_time)
		shot_charge_changed.emit(get_shot_charge_ratio(), true)

	if _is_charging_shot and Input.is_action_just_released("shoot"):
		var charge_ratio := get_shot_charge_ratio()
		_is_charging_shot = false
		_charge_time = 0.0
		shot_charge_changed.emit(0.0, false)
		_spawn_bullet(charge_ratio)


func _can_shoot() -> bool:
	if _is_dead or _is_dying or _is_game_over:
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


func _spawn_bullet(charge_ratio: float = 0.0) -> void:
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
		bullet.setup(direction, self, charge_ratio)

	fired_bullet.emit(bullet)


func get_shot_charge_ratio() -> float:
	if maximum_charge_time <= minimum_charge_time:
		return 1.0

	return clampf(
		(_charge_time - minimum_charge_time)
			/ (maximum_charge_time - minimum_charge_time),
		0.0,
		1.0
	)


func _cancel_shot_charge() -> void:
	_is_charging_shot = false
	_charge_time = 0.0
	shot_charge_changed.emit(0.0, false)


func _handle_special_assist() -> void:
	if not Input.is_action_just_pressed("special"):
		return

	if special_meter < special_meter_max:
		return

	if mattt_assist_scene == null:
		return

	special_meter = 100

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

	if _attack_anim_timer > 0.0:
		return

	if _is_dashing:
		_play_animation_with_fallback("dash", "run")
		return

	if _is_wall_sliding:
		_play_animation_with_fallback("wall_slide", "fall")
		return

	var is_shooting := _shoot_anim_timer > 0.01
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
	if _is_dead or _is_dying or _is_game_over:
		return

	if _invuln_timer > 0.0:
		return

	if health == null:
		push_warning("Player has no Health node.")
		return

	health.apply_damage(info)


func _on_damaged(info: DamageInfo) -> void:
	if _is_dead or _is_dying or _is_game_over:
		return

	_cancel_shot_charge()
	_is_dashing = false
	_is_wall_sliding = false
	_dash_timer = 0.0
	_wall_dir = 0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0

	_hitstun_timer = hitstun_duration
	_invuln_timer = damage_invuln_duration
	_shoot_anim_timer = 0.0
	_attack_anim_timer = 0.0

	if info != null:
		velocity += info.knockback

	if sprite != null:
		sprite.flip_h = _facing_left

	_update_muzzle_position()

	if not _is_hit_flashing:
		call_deferred("_run_hit_flash")


func _on_health_died() -> void:
	kill()


func kill() -> void:
	if _is_dead or _is_dying or _is_game_over:
		return

	_cancel_shot_charge()
	_death_count += 1
	_death_position = global_position

	_is_dead = true
	_is_dying = true
	_is_dashing = false
	_is_wall_sliding = false
	_is_hit_flashing = false

	_hitstun_timer = 0.0
	_invuln_timer = 0.0
	_fire_timer = 0.0
	_shoot_anim_timer = 0.0
	_attack_timer = 0.0
	_attack_anim_timer = 0.0
	_combo_timer = 0.0
	_combo_index = 0
	_aerial_attack_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0

	velocity = Vector2.ZERO

	_play_animation_if_available("death")
	died.emit()

	await _run_death_blink()

	if _death_count >= max_deaths_before_game_over:
		_is_game_over = true
		game_over.emit()
		print("Player game over.")
		return

	respawn()


func respawn() -> void:
	_cancel_shot_charge()
	global_position = _death_position
	velocity = Vector2.ZERO

	_is_dead = false
	_is_dying = false
	_is_dashing = false
	_is_wall_sliding = false
	_is_hit_flashing = false

	_hitstun_timer = 0.0
	_invuln_timer = respawn_invuln_duration
	_fire_timer = 0.0
	_shoot_anim_timer = 0.0
	_attack_timer = 0.0
	_attack_anim_timer = 0.0
	_combo_timer = 0.0
	_combo_index = 0
	_aerial_attack_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown_timer = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_lock_timer = 0.0
	_dust_spawn_timer = 0.0

	if restore_health_on_respawn:
		_restore_health_for_respawn()

	if sprite != null:
		sprite.visible = true
		sprite.modulate = Color.WHITE

	_play_animation_if_available("idle")

	if not _is_respawn_flashing:
		call_deferred("_run_respawn_flash")


func _restore_health_for_respawn() -> void:
	if health == null:
		return

	if health.has_method("heal_to_full"):
		health.heal_to_full()
		return

	if health.has_method("reset"):
		health.reset()
		return

	if "current_health" in health and "max_health" in health:
		health.current_health = health.max_health


func _run_respawn_flash() -> void:
	var target: CanvasItem = sprite

	if target == null:
		target = self

	_is_respawn_flashing = true

	var elapsed: float = 0.0
	var visible_state: bool = true

	while elapsed < respawn_invuln_duration and is_instance_valid(target):
		if _is_dead or _is_game_over:
			break

		visible_state = not visible_state
		target.visible = visible_state

		await get_tree().create_timer(respawn_flash_interval).timeout
		elapsed += respawn_flash_interval

	if is_instance_valid(target):
		target.visible = true

	_is_respawn_flashing = false


func _run_hit_flash() -> void:
	if _is_dead or _is_dying or _is_game_over:
		return

	var target: CanvasItem = sprite

	if target == null:
		target = self

	_is_hit_flashing = true
	var normal := target.modulate

	for i in range(hit_flash_count):
		if not is_instance_valid(target):
			break

		if _is_dead or _is_dying or _is_game_over:
			break

		target.modulate = hit_flash_color
		await get_tree().create_timer(hit_flash_interval).timeout

		if not is_instance_valid(target):
			break

		if _is_dead or _is_dying or _is_game_over:
			break

		target.modulate = normal
		await get_tree().create_timer(hit_flash_interval).timeout

	if is_instance_valid(target):
		if not _is_dead and not _is_dying and not _is_game_over:
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
		target.visible = true


func is_facing_left() -> bool:
	return _facing_left


func get_death_count() -> int:
	return _death_count


func get_lives_remaining() -> int:
	return max_deaths_before_game_over - _death_count


func reset_deaths() -> void:
	_death_count = 0
	_is_game_over = false


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

	if value:
		_cancel_shot_charge()


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
