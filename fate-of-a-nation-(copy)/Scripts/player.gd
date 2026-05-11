extends CharacterBody2D
class_name Player

signal health_changed(current_health: int, max_health: int)
signal fired_bullet(bullet: Node)
signal died

@export var max_health: int = 10

@export var move_speed: float = 145.0
@export var acceleration: float = 900.0
@export var friction: float = 1000.0

@export var fire_cooldown: float = 0.18
@export var rapid_fire_cooldown: float = 0.08
@export var shoot_anim_duration: float = 0.10
@export var bullet_scene: PackedScene
@export var floating_text_scene: PackedScene
@export var muzzle_offset_right: Vector2 = Vector2(10.0, -2.0)

@export var hitstun_duration: float = 0.14
@export var damage_invuln_duration: float = 0.30
@export var hit_friction: float = 700.0

@export var hit_flash_color: Color = Color(1.0, 1.0, 0.031, 0.671)
@export var hit_flash_count: int = 2
@export var hit_flash_interval: float = 0.25

@export var death_blink_duration: float = 0.60
@export var death_blink_interval: float = 0.1

var current_health: int = 0

var lane_left_limit: float = 0.0
var lane_right_limit: float = 640.0

var rapid_fire_active: bool = false
var spread_shot_active: bool = false
var shield_active: bool = false

var _facing_left: bool = false
var _fire_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _hitstun_timer: float = 0.0
var _invuln_timer: float = 0.0

var _is_dead: bool = false
var _is_dying: bool = false
var _is_hit_flashing: bool = false

var _input_vector: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle

@onready var shoot_sound: AudioStreamPlayer = get_node_or_null("Audio/ShootSound")
@onready var shotgun_sound: AudioStreamPlayer = get_node_or_null("Audio/ShotgunSound")
@onready var hit_sound: AudioStreamPlayer = get_node_or_null("Audio/HitSound")
@onready var shield_sound: AudioStreamPlayer = get_node_or_null("Audio/ShieldSound")
@onready var powerup_sound: AudioStreamPlayer = get_node_or_null("Audio/PowerupSound")
@onready var heal_sound: AudioStreamPlayer = get_node_or_null("Audio/HealSound")
@onready var bomb_sound: AudioStreamPlayer = get_node_or_null("Audio/BombSound")
@onready var death_sound: AudioStreamPlayer = get_node_or_null("Audio/DeathSound")


func _ready() -> void:
	print("PLAYER READY STARTED:", name)

	add_to_group("player")

	print("PLAYER IS IN GROUP:", is_in_group("player"))

	current_health = max_health
	health_changed.emit(current_health, max_health)
	_update_muzzle_position()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if GameState.is_game_over:
		velocity = Vector2.ZERO
		return

	_update_timers(delta)

	if _hitstun_timer > 0.0:
		_handle_hitstun(delta)
	else:
		_handle_movement(delta)
		_handle_shoot()
		_update_facing()

	move_and_slide()
	_apply_lane_limits()
	_update_animation()


func _update_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
		if _fire_timer < 0.0:
			_fire_timer = 0.0

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
		if _shoot_anim_timer < 0.0:
			_shoot_anim_timer = 0.0

	if _hitstun_timer > 0.0:
		_hitstun_timer -= delta
		if _hitstun_timer < 0.0:
			_hitstun_timer = 0.0

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		if _invuln_timer < 0.0:
			_invuln_timer = 0.0


