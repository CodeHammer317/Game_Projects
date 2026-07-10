extends Player
class_name Player2

signal nasty_state_changed(active: bool)

@export_group("Top Lobsta")
@export var transform_on_first_hit: bool = true
@export var start_as_nasty: bool = false
@export var transform_lock_time: float = 0.65

@export_group("Top Lobsta Animations")
@export var normal_idle_animation: StringName = &"idle_normal"
@export var normal_jump_start_animation: StringName = &"jump_start_normal"
@export var normal_jump_loop_animation: StringName = &"jump_loop_normal"
@export var normal_fall_animation: StringName = &"fall_normal"
@export var normal_landing_animation: StringName = &"jump_landing_normal"
@export var normal_hit_animation: StringName = &"get_hit_normal"
@export var transform_animation: StringName = &"transform"

@export var nasty_idle_animation: StringName = &"claw_idle"
@export var nasty_jump_start_animation: StringName = &"claw_jump_start"
@export var nasty_jump_loop_animation: StringName = &"claw_jump_loop"
@export var nasty_fall_animation: StringName = &"claw_fall"
@export var nasty_landing_animation: StringName = &"claw_landing"
@export var nasty_air_toss_animation: StringName = &"claw_raven_air_toss"

@export_group("Top Lobsta Combat")
@export var nasty_ground_combo: Array[StringName] = [
	&"claw_chop",
	&"claw_grab",
	&"claw_shield",
]
@export var nasty_grab_animation: StringName = &"new_animation_1"
@export var fallback_nasty_grab_animation: StringName = &"new_animation"
@export var nasty_grab_every_combo_loops: int = 2
@export var nasty_attack_offset_right: Vector2 = Vector2(58.0, -8.0)
@export var nasty_grab_offset_right: Vector2 = Vector2(80.0, -8.0)

var is_nasty: bool = false

var _is_transforming: bool = false
var _transform_timer: float = 0.0
var _was_airborne: bool = false
var _played_landing: bool = false
var _nasty_combo_loops: int = 0


func _ready() -> void:
	is_nasty = start_as_nasty
	if is_nasty:
		ground_combo = nasty_ground_combo.duplicate()
		attack_offset_right = nasty_attack_offset_right
	else:
		ground_combo = []

	super()
	_play_current_idle()


func _run_active_frame(delta: float, use_hitstun_movement: bool) -> void:
	if _is_transforming:
		_update_timers(delta)
		_transform_timer = maxf(_transform_timer - delta, 0.0)
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, hit_friction * delta)
		move_and_slide()
		_update_facing()
		_snap_visuals_to_pixel()

		if _transform_timer <= 0.0:
			_finish_transform()
		return

	super(delta, use_hitstun_movement)


func _handle_attack() -> void:
	if is_nasty:
		_handle_nasty_attack()
		return

	super()


func _handle_nasty_attack() -> void:
	if not combat_enabled:
		return

	if _is_dead or _is_dying or _is_game_over:
		return

	if _hitstun_timer > 0.0:
		return

	if not Input.is_action_just_pressed(attack_action):
		return

	if is_on_floor():
		_play_nasty_ground_attack()
	else:
		_play_nasty_aerial_attack()


func _play_nasty_ground_attack() -> void:
	if _attack_timer > 0.0:
		return

	if sprite == null or sprite.sprite_frames == null:
		return

	var combo := nasty_ground_combo
	if combo.is_empty():
		combo = [&"claw_chop"]

	var anim_name: StringName = combo[_combo_index]
	if _should_use_nasty_grab(combo):
		anim_name = _resolve_nasty_grab_animation()

	if not sprite.sprite_frames.has_animation(anim_name):
		push_warning("Missing Player2 attack animation: " + str(anim_name))
		return

	sprite.play(anim_name)
	_spawn_nasty_attack_hitbox(anim_name)

	_attack_timer = attack_cooldown
	_attack_anim_timer = attack_anim_lock_time
	_combo_timer = combo_timeout

	_combo_index += 1
	if _combo_index >= combo.size():
		_combo_index = 0
		_nasty_combo_loops += 1


func _should_use_nasty_grab(combo: Array[StringName]) -> bool:
	if nasty_grab_every_combo_loops <= 0:
		return false

	if _combo_index != combo.size() - 1:
		return false

	return (_nasty_combo_loops + 1) % nasty_grab_every_combo_loops == 0


