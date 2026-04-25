extends CharacterBody2D
class_name GlitchDemon

signal died(enemy: Node)
signal attacked(enemy: Node)
signal glitch_burst(enemy: Node)

@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0
@export var move_speed: float = 40.0

@export var use_separate_directional_animations: bool = true
@export var death_remove_delay: float = 0.0
@export var auto_play_movement_animations: bool = true

@export var player_group: StringName = &"player"
@export var detection_range: float = 220.0
@export var attack_range: float = 96.0
@export var stop_distance: float = 8.0

@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.18
@export var random_attack_variant: bool = true
@export var projectile_scene: PackedScene

# --- Mid-boss growth ---
@export var hits_per_phase: int = 10
@export var max_growth_phases: int = 3
@export var growth_scale_multiplier: float = 1.5
@export var grow_animation_name: StringName = &"Grow"
@export var grow_invulnerable_time: float = 0.6
@export var growth_tween_time: float = 0.35

@export var phase_move_speed_bonus: float = 1.15
@export var phase_attack_range_bonus: float = 1.15
@export var phase_attack_cooldown_multiplier: float = 0.85

# --- Normal spread attack tuning ---
@export var phase_2_spread_degrees: float = 10.0
@export var phase_3_spread_degrees: float = 16.0
@export var phase_3_stagger_delay: float = 0.045
@export var aim_at_target: bool = true
@export var random_spread_variance_degrees: float = 1.5

# --- Phase 3 Signature Attack: Glitch Burst ---
@export var enable_glitch_burst: bool = true
@export var glitch_burst_every_attacks: int = 3
@export var glitch_burst_windup: float = 0.45
@export var glitch_burst_rings: int = 2
@export var glitch_burst_shots_per_ring: int = 8
@export var glitch_burst_ring_delay: float = 0.12
@export var glitch_burst_rotation_degrees: float = 22.5
@export var glitch_burst_random_variance_degrees: float = 1.0
@export var glitch_burst_use_muzzle_3: bool = true

# Optional animation name. If missing, it will reuse the normal Fire animation.
@export var glitch_burst_animation_name: StringName = &"GlitchBurst"

# --- Hit reaction ---
@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

# --- Death / explosion ---
@export var explosion_animation_name: StringName = &"Explosion"
@export var explosion_delay: float = 0.08
@export var wait_for_explosion_before_free: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var explosion_sprite: AnimatedSprite2D = $AnimatedSprite2D2
@onready var health: Health = $Health

@onready var muzzle: Node2D = get_node_or_null("Muzzle")
@onready var muzzle_2: Node2D = get_node_or_null("Muzzle2")
@onready var muzzle_3: Node2D = get_node_or_null("Muzzle3")

var facing_right: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var current_attack_variant: int = 1

var growth_phase: int = 1
var base_scale: Vector2
var base_move_speed: float
var base_attack_range: float
var base_attack_cooldown: float
var _is_growing: bool = false

var _target: Node2D = null
var _attack_cooldown_timer: float = 0.0
var _attack_windup_timer: float = 0.0
var _pending_attack: bool = false

var _flee_timer: float = 0.0
var _flee_from: Node2D = null

var _phase_3_attack_count: int = 0
var _doing_glitch_burst: bool = false

var _death_anim_done: bool = false
var _explosion_anim_done: bool = false


func _ready() -> void:
	base_scale = scale
	base_move_speed = move_speed
	base_attack_range = attack_range
	base_attack_cooldown = attack_cooldown

	if health != null:
		health.max_health = hits_per_phase
		health.current_health = hits_per_phase

		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	if explosion_sprite != null:
		explosion_sprite.visible = false

		if not explosion_sprite.animation_finished.is_connected(_on_explosion_animation_finished):
			explosion_sprite.animation_finished.connect(_on_explosion_animation_finished)

	_find_target()
	_play_idle()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)

	if _is_growing:
		_apply_gravity(delta)
		move_and_slide()
		return

	_find_target_if_needed()
	_process_ai(delta)

	_apply_gravity(delta)
	move_and_slide()

	if not is_attacking and auto_play_movement_animations:
		_update_facing_from_velocity()
		_update_movement_animation()


