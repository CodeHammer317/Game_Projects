extends CharacterBody2D
class_name EnemyBase

signal died(enemy: Node)
signal attacked(enemy: Node)

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

@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

@export var explosion_animation_name: StringName = &"Explosion"
@export var explosion_delay: float = 0.08
@export var wait_for_explosion_before_free: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var explosion_sprite: AnimatedSprite2D = $AnimatedSprite2D2
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

var _flee_timer: float = 0.0
var _flee_from: Node2D = null

var _death_anim_done: bool = false
var _explosion_anim_done: bool = false


func _ready() -> void:
	if health != null:
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

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		_process_flee()
		return

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


func _update_movement_animation() -> void:
	if absf(velocity.x) > 4.0:
		_play_move()
	else:
		_play_idle()


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("Idle") and sprite.animation != "Idle":
		sprite.play("Idle")


func _play_move() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if use_separate_directional_animations:
		var anim_name := "Forward" if facing_right else "Back"
		if sprite.sprite_frames.has_animation(anim_name):
			if sprite.animation != anim_name:
				sprite.play(anim_name)
			return

	if sprite.sprite_frames.has_animation("Forward"):
		if sprite.animation != "Forward":
			sprite.play("Forward")
		sprite.flip_h = not facing_right


func start_attack() -> void:
	if is_dead or is_attacking:
		return

	is_attacking = true
	_attack_cooldown_timer = attack_cooldown
	_attack_windup_timer = attack_windup
	_pending_attack = true

	if random_attack_variant:
		current_attack_variant = randi_range(1, 3)
	else:
		current_attack_variant = 1

	play_fire_animation(current_attack_variant)


func play_fire_animation(variant: int = 1) -> void:
	if is_dead:
		return

	current_attack_variant = clampi(variant, 1, 3)

	var anim_name := "Fire%d" % current_attack_variant
	if _has_animation(anim_name):
		sprite.play(anim_name)
	else:
		finish_attack()


func _do_attack() -> void:
	if is_dead:
		return

	attacked.emit(self)

	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	get_parent().add_child(projectile)

	if muzzle != null:
		projectile.global_position = muzzle.global_position
	else:
		projectile.global_position = global_position

	var direction := Vector2.RIGHT if facing_right else Vector2.LEFT

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
	_update_movement_animation()


func _on_sprite_animation_finished() -> void:
	if is_dead:
		if sprite.animation == "Death":
			_death_anim_done = true
			_try_finalize_death()
		return

	if sprite.animation.begins_with("Fire"):
		finish_attack()


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
	CombatFX.hitstop(0.03, 0.08)
	CombatFX.shake(2.0, 0.08, 24.0)
	_update_facing_from_velocity()


func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	_pending_attack = false
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
	
	
	#call_deferred("_start_explosion_sequence")


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
	if not is_attacking and not is_dead:
		_update_movement_animation()




















