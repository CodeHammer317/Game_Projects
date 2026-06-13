extends CharacterBody2D
class_name CatOverlord

@export var move_speed: float = 60.0
@export var gravity: float = 900.0

@export var cat_projectile_scene: PackedScene
@export var shoot_cooldown: float = 1.8
@export var shoot_range: float = 420.0
@export var stop_distance: float = 180.0
@export var projectile_speed: float = 300.0

@export var max_health: int = 12
@export var damage_flash_time: float = 0.12

var current_health: int = 0
var player: Node2D = null
var facing_direction: int = 1
var shoot_timer: float = 0.0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $Muzzle
@onready var shoot_sound: AudioStreamPlayer2D = get_node_or_null("ShootSound")
@onready var hit_sound: AudioStreamPlayer2D = get_node_or_null("HitSound")


func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player") as Node2D


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
		return

	shoot_timer -= delta

	_apply_gravity(delta)
	_face_player()
	_move_logic()
	_try_shoot()

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0


func _face_player() -> void:
	if player.global_position.x > global_position.x:
		facing_direction = 1
	else:
		facing_direction = -1

	if sprite != null:
		sprite.flip_h = facing_direction < 0

	if muzzle != null:
		muzzle.position.x = absf(muzzle.position.x) * facing_direction


func _move_logic() -> void:
	var distance_to_player: float = global_position.distance_to(player.global_position)

	if distance_to_player > stop_distance:
		velocity.x = facing_direction * move_speed
	else:
		velocity.x = 0.0


func _try_shoot() -> void:
	if cat_projectile_scene == null:
		return

	if shoot_timer > 0.0:
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)

	if distance_to_player > shoot_range:
		return

	shoot_timer = shoot_cooldown
	_shoot_cat()


func _shoot_cat() -> void:
	var cat: Node2D = cat_projectile_scene.instantiate() as Node2D
	if cat == null:
		return

	get_tree().current_scene.add_child(cat)

	if muzzle != null:
		cat.global_position = muzzle.global_position
	else:
		cat.global_position = global_position

	var target_position: Vector2 = player.global_position
	target_position.y -= 12.0

	var direction: Vector2 = target_position - cat.global_position

	if direction == Vector2.ZERO:
		direction = Vector2(facing_direction, 0.0)

	if cat.has_method("setup"):
		cat.setup(direction.normalized(), self)

	if "speed" in cat:
		cat.speed = projectile_speed

	if shoot_sound != null:
		shoot_sound.play()


func apply_damage(info) -> void:
	if is_dead:
		return

	var amount: int = 1

	if info is DamageInfo:
		amount = info.damage
	elif info is int:
		amount = info

	current_health -= amount

	if hit_sound != null:
		hit_sound.play()

	_flash_damage()

	if current_health <= 0:
		_die()


func _flash_damage() -> void:
	if sprite == null:
		return

	sprite.modulate = Color.RED
	await get_tree().create_timer(damage_flash_time).timeout

	if not is_dead:
		sprite.modulate = Color.WHITE


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	queue_free()