func _update_timers(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = max(_attack_cooldown_timer - delta, 0.0)

	if _attack_windup_timer > 0.0:
		_attack_windup_timer = max(_attack_windup_timer - delta, 0.0)

		if _attack_windup_timer == 0.0 and _pending_attack:
			_pending_attack = false
			_do_attack()

	if _flee_timer > 0.0:
		_flee_timer = max(_flee_timer - delta, 0.0)

		if _flee_timer == 0.0:
			_flee_from = null


func _find_target_if_needed() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(player_group)

	if players.is_empty():
		_target = null
		return

	_target = players[0] as Node2D


func _process_ai(_delta: float) -> void:
	if is_attacking:
		velocity.x = 0.0
		return

	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

	_face_toward(_target.global_position)

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		_process_flee()
		return

	if dist > detection_range:
		velocity.x = 0.0
		return

	if dist <= attack_range:
		velocity.x = 0.0

		if _attack_cooldown_timer <= 0.0:
			start_attack()

		return

	_move_toward_target()


func _move_toward_target() -> void:
	if _target == null:
		velocity.x = 0.0
		return

	var dx: float = _target.global_position.x - global_position.x

	if absf(dx) <= stop_distance:
		velocity.x = 0.0
		return

	velocity.x = sign(dx) * move_speed
	_face_toward(_target.global_position)


func _process_flee() -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		velocity.x = 0.0
		return

	var dx: float = global_position.x - _flee_from.global_position.x

	if absf(dx) <= 1.0:
		dx = -1.0 if facing_right else 1.0

	velocity.x = sign(dx) * move_speed * flee_speed_multiplier
	_update_facing_from_velocity()


func start_attack() -> void:
	if is_dead or is_attacking or _is_growing:
		return

	is_attacking = true
	velocity.x = 0.0

	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)

	var should_burst := _should_use_glitch_burst()

	if should_burst:
		_start_glitch_burst()
		return

	_attack_cooldown_timer = attack_cooldown
	_attack_windup_timer = attack_windup
	_pending_attack = true

	if random_attack_variant:
		current_attack_variant = randi_range(1, 3)
	else:
		current_attack_variant = 1

	play_fire_animation(current_attack_variant)


func _should_use_glitch_burst() -> bool:
	if not enable_glitch_burst:
		return false

	if growth_phase < 3:
		return false

	if glitch_burst_every_attacks <= 0:
		return false

	_phase_3_attack_count += 1

	return _phase_3_attack_count >= glitch_burst_every_attacks


func _start_glitch_burst() -> void:
	_phase_3_attack_count = 0
	_doing_glitch_burst = true
	_pending_attack = false
	_attack_windup_timer = 0.0
	_attack_cooldown_timer = attack_cooldown * 1.35

	_apply_facing()

	if _has_animation(String(glitch_burst_animation_name)):
		sprite.play(glitch_burst_animation_name)
	elif _has_animation("Fire3"):
		sprite.play("Fire3")
	elif _has_animation("Fire1"):
		sprite.play("Fire1")

	_do_glitch_burst_sequence()


func _do_glitch_burst_sequence() -> void:
	await get_tree().create_timer(glitch_burst_windup).timeout

	if is_dead or _is_growing:
		return

	glitch_burst.emit(self)

	CombatFX.hitstop(0.025, 0.04)
	CombatFX.shake(3.5, 0.12, 26.0)

	var spawn_point := _get_glitch_burst_muzzle()
	var base_angle_offset := 0.0

	for ring_index in range(glitch_burst_rings):
		if is_dead or _is_growing:
			return

		var ring_rotation := deg_to_rad(base_angle_offset)

		for shot_index in range(glitch_burst_shots_per_ring):
			var t := float(shot_index) / float(glitch_burst_shots_per_ring)
			var angle := TAU * t + ring_rotation
			var dir := Vector2.RIGHT.rotated(angle)

			dir = _with_custom_variance(dir, glitch_burst_random_variance_degrees)
			_spawn_projectile(spawn_point.global_position, dir)

		base_angle_offset += glitch_burst_rotation_degrees

		if glitch_burst_ring_delay > 0.0 and ring_index < glitch_burst_rings - 1:
			await get_tree().create_timer(glitch_burst_ring_delay).timeout

	_doing_glitch_burst = false
	finish_attack()


func play_fire_animation(variant: int = 1) -> void:
	if is_dead or _is_growing:
		return

	_apply_facing()

	current_attack_variant = clampi(variant, 1, 3)

	var anim_name := "Fire%d" % current_attack_variant

	if _has_animation(anim_name):
		sprite.play(anim_name)
	else:
		_do_attack()
		finish_attack()


func _do_attack() -> void:
	if is_dead or _is_growing:
		return

	attacked.emit(self)

	if projectile_scene == null:
		push_warning("GlitchDemon: projectile_scene is not assigned.")
		return

	var base_dir := _get_base_attack_direction()

	match growth_phase:
		1:
			_fire_phase_1(base_dir)
		2:
			_fire_phase_2(base_dir)
		_:
			await _fire_phase_3(base_dir)


