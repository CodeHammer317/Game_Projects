extends CharacterBody2D
class_name EnemyBasic

signal died(enemy: Node)

@export var move_speed: float = 70.0
@export var max_health: int = 2
@export var point_value: int = 100
@export var contact_damage: int = 1

@export var can_shoot: bool = true
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 5.4
@export var shoot_delay_min: float = 0.3
@export var shoot_delay_max: float = 1.0

@export var powerup_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var powerup_drop_chance: float = 1.0

@export var hit_flash_color: Color = Color(0.728, 0.0, 0.142, 1.0)
@export var hit_flash_return_time: float = 0.18
@export var hit_shake_amount: float = 4.0
@export var hit_shake_step_time: float = 0.035

var current_health: int = 0
var is_dead: bool = false
var hit_tween: Tween = null
var original_sprite_position: Vector2 = Vector2.ZERO
var original_sprite_modulate: Color = Color.WHITE

var powerup_pool: Array[int] = [
	Powerup.PowerupType.HEALTH,
	Powerup.PowerupType.RAPID_FIRE,
	Powerup.PowerupType.SPREAD_SHOT,
	Powerup.PowerupType.SHIELD,
	Powerup.PowerupType.BOMB
]

@onready var hurtbox: Area2D = $Hurtbox
@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Node2D = $Muzzle
@onready var shoot_timer: Timer = $ShootTimer


func _ready() -> void:
	randomize()
	current_health = max_health

	if sprite != null:
		original_sprite_position = sprite.position
		original_sprite_modulate = sprite.modulate

	if hurtbox != null:
		hurtbox.set_meta("owner_enemy", self)

	if shoot_timer != null:
		shoot_timer.one_shot = true

		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)

		var first_delay: float = randf_range(shoot_delay_min, shoot_delay_max)
		shoot_timer.start(first_delay)


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		velocity = Vector2.ZERO
		return

	if is_dead:
		velocity = Vector2.ZERO
		return

	velocity.x = 0.0
	velocity.y = move_speed

	move_and_slide()


func take_damage(amount: int = 1, attacker: Node = null) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	current_health -= amount
	_play_hit_feedback()

	if current_health <= 0:
		current_health = 0
		die()
		return


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	if shoot_timer != null:
		shoot_timer.stop()

	if hit_tween != null:
		hit_tween.kill()
		hit_tween = null

	GameState.add_kill(point_value)
	died.emit(self)

	var camera: CameraShake = get_tree().get_first_node_in_group("camera_shake") as CameraShake

	if camera != null:
		camera.shake(0.7)

	call_deferred("_try_spawn_powerup")
	_scale_and_die()


func shoot() -> void:
	if is_dead:
		return

	if GameState.is_game_over:
		return

	if not can_shoot:
		return

	if bullet_scene == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	if muzzle != null:
		bullet.global_position = muzzle.global_position
	else:
		bullet.global_position = global_position

	if bullet.has_method("setup"):
		bullet.setup(Vector2.DOWN, self)


func _on_shoot_timer_timeout() -> void:
	shoot()

	if is_dead:
		return

	if GameState.is_game_over:
		return

	if shoot_timer != null:
		shoot_timer.start(shoot_cooldown)


func _try_spawn_powerup() -> void:
	if powerup_scene == null:
		return

	if randf() > powerup_drop_chance:
		return

	var powerup: Powerup = powerup_scene.instantiate() as Powerup

	if powerup == null:
		return

	powerup.global_position = global_position

	var random_type: int = _get_random_powerup_type()
	powerup.setup(random_type)

	get_tree().current_scene.call_deferred("add_child", powerup)


func _get_random_powerup_type() -> int:
	if powerup_pool.is_empty():
		return Powerup.PowerupType.HEALTH

	var index: int = randi() % powerup_pool.size()
	return powerup_pool[index]


func _play_hit_feedback() -> void:
	if sprite == null:
		return

	if hit_tween != null:
		hit_tween.kill()

	sprite.position = original_sprite_position
	sprite.modulate = hit_flash_color

	hit_tween = create_tween()
	hit_tween.tween_property(sprite, "position:x", original_sprite_position.x - hit_shake_amount, hit_shake_step_time)
	hit_tween.tween_property(sprite, "position:x", original_sprite_position.x + hit_shake_amount, hit_shake_step_time)
	hit_tween.tween_property(sprite, "position:x", original_sprite_position.x, hit_shake_step_time)
	hit_tween.parallel().tween_property(sprite, "modulate", original_sprite_modulate, hit_flash_return_time)


func _scale_and_die() -> void:
	if sprite == null:
		queue_free()
		return

	var tween: Tween = create_tween()

	tween.tween_property(sprite, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.08)

	tween.finished.connect(queue_free)