'''extends CharacterBody2D
class_name EnemyBase

signal died(enemy: Node)
signal attacked(enemy: Node)

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

@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

@export var attack_cancel_distance_multiplier: float = 1.5
@export var flip_idle_animation: bool = true
@export var flip_attack_animations: bool = true
@export var flip_hit_animation: bool = true
@export var flip_death_animation: bool = true
@export var mirror_muzzle_with_facing: bool = true
@export var hit_animation_name: StringName = &"Hit"

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
var _attack_direction: int = 1

var _flee_timer: float = 0.0
var _flee_from: Node2D = null

var _muzzle_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	if muzzle != null:
		_muzzle_base_position = muzzle.position

	_find_target()
	_apply_facing_visuals()
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

	var closest: Node2D = null
	var best_dist := INF

	for p in players:
		if not (p is Node2D):
			continue

		var node := p as Node2D
		var d := global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			closest = node

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

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

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

	var dir = sign(global_position.x - _flee_from.global_position.x)
	if dir == 0.0:
		dir = -1.0 if facing_right else 1.0

	velocity.x = dir * move_speed * flee_speed_multiplier
	_update_facing_from_velocity()


func _face_toward(world_pos: Vector2) -> void:
	facing_right = world_pos.x > global_position.x
	_apply_facing_visuals()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _update_facing_from_velocity() -> void:
	var changed := false

	if velocity.x > 0.01:
		if not facing_right:
			changed = true
		facing_right = true
	elif velocity.x < -0.01:
		if facing_right:
			changed = true
		facing_right = false

	if changed:
		_apply_facing_visuals()


func _apply_facing_visuals() -> void:
	_update_muzzle_facing()


func _update_muzzle_facing() -> void:
	if muzzle == null or not mirror_muzzle_with_facing:
		return

	var p := _muzzle_base_position
	p.x = absf(_muzzle_base_position.x) if facing_right else -absf(_muzzle_base_position.x)
	muzzle.position = p


func _update_movement_animation() -> void:
	if absf(velocity.x) > 4.0:
		_play_move()
	else:
		_play_idle()


func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("Idle"):
		if sprite.animation != "Idle":
			sprite.play("Idle")

		if flip_idle_animation:
			sprite.flip_h = not facing_right
		else:
			sprite.flip_h = false


func _play_move() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if use_separate_directional_animations:
		var anim_name := "Forward" if facing_right else "Back"
		if sprite.sprite_frames.has_animation(anim_name):
			if sprite.animation != anim_name:
				sprite.play(anim_name)

			sprite.flip_h = false
			return

	if sprite.sprite_frames.has_animation("Forward"):
		if sprite.animation != "Forward":
			sprite.play("Forward")
		sprite.flip_h = not facing_right


func start_attack() -> void:
	if is_dead or is_attacking:
		return

	is_attacking = true
	_attack_cooldown_timer = attack_cooldown
	_attack_windup_timer = attack_windup
	_pending_attack = true

	_attack_direction = 1 if facing_right else -1

	if random_attack_variant:
		current_attack_variant = randi_range(1, 3)
	else:
		current_attack_variant = 1

	play_fire_animation(current_attack_variant)


func play_fire_animation(variant: int = 1) -> void:
	if is_dead or sprite == null or sprite.sprite_frames == null:
		return

	current_attack_variant = clampi(variant, 1, 3)

	var anim_name := "Fire%d" % current_attack_variant
	if _has_animation(anim_name):
		sprite.play(anim_name)

		if flip_attack_animations:
			sprite.flip_h = (_attack_direction < 0)
		else:
			sprite.flip_h = false

		# Lock muzzle to attack direction for the full attack
		if muzzle != null and mirror_muzzle_with_facing:
			var p := _muzzle_base_position
			p.x = absf(_muzzle_base_position.x) if _attack_direction > 0 else -absf(_muzzle_base_position.x)
			muzzle.position = p
	else:
		finish_attack()


func _do_attack() -> void:
	if is_dead:
		return

	if _target == null or not is_instance_valid(_target):
		finish_attack()
		return

	var dist := global_position.distance_to(_target.global_position)
	if dist > attack_range * attack_cancel_distance_multiplier:
		finish_attack()
		return

	attacked.emit(self)

	if projectile_scene == null:
		finish_attack()
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		finish_attack()
		return

	get_parent().add_child(projectile)

	if muzzle != null:
		projectile.global_position = muzzle.global_position
	else:
		projectile.global_position = global_position

	var direction := Vector2.RIGHT if _attack_direction > 0 else Vector2.LEFT

	if projectile.has_method("setup"):
		projectile.setup(direction, self)
	elif projectile.has_method("launch"):
		projectile.launch(direction, _target, self)

	finish_attack()


func finish_attack() -> void:
	if is_dead:
		return

	is_attacking = false
	_pending_attack = false
	_attack_windup_timer = 0.0
	_apply_facing_visuals()
	_update_movement_animation()


func _on_sprite_animation_finished() -> void:
	if is_dead:
		return

	if sprite.animation.begins_with("Fire"):
		finish_attack()


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

	if _has_animation(hit_animation_name):
		sprite.play(hit_animation_name)
		if flip_hit_animation:
			sprite.flip_h = not facing_right
		else:
			sprite.flip_h = false

	_update_facing_from_velocity()
	_apply_facing_visuals()


func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	_pending_attack = false
	velocity = Vector2.ZERO

	if _has_animation("Death"):
		sprite.play("Death")
		if flip_death_animation:
			sprite.flip_h = not facing_right
		else:
			sprite.flip_h = false

		if sprite.animation_finished.is_connected(_on_death_animation_finished):
			sprite.animation_finished.disconnect(_on_death_animation_finished)
		sprite.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		_finalize_death()


func _on_death_animation_finished() -> void:
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
	_apply_facing_visuals()
	if not is_attacking and not is_dead:
		_update_movement_animation()'''