func _fire_phase_1(base_dir: Vector2) -> void:
	var spawn_point := _get_safe_muzzle(muzzle)
	_spawn_projectile(spawn_point.global_position, base_dir)


func _fire_phase_2(base_dir: Vector2) -> void:
	var spread := deg_to_rad(phase_2_spread_degrees)

	var shots: Array[Dictionary] = [
		{"muzzle": _get_safe_muzzle(muzzle), "dir": base_dir.rotated(-spread)},
		{"muzzle": _get_safe_muzzle(muzzle_2), "dir": base_dir},
		{"muzzle": _get_safe_muzzle(muzzle), "dir": base_dir.rotated(spread)}
	]

	for shot in shots:
		_spawn_projectile(shot["muzzle"].global_position, _with_variance(shot["dir"]))


func _fire_phase_3(base_dir: Vector2) -> void:
	var spread := deg_to_rad(phase_3_spread_degrees)

	var shots: Array[Dictionary] = [
		{"muzzle": _get_safe_muzzle(muzzle), "dir": base_dir.rotated(-spread)},
		{"muzzle": _get_safe_muzzle(muzzle_2), "dir": base_dir.rotated(-spread * 0.5)},
		{"muzzle": _get_safe_muzzle(muzzle_3), "dir": base_dir},
		{"muzzle": _get_safe_muzzle(muzzle_2), "dir": base_dir.rotated(spread * 0.5)},
		{"muzzle": _get_safe_muzzle(muzzle), "dir": base_dir.rotated(spread)}
	]

	for shot in shots:
		if is_dead or _is_growing:
			return

		_spawn_projectile(shot["muzzle"].global_position, _with_variance(shot["dir"]))

		if phase_3_stagger_delay > 0.0:
			await get_tree().create_timer(phase_3_stagger_delay).timeout


func _get_base_attack_direction() -> Vector2:
	var dir := Vector2.RIGHT if facing_right else Vector2.LEFT

	if aim_at_target and _target != null and is_instance_valid(_target):
		dir = (_target.global_position - global_position).normalized()

		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT if facing_right else Vector2.LEFT

	return dir


func _with_variance(dir: Vector2) -> Vector2:
	return _with_custom_variance(dir, random_spread_variance_degrees)


func _with_custom_variance(dir: Vector2, variance_degrees: float) -> Vector2:
	if variance_degrees <= 0.0:
		return dir.normalized()

	var variance := deg_to_rad(variance_degrees)
	return dir.rotated(randf_range(-variance, variance)).normalized()


func _get_safe_muzzle(preferred_muzzle: Node2D) -> Node2D:
	if preferred_muzzle != null:
		return preferred_muzzle

	if muzzle != null:
		return muzzle

	return self


func _get_glitch_burst_muzzle() -> Node2D:
	if glitch_burst_use_muzzle_3 and muzzle_3 != null:
		return muzzle_3

	if muzzle_2 != null:
		return muzzle_2

	if muzzle != null:
		return muzzle

	return self


func _spawn_projectile(spawn_position: Vector2, direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("GlitchDemon: projectile_scene is not assigned.")
		return

	var projectile := projectile_scene.instantiate()

	if projectile == null:
		push_warning("GlitchDemon: projectile could not instantiate.")
		return

	get_parent().add_child(projectile)
	projectile.global_position = spawn_position

	if projectile.has_method("setup"):
		projectile.setup(direction.normalized(), self)
	elif projectile.has_method("launch"):
		projectile.launch(direction.normalized(), _target, self)
	else:
		push_warning("Projectile needs setup(direction, owner) or launch(direction, target, owner).")


func finish_attack() -> void:
	if is_dead:
		return

	is_attacking = false
	_pending_attack = false
	_doing_glitch_burst = false
	_attack_windup_timer = 0.0
	_update_movement_animation()


func _face_toward(world_pos: Vector2) -> void:
	facing_right = world_pos.x > global_position.x
	_apply_facing()


func _apply_facing() -> void:
	if sprite == null:
		return

	sprite.flip_h = not facing_right


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _update_facing_from_velocity() -> void:
	if velocity.x > 0.01:
		facing_right = true
	elif velocity.x < -0.01:
		facing_right = false

	_apply_facing()


func _update_movement_animation() -> void:
	if absf(velocity.x) > 4.0:
		_play_move()
	else:
		_play_idle()


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	_apply_facing()

	if sprite.sprite_frames.has_animation("Idle") and sprite.animation != "Idle":
		sprite.play("Idle")


func _play_move() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	_apply_facing()

	if use_separate_directional_animations:
		var anim_name := "Forward" if facing_right else "Back"

		if sprite.sprite_frames.has_animation(anim_name):
			if sprite.animation != anim_name:
				sprite.play(anim_name)
			return

	if sprite.sprite_frames.has_animation("Forward"):
		if sprite.animation != "Forward":
			sprite.play("Forward")


func _on_sprite_animation_finished() -> void:
	if is_dead:
		if sprite.animation == "Death":
			_death_anim_done = true
			_try_finalize_death()
		return

	if _is_growing:
		if sprite.animation == grow_animation_name:
			_play_idle()
		return

	if _doing_glitch_burst:
		return

	if sprite.animation.begins_with("Fire"):
		finish_attack()


func _on_damaged(info: DamageInfo) -> void:
	if is_dead or _is_growing:
		return

	if info != null:
		velocity += info.knockback

		if info.instigator is Node2D:
			_flee_from = info.instigator as Node2D
		else:
			_flee_from = _target

	_flee_timer = flee_duration
	is_attacking = false
	_pending_attack = false
	_doing_glitch_burst = false
	_attack_windup_timer = 0.0

	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)
	else:
		_update_facing_from_velocity()

	CombatFX.hitstop(0.03, 0.08)
	CombatFX.shake(2.0, 0.08, 24.0)


