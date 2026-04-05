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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _is_dead: bool = false
var _input_dir: float = 0.0


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_fire_timer(delta)
	_update_shoot_anim_timer(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)
	_handle_shoot()
	_update_facing()

	move_and_slide()
	_update_animation()


func _update_fire_timer(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer = max(_fire_timer - delta, 0.0)


func _update_shoot_anim_timer(delta: float) -> void:
	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer = max(_shoot_anim_timer - delta, 0.0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _handle_horizontal_movement(delta: float) -> void:
	_input_dir = Input.get_axis("move_left", "move_right")

	if _input_dir != 0.0:
		var accel: float = acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, _input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_just_pressed("shoot"):
		return

	if _fire_timer > 0.0:
		return

	if bullet_scene == null:
		push_warning("Player bullet_scene is not assigned.")
		return

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	_fire_timer = fire_cooldown
	_shoot_anim_timer = shoot_anim_duration

	var direction: Vector2 = Vector2.LEFT if _facing_left else Vector2.RIGHT

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

	if muzzle:
		muzzle.position = Vector2(
			-muzzle_offset_right.x if _facing_left else muzzle_offset_right.x,
			muzzle_offset_right.y
		)


func _update_animation() -> void:
	if _is_dead:
		_play_animation_if_available("death")
		return

	var is_shooting: bool = _shoot_anim_timer > 0.0
	var is_running: bool = absf(_input_dir) > 0.0 and absf(velocity.x) > 8.0

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


func is_facing_left() -> bool:
	return _facing_left


func kill() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()
















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
@export var bullet_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _is_dead: bool = false

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_update_fire_timer(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal_movement(delta)
	_handle_shoot()
	_update_facing()
	_update_animation()

	move_and_slide()


func _update_fire_timer(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
		if _fire_timer < 0.0:
			_fire_timer = 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y > max_fall_speed:
			velocity.y = max_fall_speed
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


func _handle_horizontal_movement(delta: float) -> void:
	var input_dir: float = Input.get_axis("move_left", "move_right")

	if input_dir != 0.0:
		var accel := acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, input_dir * move_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_just_pressed("shoot"):
		return

	if _fire_timer > 0.0:
		return

	if bullet_scene == null:
		push_warning("Player bullet_scene is not assigned.")
		return

	_fire_timer = fire_cooldown

	var bullet := bullet_scene.instantiate()
	if bullet == null:
		return

	var direction := Vector2.LEFT if _facing_left else Vector2.RIGHT

	get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)


func _update_facing() -> void:
	if velocity.x < -0.01:
		_facing_left = true
	elif velocity.x > 0.01:
		_facing_left = false

	sprite.flip_h = _facing_left


func _update_animation() -> void:
	if _is_dead:
		_play_if_exists("death")
		return

	if not is_on_floor():
		if velocity.y > 0.0:
			_play_if_exists("jump")
		else:
			_play_if_exists("fall")
		return

	if absf(velocity.x) > 8.0:
		_play_if_exists("run")
	else:
		_play_if_exists("idle")


func _play_if_exists(anim_name: StringName) -> void:
	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name) and sprite.animation != anim_name:
		sprite.play(anim_name)


func kill() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	died.emit()
func is_facing_left() -> bool:
	return _facing_left'''
