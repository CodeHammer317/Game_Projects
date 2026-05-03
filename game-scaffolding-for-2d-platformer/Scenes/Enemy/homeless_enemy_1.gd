extends CharacterBody2D
class_name Homeless1

signal died(enemy: Node)
signal attacked(enemy: Node)

@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0
@export var move_speed: float = 40.0
@export var run_speed_multiplier: float = 1.35

@export var death_remove_delay: float = 0.0
@export var auto_play_movement_animations: bool = true

@export var player_group: StringName = &"player"
@export var detection_range: float = 220.0
@export var attack_range: float = 96.0
@export var stop_distance: float = 8.0

@export var attack_cooldown: float = 1.2
@export var attack_ready_duration: float = 0.18
@export var attack_anim_lock_time: float = 0.28
@export var random_attack_variant: bool = true
@export var projectile_scene: PackedScene

@export var hurt_anim_lock_time: float = 0.20
@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

@export var idle_change_interval_min: float = 1.5
@export var idle_change_interval_max: float = 3.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var muzzle: Node2D = get_node_or_null("Muzzle")

var facing_right: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var current_attack_variant: int = 1

var _target: Node2D = null

var _attack_cooldown_timer: float = 0.0
var _attack_ready_timer: float = 0.0
var _attack_anim_timer: float = 0.0
var _pending_attack: bool = false
var _projectile_fired_this_attack: bool = false

var _hurt_timer: float = 0.0

var _flee_timer: float = 0.0
var _flee_from: Node2D = null

var _idle_variant: StringName = &"Idle1"
var _idle_swap_timer: float = 0.0

var _death_anim_done: bool = false


func _ready() -> void:
	randomize()

	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_pick_idle_variant(true)
	_find_target()
	_apply_sprite_facing()
	_play_idle()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_find_target_if_needed()
	_process_ai(delta)

	_apply_gravity(delta)
	move_and_slide()

	_update_facing_logic()

	if auto_play_movement_animations:
		_update_animation_state()

	_apply_sprite_facing()