func _resolve_nasty_grab_animation() -> StringName:
	if sprite != null and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(nasty_grab_animation):
			return nasty_grab_animation

		if sprite.sprite_frames.has_animation(fallback_nasty_grab_animation):
			return fallback_nasty_grab_animation

	return nasty_grab_animation


func _play_nasty_aerial_attack() -> void:
	if _aerial_attack_timer > 0.0:
		return

	if sprite == null or sprite.sprite_frames == null:
		return

	var anim_name := nasty_air_toss_animation
	if not sprite.sprite_frames.has_animation(anim_name):
		anim_name = nasty_fall_animation

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
		_spawn_nasty_attack_hitbox(anim_name)

	_aerial_attack_timer = aerial_attack_cooldown
	_attack_timer = attack_cooldown
	_attack_anim_timer = attack_anim_lock_time


func _spawn_nasty_attack_hitbox(attack_name: StringName) -> void:
	var old_offset := attack_offset_right
	attack_offset_right = nasty_grab_offset_right if attack_name == _resolve_nasty_grab_animation() else nasty_attack_offset_right
	_spawn_attack_hitbox(attack_name)
	attack_offset_right = old_offset


func _update_animation() -> void:
	if sprite == null:
		return

	if _is_transforming:
		return

	if _is_dead:
		_play_animation_if_available("death")
		return

	if _attack_anim_timer > 0.0:
		return

	if is_nasty:
		_update_nasty_animation()
	else:
		_update_normal_animation()


func _update_normal_animation() -> void:
	if not is_on_floor():
		_was_airborne = true
		_play_animation_if_available(normal_jump_loop_animation if velocity.y < 0.0 else normal_fall_animation)
		return

	if _was_airborne and not _played_landing:
		_play_animation_if_available(normal_landing_animation)
		_played_landing = true
		return

	_was_airborne = false
	_played_landing = false
	_play_animation_if_available(normal_idle_animation)


func _update_nasty_animation() -> void:
	if not is_on_floor():
		_was_airborne = true
		_play_animation_if_available(nasty_jump_loop_animation if velocity.y < 0.0 else nasty_fall_animation)
		return

	if _was_airborne and not _played_landing:
		_play_animation_if_available(nasty_landing_animation)
		_played_landing = true
		return

	_was_airborne = false
	_played_landing = false
	_play_animation_if_available(nasty_idle_animation)


func _do_jump(is_double_jump: bool = false) -> void:
	super(is_double_jump)

	if is_nasty:
		_play_animation_if_available(nasty_jump_start_animation)
	else:
		_play_animation_if_available(normal_jump_start_animation)


func _on_damaged(info: DamageInfo) -> void:
	super(info)

	if transform_on_first_hit and not is_nasty and not _is_transforming:
		_begin_transform()
	elif not is_nasty:
		_play_animation_if_available(normal_hit_animation)


func _begin_transform() -> void:
	_is_transforming = true
	_transform_timer = transform_lock_time
	_hitstun_timer = maxf(_hitstun_timer, transform_lock_time)
	_attack_anim_timer = 0.0
	_attack_timer = 0.0
	_combo_timer = 0.0
	_combo_index = 0
	_nasty_combo_loops = 0
	_cancel_shot_charge()
	_is_dashing = false
	_is_wall_sliding = false
	_end_double_jump_state()
	_play_animation_if_available(transform_animation)


func _finish_transform() -> void:
	if is_nasty:
		_is_transforming = false
		return

	is_nasty = true
	_is_transforming = false
	ground_combo = nasty_ground_combo.duplicate()
	attack_offset_right = nasty_attack_offset_right
	_was_airborne = not is_on_floor()
	_play_current_idle()
	nasty_state_changed.emit(true)


func _play_current_idle() -> void:
	if is_nasty:
		_play_animation_if_available(nasty_idle_animation)
	else:
		_play_animation_if_available(normal_idle_animation)


func reset_to_normal_form() -> void:
	is_nasty = false
	_is_transforming = false
	_transform_timer = 0.0
	ground_combo = []
	_combo_index = 0
	_nasty_combo_loops = 0
	_play_current_idle()
	nasty_state_changed.emit(false)
