extends CharacterBody2D
class_name Player

@export var move_speed: float = 260.0
@export var lane_left_limit: float = 80.0
@export var lane_right_limit: float = 560.0

@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.18

@export var max_health: int = 3
@export var current_health: int = 3

var can_shoot: bool = true
var shot_mode: StringName = &"single"
var base_fire_cooldown: float = 0.18

@onready var muzzle: Node2D = $Muzzle
@onready var shoot_timer: Timer = $ShootTimer
@onready var shot_sound: AudioStreamPlayer = $ShotSound
@onready var shotgun_sound: AudioStreamPlayer = $ShotgunSound


func _ready() -> void:
	base_fire_cooldown = fire_cooldown
	current_health = max_health

	if shoot_timer != null:
		shoot_timer.one_shot = true
		shoot_timer.wait_time = fire_cooldown

		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)

	if not GameState.killstreak_changed.is_connected(_on_killstreak_changed):
		GameState.killstreak_changed.connect(_on_killstreak_changed)


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		velocity = Vector2.ZERO
		return

	_handle_movement()
	_handle_shooting()

	move_and_slide()
	_clamp_to_lane()


func _handle_movement() -> void:
	var input_x: float = Input.get_axis("move_left", "move_right")

	velocity.x = input_x * move_speed
	velocity.y = 0.0


func _handle_shooting() -> void:
	if not Input.is_action_pressed("shoot"):
		return

	if not can_shoot:
		return

	shoot()


func shoot() -> void:
	if bullet_scene == null:
		push_warning("Player: bullet_scene is not assigned.")
		return

	can_shoot = false

	if shot_mode == &"spread":
		_play_shotgun_sound()
		_fire_spread()
	else:
		_play_shot_sound()
		_fire_single()

	if shoot_timer != null:
		shoot_timer.start()


func _fire_single() -> void:
	_spawn_bullet(Vector2.UP)


func _fire_spread() -> void:
	_spawn_bullet(Vector2.UP)
	_spawn_bullet(Vector2(-0.1, -1.0).normalized())
	_spawn_bullet(Vector2(0.1, -1.0).normalized())


func _spawn_bullet(direction: Vector2) -> void:
	var bullet: Node = bullet_scene.instantiate()

	get_tree().current_scene.add_child(bullet)

	if muzzle != null:
		bullet.global_position = muzzle.global_position
	else:
		bullet.global_position = global_position

	if bullet.has_method("setup"):
		bullet.setup(direction, self)


func _play_shot_sound() -> void:
	if shot_sound == null:
		return

	shot_sound.stop()
	shot_sound.play()


func _play_shotgun_sound() -> void:
	if shotgun_sound == null:
		return

	shotgun_sound.stop()
	shotgun_sound.play()


func take_damage(amount: int = 1, attacker: Node = null) -> void:
	if GameState.is_game_over:
		return

	current_health -= amount

	if current_health <= 0:
		current_health = 0
		die()


func heal(amount: int = 1) -> void:
	if amount <= 0:
		return

	current_health += amount

	if current_health > max_health:
		current_health = max_health


func apply_powerup(powerup_type: StringName) -> void:
	if powerup_type == &"spread":
		shot_mode = &"spread"

	if powerup_type == &"rapid":
		fire_cooldown = 0.09

	if shoot_timer != null:
		shoot_timer.wait_time = fire_cooldown


func die() -> void:
	var level: Node = get_tree().current_scene

	if level != null and level.has_method("shake_camera"):
		level.shake_camera(0.75)

	GameState.trigger_game_over("The last soldier has fallen.")


func _clamp_to_lane() -> void:
	var clamped_x: float = clamp(global_position.x, lane_left_limit, lane_right_limit)
	global_position.x = clamped_x


func _on_shoot_timer_timeout() -> void:
	can_shoot = true


func _on_killstreak_changed(streak: int) -> void:
	if streak < 10:
		fire_cooldown = base_fire_cooldown
	else:
		fire_cooldown = base_fire_cooldown * 0.7

	if shoot_timer != null:
		shoot_timer.wait_time = fire_cooldown