func _on_died() -> void:
	if is_dead or _is_growing:
		return

	if growth_phase < max_growth_phases:
		_start_growth_phase()
		return

	_start_final_death()


func _start_growth_phase() -> void:
	_is_growing = true
	is_attacking = false
	_pending_attack = false
	_doing_glitch_burst = false
	_attack_windup_timer = 0.0
	velocity = Vector2.ZERO

	growth_phase += 1

	print("GlitchDemon grew to phase: ", growth_phase)

	if health != null:
		health.invulnerable = true
		health._is_dead = false
		health.max_health = hits_per_phase
		health.current_health = hits_per_phase

	_apply_phase_stats()

	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)

	CombatFX.hitstop(0.04, 0.08)
	CombatFX.shake(4.0, 0.14, 22.0)

	var target_scale := base_scale * pow(growth_scale_multiplier, growth_phase - 1)

	if _has_animation(String(grow_animation_name)):
		sprite.play(grow_animation_name)

	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale, growth_tween_time)
	await tween.finished

	await get_tree().create_timer(grow_invulnerable_time).timeout

	if health != null:
		health.invulnerable = false

	_is_growing = false
	_play_idle()


func _apply_phase_stats() -> void:
	var phase_index := growth_phase - 1

	move_speed = base_move_speed * pow(phase_move_speed_bonus, phase_index)
	attack_range = base_attack_range * pow(phase_attack_range_bonus, phase_index)
	attack_cooldown = base_attack_cooldown * pow(phase_attack_cooldown_multiplier, phase_index)


func _start_final_death() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	_pending_attack = false
	_doing_glitch_burst = false
	velocity = Vector2.ZERO
	_death_anim_done = false
	_explosion_anim_done = false

	if _has_animation("Death"):
		sprite.play("Death")
	else:
		_death_anim_done = true
		CombatFX.hitstop(0.05, 0.05)
		CombatFX.shake(5.0, 0.16, 20.0)

	_start_explosion_sequence()


func _start_explosion_sequence() -> void:
	if explosion_sprite == null:
		_explosion_anim_done = true
		_try_finalize_death()
		return

	if explosion_delay > 0.0:
		await get_tree().create_timer(explosion_delay).timeout

	if not is_instance_valid(explosion_sprite):
		_explosion_anim_done = true
		_try_finalize_death()
		return

	explosion_sprite.visible = true

	if explosion_sprite.sprite_frames != null and explosion_sprite.sprite_frames.has_animation(explosion_animation_name):
		explosion_sprite.play(explosion_animation_name)
	else:
		_explosion_anim_done = true
		_try_finalize_death()


func _on_explosion_animation_finished() -> void:
	if explosion_sprite == null:
		return

	if explosion_sprite.animation == explosion_animation_name:
		_explosion_anim_done = true
		_try_finalize_death()


func _try_finalize_death() -> void:
	if wait_for_explosion_before_free:
		if not _death_anim_done or not _explosion_anim_done:
			return
	else:
		if not _death_anim_done:
			return

	if death_remove_delay > 0.0:
		var timer := get_tree().create_timer(death_remove_delay)
		timer.timeout.connect(_finalize_death, CONNECT_ONE_SHOT)
	else:
		_finalize_death()


func _finalize_death() -> void:
	died.emit(self)
	queue_free()


func _has_animation(anim_name: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func set_facing_right(value: bool) -> void:
	facing_right = value
	_apply_facing()

	if not is_attacking and not is_dead:
		_update_movement_animation()