func _handle_movement(delta: float) -> void:
	_input_vector = Vector2.ZERO
	_input_vector.x = Input.get_axis("move_left", "move_right")
	_input_vector.y = Input.get_axis("move_up", "move_down")

	if _input_vector.length() > 1.0:
		_input_vector = _input_vector.normalized()

	if _input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(_input_vector * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _handle_hitstun(delta: float) -> void:
	_input_vector = Vector2.ZERO
	velocity = velocity.move_toward(Vector2.ZERO, hit_friction * delta)


func _handle_shoot() -> void:
	if not Input.is_action_pressed("shoot"):
		return

	if not _can_shoot():
		return

	if spread_shot_active:
		_fire_spread_shot()
		_play_sound(shotgun_sound)
	else:
		_fire_single_bullet(_get_forward_direction())
		_play_sound(shoot_sound)

	_shoot_anim_timer = shoot_anim_duration

	if rapid_fire_active:
		_fire_timer = rapid_fire_cooldown
	else:
		_fire_timer = fire_cooldown


func _can_shoot() -> bool:
	if _is_dead:
		return false

	if _is_dying:
		return false

	if _fire_timer > 0.0:
		return false

	if _hitstun_timer > 0.0:
		return false

	if bullet_scene == null:
		push_warning("Player: bullet_scene is not assigned.")
		return false

	if muzzle == null:
		push_warning("Player: Muzzle node is missing.")
		return false

	return true


func _fire_spread_shot() -> void:
	var forward: Vector2 = _get_forward_direction()

	_fire_single_bullet(forward.rotated(deg_to_rad(-12.0)))
	_fire_single_bullet(forward)
	_fire_single_bullet(forward.rotated(deg_to_rad(12.0)))


func _fire_single_bullet(direction: Vector2) -> void:
	if bullet_scene == null:
		return

	if muzzle == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	bullet.global_position = muzzle.global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)

	fired_bullet.emit(bullet)


func _get_forward_direction() -> Vector2:
	return Vector2.UP


func _update_facing() -> void:
	if _input_vector.x < 0.0:
		_facing_left = true

	if _input_vector.x > 0.0:
		_facing_left = false

	if sprite != null:
		sprite.flip_h = _facing_left

	_update_muzzle_position()


func _update_muzzle_position() -> void:
	if muzzle == null:
		return

	var muzzle_x: float = muzzle_offset_right.x

	if _facing_left:
		muzzle_x = -muzzle_offset_right.x

	muzzle.position = Vector2(muzzle_x, muzzle_offset_right.y)


func _apply_lane_limits() -> void:
	var pos: Vector2 = global_position
	pos.x = clamp(pos.x, lane_left_limit, lane_right_limit)
	global_position = pos


func _update_animation() -> void:
	if _is_dead:
		_play_animation_if_available("death")
		return

	var is_shooting: bool = _shoot_anim_timer > 0.0
	var is_moving: bool = velocity.length() > 8.0

	if is_moving:
		if is_shooting:
			_play_animation_with_fallback("shoot_run", "run")
		else:
			_play_animation_if_available("run")
	else:
		if is_shooting:
			_play_animation_with_fallback("shoot_idle", "idle")
		else:
			_play_animation_if_available("idle")


func _play_animation_if_available(anim_name: StringName) -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _play_animation_with_fallback(anim_name: StringName, fallback_name: StringName) -> void:
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


func apply_powerup(powerup_type: int, amount: int = 1, duration: float = 6.0) -> void:
	if _is_dead:
		return

	if _is_dying:
		return

	match powerup_type:
		Powerup.PowerupType.HEALTH:
			_heal(amount)

		Powerup.PowerupType.RAPID_FIRE:
			_activate_rapid_fire(duration)

		Powerup.PowerupType.SPREAD_SHOT:
			_activate_spread_shot(duration)

		Powerup.PowerupType.SHIELD:
			_activate_shield()

		Powerup.PowerupType.BOMB:
			_activate_bomb()
	_spawn_floating_text("RAPID", Color.YELLOW)
	_spawn_floating_text("SPREAD", Color.YELLOW)
	_spawn_floating_text("SHIELD", Color.CYAN)
	_spawn_floating_text("BOMB", Color.ORANGE)

func _heal(amount: int) -> void:
	if _is_dead:
		return

	if _is_dying:
		return

	current_health += amount
	_spawn_floating_text("+" + str(amount) + " HP", Color.GREEN)
	if current_health > max_health:
		current_health = max_health
	health_changed.emit(current_health, max_health)

	_play_sound(heal_sound)
	print("Player healed:", current_health, "/", max_health)


func _activate_rapid_fire(duration: float) -> void:
	rapid_fire_active = true
	_play_sound(powerup_sound)

	await get_tree().create_timer(duration).timeout

	rapid_fire_active = false


func _activate_spread_shot(duration: float) -> void:
	spread_shot_active = true
	_play_sound(powerup_sound)

	await get_tree().create_timer(duration).timeout

	spread_shot_active = false


