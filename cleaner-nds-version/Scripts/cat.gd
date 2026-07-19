extends CharacterBody2D
class_name CatEnemy

signal damaged(info: DamageInfo, health_remaining: int)
signal died(enemy: Node)

@export_group("Movement")
@export var move_speed: float = 45.0
@export var gravity: float = 900.0
@export var jump_velocity: float = -260.0
@export var detection_range: float = 190.0
@export var attack_range: float = 34.0
@export var sprite_faces_left: bool = false

@export_group("Combat")
@export var max_health: int = 4
@export var contact_damage: int = 1
@export var attack_cooldown: float = 1.0
@export var damage_invulnerability: float = 0.2
@export var attack_knockback: Vector2 = Vector2(110.0, -45.0)

@export_group("Personality")
@export var hiss_interval_min: float = 3.0
@export var hiss_interval_max: float = 6.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var target: Node2D = null
var current_health: int = 0
var facing_direction: int = 1
var attack_timer: float = 0.0
var invulnerability_timer: float = 0.0
var hiss_timer: float = 0.0
var is_attacking: bool = false
var is_hissing: bool = false
var attack_connected: bool = false
var is_dead: bool = false


func _ready() -> void:
	if not is_in_group(&"enemies"):
		add_to_group(&"enemies")
	current_health = max_health
	hiss_timer = randf_range(hiss_interval_min, hiss_interval_max)
	sprite.animation_finished.connect(_on_animation_finished)
	_find_target()
	_play_animation(&"idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	invulnerability_timer = maxf(invulnerability_timer - delta, 0.0)
	hiss_timer = maxf(hiss_timer - delta, 0.0)

	if target == null or not is_instance_valid(target):
		_find_target()

	_apply_gravity(delta)

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 8.0 * delta)
		_apply_attack_frame()
	elif is_hissing:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 8.0 * delta)
	else:
		_process_behavior()

	move_and_slide()

	if not is_attacking and not is_hissing and is_on_wall() and is_on_floor():
		velocity.y = jump_velocity
		_play_animation(&"jump")


func _process_behavior() -> void:
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		_play_animation(&"idle")
		return

	var offset := target.global_position - global_position
	var distance := offset.length()
	_update_facing(offset.x)

	if distance <= attack_range and attack_timer <= 0.0:
		_start_attack()
		return

	if distance <= detection_range:
		velocity.x = facing_direction * move_speed
		_play_animation(&"walk")
		return

	velocity.x = move_toward(velocity.x, 0.0, move_speed)
	if hiss_timer <= 0.0:
		_start_hiss()
	else:
		_play_animation(&"idle")


func _start_attack() -> void:
	is_attacking = true
	attack_connected = false
	attack_timer = attack_cooldown
	velocity.x = 0.0
	_play_animation(&"attack", true)


func _apply_attack_frame() -> void:
	if attack_connected or sprite.frame < 1 or target == null:
		return
	if global_position.distance_to(target.global_position) > attack_range * 1.35:
		return
	if not target.has_method("apply_damage"):
		return

	attack_connected = true
	var knockback := Vector2(attack_knockback.x * facing_direction, attack_knockback.y)
	target.apply_damage(DamageInfo.new(contact_damage, knockback, self))


func _start_hiss() -> void:
	is_hissing = true
	hiss_timer = randf_range(hiss_interval_min, hiss_interval_max)
	velocity.x = 0.0
	_play_animation(&"hiss", true)


func _on_animation_finished() -> void:
	if sprite.animation == &"attack":
		is_attacking = false
		attack_connected = false
	elif sprite.animation == &"hiss":
		is_hissing = false
	_play_animation(&"idle", true)


func _find_target() -> void:
	target = get_tree().get_first_node_in_group(&"player") as Node2D


func _update_facing(horizontal_offset: float) -> void:
	if not is_zero_approx(horizontal_offset):
		facing_direction = 1 if horizontal_offset > 0.0 else -1
	sprite.flip_h = (facing_direction > 0) if sprite_faces_left else (facing_direction < 0)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 700.0)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _play_animation(animation_name: StringName, restart: bool = false) -> void:
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	if restart or sprite.animation != animation_name:
		sprite.play(animation_name)


func apply_damage(info: DamageInfo) -> void:
	if is_dead or info == null or invulnerability_timer > 0.0:
		return

	current_health -= info.damage
	invulnerability_timer = damage_invulnerability
	velocity += info.knockback
	damaged.emit(info, maxi(current_health, 0))

	var flash := create_tween()
	sprite.modulate = Color(1.0, 0.35, 0.45, 1.0)
	flash.tween_property(sprite, "modulate", Color.WHITE, damage_invulnerability)

	if current_health <= 0:
		_die()


func take_damage(amount: int, attacker: Node = null) -> void:
	apply_damage(DamageInfo.new(amount, Vector2.ZERO, attacker))


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	var death_tween := create_tween()
	death_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	death_tween.tween_callback(queue_free)
