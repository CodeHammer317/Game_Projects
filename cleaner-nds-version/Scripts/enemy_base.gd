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
@export var hurt_animation_name: StringName = &"Hurt"
@export var hurt_animation_lock_time: float = 0.20

@export var player_group: StringName = &"player"
@export var detection_range: float = 220.0
@export var attack_range: float = 96.0
@export var stop_distance: float = 8.0

@export var attack_cooldown: float = 1.2
@export var attack_windup: float = 0.18
@export var random_attack_variant: bool = true
@export var projectile_scene: PackedScene
@export var mirror_muzzle_with_facing: bool = false
@export var melee_attack_variants: Array[int] = []
@export var melee_range: float = 52.0
@export var melee_damage: int = 1
@export var melee_knockback: Vector2 = Vector2(110.0, -25.0)

@export var flee_speed_multiplier: float = 1.6
@export var flee_duration: float = 0.60

@export var explosion_animation_name: StringName = &"Explosion"
@export var explosion_delay: float = 0.08
@export var wait_for_explosion_before_free: bool = true

@export var use_machine_sound_while_moving: bool = true
@export var use_machine_sound_on_attack: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var explosion_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D2") as AnimatedSprite2D
@onready var health: Health = $Health
@onready var muzzle: Node2D = get_node_or_null("Muzzle")

@onready var machine_sound: AudioStreamPlayer = get_node_or_null("MachineSound")
@onready var explosion_sound: AudioStreamPlayer = get_node_or_null("ExplosionSound")

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
var _hurt_animation_timer: float = 0.0

var _death_anim_done: bool = false
var _explosion_anim_done: bool = false


func _ready() -> void:
	if machine_sound == null and (use_machine_sound_while_moving or use_machine_sound_on_attack):
		push_warning("%s: MachineSound node not found." % name)

	if explosion_sound == null and explosion_sprite != null:
		push_warning("%s: ExplosionSound node not found." % name)

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
		_stop_machine_sound()
		return

	_update_timers(delta)
	_find_target_if_needed()
	_process_ai(delta)

	_apply_gravity(delta)
	move_and_slide()

	if not is_attacking and _hurt_animation_timer <= 0.0 and auto_play_movement_animations:
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

	if _hurt_animation_timer > 0.0:
		_hurt_animation_timer = max(_hurt_animation_timer - delta, 0.0)


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
		_stop_machine_sound()
		return

	if _target == null or not is_instance_valid(_target):
		velocity.x = 0.0
		_stop_machine_sound()
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

	if _flee_timer > 0.0 and _flee_from != null and is_instance_valid(_flee_from):
		_process_flee()
		return

	if dist > detection_range:
		velocity.x = 0.0
		_stop_machine_sound()
		return

	if dist <= attack_range:
		velocity.x = 0.0
		_stop_machine_sound()
		_face_toward(_target.global_position)

		if _attack_cooldown_timer <= 0.0:
			start_attack()
		return

	_move_toward_target()


func _move_toward_target() -> void:
	if _target == null:
		velocity.x = 0.0
		_stop_machine_sound()
		return

	var dx: float = _target.global_position.x - global_position.x

	if absf(dx) <= stop_distance:
		velocity.x = 0.0
		_stop_machine_sound()
		return

	velocity.x = sign(dx) * move_speed
	_face_toward(_target.global_position)


func _process_flee() -> void:
	if _flee_from == null or not is_instance_valid(_flee_from):
		velocity.x = 0.0
		_stop_machine_sound()
		return

	var dx: float = global_position.x - _flee_from.global_position.x

	if absf(dx) <= 1.0:
		dx = -1.0 if facing_right else 1.0

	velocity.x = sign(dx) * move_speed * flee_speed_multiplier
	_update_facing_from_velocity()


func _face_toward(world_pos: Vector2) -> void:
	facing_right = world_pos.x > global_position.x
	if not use_separate_directional_animations and sprite != null:
		sprite.flip_h = not facing_right
	if mirror_muzzle_with_facing and muzzle != null:
		muzzle.position.x = absf(muzzle.position.x) if facing_right else -absf(muzzle.position.x)


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
	var is_moving := absf(velocity.x) > 4.0

	if is_moving:
		_play_move()
		_play_machine_sound()
	else:
		_play_idle()
		_stop_machine_sound()


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

	_stop_machine_sound()

	var available_variants: Array[int] = []
	var use_melee := (
		not melee_attack_variants.is_empty()
		and _target != null
		and is_instance_valid(_target)
		and global_position.distance_to(_target.global_position) <= melee_range
	)

	for variant in range(1, 4):
		if not _has_animation("Fire%d" % variant):
			continue

		var is_melee_variant := melee_attack_variants.has(variant)
		if melee_attack_variants.is_empty() or is_melee_variant == use_melee:
			available_variants.append(variant)

	if available_variants.is_empty():
		finish_attack()
		return

	if random_attack_variant:
		current_attack_variant = available_variants.pick_random()
	else:
		current_attack_variant = available_variants[0]

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

	if use_machine_sound_on_attack:
		if not melee_attack_variants.has(current_attack_variant):
			_play_machine_sound(true)

	if melee_attack_variants.has(current_attack_variant):
		_do_melee_attack()
		return

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


func _do_melee_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	if global_position.distance_to(_target.global_position) > melee_range:
		return

	if not _target.has_method("apply_damage"):
		return

	var direction := 1.0 if facing_right else -1.0
	var info := DamageInfo.new(
		melee_damage,
		Vector2(direction * melee_knockback.x, melee_knockback.y),
		self
	)
	_target.apply_damage(info)


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

	if _has_animation(hurt_animation_name):
		_hurt_animation_timer = hurt_animation_lock_time
		sprite.play(hurt_animation_name)

	CombatFx.hitstop(0.03, 0.08)
	CombatFx.shake(2.0, 0.08, 24.0)

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

	_stop_machine_sound()

	CombatFx.hitstop(0.05, 0.05)
	CombatFx.shake(5.0, 0.16, 20.0)

	if _has_animation("Death"):
		sprite.play("Death")
	else:
		_death_anim_done = true

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

	_play_explosion_sound()

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


func _play_machine_sound(force_restart: bool = false) -> void:
	if machine_sound == null:
		return

	if not use_machine_sound_while_moving and not force_restart:
		return

	if force_restart:
		machine_sound.stop()
		machine_sound.play()
		return

	if not machine_sound.playing:
		machine_sound.play()


func _stop_machine_sound() -> void:
	if machine_sound == null:
		return

	if machine_sound.playing:
		machine_sound.stop()


func _play_explosion_sound() -> void:
	if explosion_sound == null:
		return

	explosion_sound.stop()
	explosion_sound.play()


func _has_animation(anim_name: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)
	
func take_damage(amount: int, attacker: Node = null) -> void:
	var info := DamageInfo.new(amount, Vector2.ZERO, attacker)
	apply_damage(info)
	
func apply_damage(info: DamageInfo) -> void:
	if is_dead:
		return

	if health == null:
		return

	health.apply_damage(info)

func set_facing_right(value: bool) -> void:
	facing_right = value
	if not use_separate_directional_animations and sprite != null:
		sprite.flip_h = not facing_right
	if mirror_muzzle_with_facing and muzzle != null:
		muzzle.position.x = absf(muzzle.position.x) if facing_right else -absf(muzzle.position.x)
	if not is_attacking and not is_dead:
		_update_movement_animation()