func _activate_shield() -> void:
	shield_active = true
	_play_sound(shield_sound)
	print("Shield active")
	_spawn_floating_text("BLOCK", Color.BLUE)


func _activate_bomb() -> void:
	_play_sound(bomb_sound)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy == null:
			continue

		if enemy.has_method("take_damage"):
			enemy.take_damage(999, self)


func take_damage(amount: int = 1, attacker: Node = null) -> void:
	if _is_dead:
		return

	if _is_dying:
		return

	if _invuln_timer > 0.0:
		return

	if shield_active:
		shield_active = false
		_play_sound(shield_sound)
		print("Shield blocked damage")
		return

	current_health -= amount
	_spawn_floating_text("-" + str(amount), Color.RED)
	if current_health < 0:
		current_health = 0
	
	health_changed.emit(current_health, max_health)
	
	_play_sound(hit_sound)
	print("Player health:", current_health, "/", max_health)

	_on_player_damaged(attacker)

	if current_health <= 0:
		kill()


func _on_player_damaged(attacker: Node = null) -> void:
	_hitstun_timer = hitstun_duration
	_invuln_timer = damage_invuln_duration
	_shoot_anim_timer = 0.0

	if not _is_hit_flashing:
		call_deferred("_run_hit_flash")


func is_facing_left() -> bool:
	return _facing_left


func kill() -> void:
	if _is_dead:
		return

	if _is_dying:
		return

	_is_dead = true
	_is_dying = true
	_hitstun_timer = 0.0
	_invuln_timer = 0.0
	_fire_timer = 0.0
	_shoot_anim_timer = 0.0
	velocity = Vector2.ZERO
	GameState.trigger_game_over("Player died")
	_play_sound(death_sound)
	_play_animation_if_available("death")
	died.emit()

	call_deferred("_run_death_blink")
	

func _run_hit_flash() -> void:
	if _is_dead:
		return

	if _is_dying:
		return

	var target: CanvasItem = null

	if sprite != null:
		target = sprite
	else:
		target = self

	if target == null:
		return

	_is_hit_flashing = true

	var normal: Color = target.modulate

	for i in range(hit_flash_count):
		if not is_instance_valid(target):
			break

		if _is_dead:
			break

		if _is_dying:
			break

		target.modulate = hit_flash_color
		await get_tree().create_timer(hit_flash_interval).timeout

		if not is_instance_valid(target):
			break

		if _is_dead:
			break

		if _is_dying:
			break

		target.modulate = normal
		await get_tree().create_timer(hit_flash_interval).timeout

	if is_instance_valid(target):
		if not _is_dead:
			if not _is_dying:
				target.modulate = normal

	_is_hit_flashing = false


func _run_death_blink() -> void:
	var target: CanvasItem = null

	if sprite != null:
		target = sprite
	else:
		target = self

	if target == null:
		queue_free()
		return

	var elapsed: float = 0.0
	var visible_state: bool = false

	while elapsed < death_blink_duration and is_instance_valid(target):
		visible_state = not visible_state

		var c: Color = target.modulate

		if visible_state:
			c.a = 0.2
		else:
			c.a = 1.0

		target.modulate = c

		await get_tree().create_timer(death_blink_interval).timeout
		elapsed += death_blink_interval

	if is_instance_valid(target):
		var reset_color: Color = target.modulate
		reset_color.a = 1.0
		target.modulate = reset_color

	queue_free()


func _play_sound(sound: AudioStreamPlayer) -> void:
	if sound == null:
		return
	#sound.pitch_scale = randf_range(0.9, 1.0)
	#sound.volume_db = randf_range(0.0, 0.5)
	sound.stop()
	sound.play()
func _spawn_floating_text(text: String, text_color: Color = Color.WHITE) -> void:
	if floating_text_scene == null:
		return

	var floating_text: FloatingText = floating_text_scene.instantiate() as FloatingText

	if floating_text == null:
		return

	get_tree().current_scene.add_child(floating_text)
	floating_text.global_position = global_position + Vector2(0.0, -18.0)
	floating_text.setup(text, text_color)