func _update_timers(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = max(_attack_cooldown_timer - delta, 0.0)

	if _attack_ready_timer > 0.0:
		_attack_ready_timer = max(_attack_ready_timer - delta, 0.0)
		if _attack_ready_timer == 0.0 and _pending_attack and not is_dead:
			_pending_attack = false
			_begin_attack_animation()

	if _attack_anim_timer > 0.0:
		_attack_anim_timer = max(_attack_anim_timer - delta, 0.0)
		if _attack_anim_timer == 0.0 and is_attacking and not is_dead:
			finish_attack()

	if _hurt_timer > 0.0:
		_hurt_timer = max(_hurt_timer - delta, 0.0)

	if _flee_timer > 0.0:
		_flee_timer = max(_flee_timer - delta, 0.0)
		if _flee_timer == 0.0:
			_flee_from = null

	if _idle_swap_timer > 0.0:
		_idle_swap_timer = max(_idle_swap_timer - delta, 0.0)
		if _idle_swap_timer == 0.0:
			_pick_idle_variant()


func _find_target_if_needed() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(player_group)
	if players.is_empty():
		_target = null
		return

	var closest: Node2D = null
	var closest_dist := INF

	for p in players:
		if p is Node2D:
			var candidate := p as Node2D
			var dist := global_position.distance_to(candidate.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = candidate

	_target = closest


func _process_ai(_delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		return

	if _hurt_timer > 0.0:
		# Hurt state should finish before resuming normal AI
		return

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		_process_flee()
		return

	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return

	# Always face target when not fleeing
	_face_toward(_target.global_position)

	if is_attacking:
		velocity.x = 0.0
		return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()

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
	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return

	var dx := _target.global_position.x - global_position.x

	if absf(dx) <= stop_distance:
		velocity.x = 0.0
		return

	var move_dir = sign(dx)
	var should_run := absf(dx) > attack_range * 1.5
	var speed := move_speed * (run_speed_multiplier if should_run else 1.0)

	velocity.x = move_dir * speed


func _process_flee() -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		velocity.x = 0.0
		return

	var dx := global_position.x - _flee_from.global_position.x
	if absf(dx) <= 1.0:
		dx = -1.0 if facing_right else 1.0

	velocity.x = sign(dx) * move_speed * flee_speed_multiplier


func _face_toward(world_pos: Vector2) -> void:
	facing_right = world_pos.x > global_position.x


func _update_facing_logic() -> void:
	if is_dead:
		return

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		if velocity.x > 0.01:
			facing_right = true
		elif velocity.x < -0.01:
			facing_right = false
		return

	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)
		return

	if velocity.x > 0.01:
		facing_right = true
	elif velocity.x < -0.01:
		facing_right = false


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _apply_sprite_facing() -> void:
	if sprite != null:
		sprite.flip_h = not facing_right


func _update_animation_state() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if is_dead:
		return

	# Hard locks first
	if _hurt_timer > 0.0:
		if _has_animation("Hurt") and sprite.animation != "Hurt":
			sprite.play("Hurt")
		return

	if is_attacking:
		if _pending_attack:
			if _has_animation("Attack_Ready") and sprite.animation != "Attack_Ready":
				sprite.play("Attack_Ready")
			return

		var attack_anim := "Attack%d" % current_attack_variant
		if _has_animation(attack_anim) and sprite.animation != attack_anim:
			sprite.play(attack_anim)
		return

	if not is_on_floor():
		if _has_animation("Jump") and sprite.animation != "Jump":
			sprite.play("Jump")
		return

	var speed_abs := absf(velocity.x)

	if speed_abs > move_speed * 0.75 and _has_animation("Run"):
		if sprite.animation != "Run":
			sprite.play("Run")
		return

	if speed_abs > 4.0 and _has_animation("Walk"):
		if sprite.animation != "Walk":
			sprite.play("Walk")
		return

	_play_idle()


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if not _has_animation(_idle_variant):
		_idle_variant = &"Idle1"

	if sprite.animation != _idle_variant:
		sprite.play(_idle_variant)


func _pick_idle_variant(force_reset_timer: bool = false) -> void:
	_idle_variant = &"Idle1"

	if _has_animation("Idle2") and randi() % 2 == 0:
		_idle_variant = &"Idle2"

	if force_reset_timer or _idle_swap_timer <= 0.0:
		_idle_swap_timer = randf_range(idle_change_interval_min, idle_change_interval_max)


func start_attack() -> void:
	if is_dead or is_attacking or _hurt_timer > 0.0:
		return

	is_attacking = true
	_pending_attack = true
	_projectile_fired_this_attack = false
	attack_face_target()
	velocity.x = 0.0

	_attack_cooldown_timer = attack_cooldown
	_attack_ready_timer = attack_ready_duration
	_attack_anim_timer = 0.0

	if random_attack_variant:
		current_attack_variant = randi_range(1, 2)
	else:
		current_attack_variant = 1

	if _has_animation("Attack_Ready"):
		sprite.play("Attack_Ready")
	else:
		_begin_attack_animation()


func attack_face_target() -> void:
	if _target != null and is_instance_valid(_target):
		_face_toward(_target.global_position)


func _begin_attack_animation() -> void:
	if is_dead:
		return

	_pending_attack = false
	attack_face_target()

	current_attack_variant = clampi(current_attack_variant, 1, 2)
	var anim_name := "Attack%d" % current_attack_variant

	if _has_animation(anim_name):
		sprite.play(anim_name)
		_attack_anim_timer = attack_anim_lock_time
		_do_attack()
	else:
		finish_attack()


func _do_attack() -> void:
	if is_dead or _projectile_fired_this_attack:
		return

	_projectile_fired_this_attack = true
	attacked.emit(self)

	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	get_parent().add_child(projectile)

	var direction := Vector2.RIGHT if facing_right else Vector2.LEFT

	if muzzle != null:
		projectile.global_position = muzzle.global_position + direction * 4.0
	else:
		projectile.global_position = global_position + direction * 4.0

	if projectile.has_method("setup"):
		projectile.setup(direction, self)
	elif projectile.has_method("launch"):
		projectile.launch(direction, _target, self)


func finish_attack() -> void:
	if is_dead:
		return

	is_attacking = false
	_pending_attack = false
	_projectile_fired_this_attack = false
	_attack_ready_timer = 0.0
	_attack_anim_timer = 0.0


func _on_damaged(info: DamageInfo) -> void:
	if is_dead:
		return

	is_attacking = false
	_pending_attack = false
	_projectile_fired_this_attack = false
	_attack_ready_timer = 0.0
	_attack_anim_timer = 0.0

	if info != null:
		velocity += info.knockback

		if info.instigator is Node2D:
			_flee_from = info.instigator as Node2D
		else:
			_flee_from = _target

	_flee_timer = flee_duration
	_hurt_timer = hurt_anim_lock_time

	if _has_animation("Hurt"):
		sprite.play("Hurt")

	CombatFX.hitstop(0.03, 0.08)
	CombatFX.shake(2.0, 0.08, 24.0)

	_update_facing_logic()
	_apply_sprite_facing()


func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	_pending_attack = false
	_projectile_fired_this_attack = false

	_attack_ready_timer = 0.0
	_attack_anim_timer = 0.0
	_hurt_timer = 0.0
	_flee_timer = 0.0

	velocity = Vector2.ZERO
	_death_anim_done = false

	CombatFX.hitstop(0.05, 0.05)
	CombatFX.shake(5.0, 0.16, 20.0)

	_apply_sprite_facing()

	if _has_animation("Death"):
		sprite.play("Death")
	else:
		_death_anim_done = true
		_try_finalize_death()


func _on_sprite_animation_finished() -> void:
	if sprite == null:
		return

	if is_dead:
		if sprite.animation == "Death":
			_death_anim_done = true
			_try_finalize_death()
		return

	# Let timer own the state timing, but if animation finishes first,
	# clear early so the enemy feels responsive.
	if sprite.animation == "Hurt" and _hurt_timer > 0.0:
		_hurt_timer = 0.0
		return

	if (sprite.animation == "Attack1" or sprite.animation == "Attack2") and _attack_anim_timer > 0.0:
		_attack_anim_timer = 0.0
		finish_attack()


func _try_finalize_death() -> void:
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


func _has_animation(anim_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func set_facing_right(value: bool) -> void:
	facing_right = value
	_apply_sprite_facing()

	if not is_attacking and not is_dead and _hurt_timer <= 0.0:
		_update_animation_state()






















'''extends CharacterBody2D
class_name Homeless1

signal died(enemy: Node)
signal attacked(enemy: Node)

@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0
@export var move_speed: float = 40.0
@export var run_speed_multiplier: float = 1.35

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

@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var muzzle: Node2D = get_node_or_null("Muzzle")

var facing_right: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var current_attack_variant: int = 1

var _target: Node2D = null
var _attack_cooldown_timer: float = 0.0
var _attack_windup_timer: float = 0.0
var _pending_attack: bool = false
var _projectile_fired_this_attack: bool = false

var _flee_timer: float = 0.0
var _flee_from: Node2D = null

var _death_anim_done: bool = false


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_find_target()
	_apply_sprite_facing()
	_play_idle()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_timers(delta)
	_find_target_if_needed()
	_process_ai(delta)

	_apply_gravity(delta)
	move_and_slide()

	if not is_attacking and auto_play_movement_animations:
		_update_facing_from_velocity()
		_update_movement_animation()

	_apply_sprite_facing()


func _update_timers(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer = max(_attack_cooldown_timer - delta, 0.0)

	if _attack_windup_timer > 0.0:
		_attack_windup_timer = max(_attack_windup_timer - delta, 0.0)
		if _attack_windup_timer <= 0.0 and _pending_attack:
			_pending_attack = false
			play_fire_animation(current_attack_variant)
			_do_attack()

	if _flee_timer > 0.0:
		_flee_timer = max(_flee_timer - delta, 0.0)
		if _flee_timer <= 0.0:
			_flee_from = null


func _find_target_if_needed() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(player_group)
	if players.is_empty():
		_target = null
		return

	var closest: Node2D = null
	var closest_dist := INF

	for p in players:
		if p is Node2D:
			var candidate := p as Node2D
			var dist := global_position.distance_to(candidate.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = candidate

	_target = closest


func _process_ai(_delta: float) -> void:
	if is_attacking:
		velocity.x = 0.0
		return

	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		_process_flee()
		return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()

	if dist > detection_range:
		velocity.x = 0.0
		return

	if dist <= attack_range:
		velocity.x = 0.0
		_face_toward(_target.global_position)

		if _attack_cooldown_timer <= 0.0:
			start_attack()

		return

	_move_toward_target()


func _move_toward_target() -> void:
	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		return

	var dx := _target.global_position.x - global_position.x

	if absf(dx) <= stop_distance:
		velocity.x = 0.0
		return

	var move_dir = sign(dx)
	var should_run := absf(dx) > attack_range * 1.5
	var speed := move_speed * (run_speed_multiplier if should_run else 1.0)

	velocity.x = move_dir * speed
	_face_toward(_target.global_position)


func _process_flee() -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		velocity.x = 0.0
		return

	var dx := global_position.x - _flee_from.global_position.x
	if absf(dx) <= 1.0:
		dx = -1.0 if facing_right else 1.0

	velocity.x = sign(dx) * move_speed * flee_speed_multiplier
	_update_facing_from_velocity()


func _face_toward(world_pos: Vector2) -> void:
	facing_right = world_pos.x > global_position.x


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


func _apply_sprite_facing() -> void:
	if sprite != null:
		sprite.flip_h = not facing_right


func _update_movement_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if not is_on_floor():
		if _has_animation("Jump"):
			if sprite.animation != "Jump":
				sprite.play("Jump")
		return

	if absf(velocity.x) > move_speed * 0.75 and _has_animation("Run"):
		if sprite.animation != "Run":
			sprite.play("Run")
		return

	if absf(velocity.x) > 4.0 and _has_animation("Walk"):
		if sprite.animation != "Walk":
			sprite.play("Walk")
		return

	_play_idle()


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var anim_name := "Idle1"
	if _has_animation("Idle2") and randi() % 2 == 0:
		anim_name = "Idle2"

	if sprite.animation != anim_name:
		sprite.play(anim_name)


func start_attack() -> void:
	if is_dead or is_attacking:
		return

	is_attacking = true
	_attack_cooldown_timer = attack_cooldown
	_attack_windup_timer = attack_windup
	_pending_attack = true
	_projectile_fired_this_attack = false
	velocity.x = 0.0

	if random_attack_variant:
		current_attack_variant = randi_range(1, 2)
	else:
		current_attack_variant = 1

	if _has_animation("Attack_Ready"):
		sprite.play("Attack_Ready")
	else:
		play_fire_animation(current_attack_variant)
		_pending_attack = false
		_do_attack()


func play_fire_animation(variant: int = 1) -> void:
	if is_dead:
		return

	current_attack_variant = clampi(variant, 1, 2)
	var anim_name := "Attack%d" % current_attack_variant

	if _has_animation(anim_name):
		sprite.play(anim_name)
	else:
		finish_attack()


func _do_attack() -> void:
	if is_dead or _projectile_fired_this_attack:
		return

	_projectile_fired_this_attack = true
	attacked.emit(self)

	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	get_parent().add_child(projectile)

	var direction := Vector2.RIGHT if facing_right else Vector2.LEFT

	if muzzle != null:
		projectile.global_position = muzzle.global_position + direction * 4.0
	else:
		projectile.global_position = global_position + direction * 4.0

	if projectile.has_method("setup"):
		projectile.setup(direction, self)
	elif projectile.has_method("launch"):
		projectile.launch(direction, _target, self)


func finish_attack() -> void:
	if is_dead:
		return

	is_attacking = false
	_pending_attack = false
	_attack_windup_timer = 0.0
	_projectile_fired_this_attack = false
	_update_movement_animation()


func _on_sprite_animation_finished() -> void:
	if is_dead:
		if sprite.animation == "Death":
			_death_anim_done = true
			_try_finalize_death()
		return

	if sprite.animation == "Attack_Ready":
		return

	if sprite.animation == "Attack1" or sprite.animation == "Attack2":
		finish_attack()
		return

	if sprite.animation == "Hurt":
		_update_movement_animation()


func _on_damaged(info: DamageInfo) -> void:
	if is_dead:
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
	_attack_windup_timer = 0.0
	_projectile_fired_this_attack = false

	if _has_animation("Hurt"):
		sprite.play("Hurt")

	CombatFX.hitstop(0.03, 0.08)
	CombatFX.shake(2.0, 0.08, 24.0)

	_update_facing_from_velocity()
	_apply_sprite_facing()


func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	_pending_attack = false
	_projectile_fired_this_attack = false
	velocity = Vector2.ZERO
	_death_anim_done = false

	CombatFX.hitstop(0.05, 0.05)
	CombatFX.shake(5.0, 0.16, 20.0)

	_apply_sprite_facing()

	if _has_animation("Death"):
		sprite.play("Death")
	else:
		_death_anim_done = true
		_try_finalize_death()


func _try_finalize_death() -> void:
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
	_apply_sprite_facing()

	if not is_attacking and not is_dead:
		_update_movement_animation()'''
