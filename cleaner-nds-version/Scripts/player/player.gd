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


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_apply_gravity(delta)

	if _hitstun_timer > 0.0:
		_handle_hitstun(delta)
	else:
		_handle_jump()
		_handle_horizontal_movement(delta)
		_handle_shoot()
		_update_facing()

	move_and_slide()
	_update_animation()


func _update_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = max(_fire_timer - delta, 0.0)

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer = max(_shoot_anim_timer - delta, 0.0)

	if _hitstun_timer > 0.0:
		_hitstun_timer = max(_hitstun_timer - delta, 0.0)

	if _invuln_timer > 0.0:
		_invuln_timer = max(_invuln_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_hitstun(delta: float) -> void:
	_input_dir = 0.0
	velocity.x = move_toward(velocity.x, 0.0, hit_friction * delta)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _handle_horizontal_movement(delta: float) -> void:
	_input_dir = Input.get_axis("move_left", "move_right")

	if _input_dir != 0.0:
		var accel := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, _input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_just_pressed("shoot"):
		return

	if _fire_timer > 0.0 or _hitstun_timer > 0.0:
		return

	if bullet_scene == null:
		push_warning("Player bullet_scene is not assigned.")
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	_fire_timer = fire_cooldown
	_shoot_anim_timer = shoot_anim_duration

	var direction := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)


func _update_facing() -> void:
	if _input_dir < 0.0:
		_facing_left = true
	elif _input_dir > 0.0:
		_facing_left = false

	sprite.flip_h = _facing_left

	if muzzle != null:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)


func _update_animation() -> void:
	if _is_dead:
		_play_animation_if_available("death")
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

	_hitstun_timer = hitstun_duration
	_invuln_timer = damage_invuln_duration
	_shoot_anim_timer = 0.0

	if info != null:
		velocity += info.knockback

	sprite.flip_h = _facing_left

	if muzzle != null:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)

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
	_hitstun_timer = 0.0
	_invuln_timer = 0.0
	_fire_timer = 0.0
	_shoot_anim_timer = 0.0
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



















'''extends CharacterBody2D
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


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_health_died):
			health.died.connect(_on_health_died)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_timers(delta)
	_apply_gravity(delta)

	if _hitstun_timer > 0.0:
		_handle_hitstun(delta)
	else:
		_handle_jump()
		_handle_horizontal_movement(delta)
		_handle_shoot()
		_update_facing()

	move_and_slide()
	_update_animation()


func _update_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = max(_fire_timer - delta, 0.0)

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer = max(_shoot_anim_timer - delta, 0.0)

	if _hitstun_timer > 0.0:
		_hitstun_timer = max(_hitstun_timer - delta, 0.0)

	if _invuln_timer > 0.0:
		_invuln_timer = max(_invuln_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_hitstun(delta: float) -> void:
	_input_dir = 0.0
	velocity.x = move_toward(velocity.x, 0.0, hit_friction * delta)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _handle_horizontal_movement(delta: float) -> void:
	_input_dir = Input.get_axis("move_left", "move_right")

	if _input_dir != 0.0:
		var accel := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, _input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_just_pressed("shoot"):
		return

	if _fire_timer > 0.0 or _hitstun_timer > 0.0:
		return

	if bullet_scene == null:
		push_warning("Player bullet_scene is not assigned.")
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	_fire_timer = fire_cooldown
	_shoot_anim_timer = shoot_anim_duration

	var direction := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)


func _update_facing() -> void:
	if _input_dir < 0.0:
		_facing_left = true
	elif _input_dir > 0.0:
		_facing_left = false

	sprite.flip_h = _facing_left

	if muzzle != null:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)


func _update_animation() -> void:
	if _is_dead:
		_play_animation_if_available("death")
		return

	if _hitstun_timer > 0.0:
		_play_animation_if_available("get_hit")
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
	if _is_dead:
		return

	if _invuln_timer > 0.0:
		return

	if health == null:
		push_warning("Player has no Health node.")
		return

	health.apply_damage(info)


func _on_damaged(info: DamageInfo) -> void:
	if _is_dead:
		return

	_hitstun_timer = hitstun_duration
	_invuln_timer = damage_invuln_duration
	_shoot_anim_timer = 0.0

	if info != null:
		velocity += info.knockback

	# Do NOT force facing on hit.
	sprite.flip_h = _facing_left

	if muzzle != null:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)

	_play_animation_if_available("get_hit")


func _on_health_died() -> void:
	kill()


func is_facing_left() -> bool:
	return _facing_left


func kill() -> void:
	if _is_dead:
		return

	_is_dead = true
	_hitstun_timer = 0.0
	_invuln_timer = 0.0
	velocity = Vector2.ZERO

	_play_animation_if_available("death")
	died.emit()
	queue_free()'''
