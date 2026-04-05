extends CharacterBody2D
class_name EnemyBase

signal died(enemy: Node)

@export var gravity: float = 900.0
@export var max_fall_speed: float = 700.0
@export var move_speed: float = 40.0

@export var use_separate_directional_animations: bool = true
@export var death_remove_delay: float = 0.0
@export var auto_play_movement_animations: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health

var facing_right: bool = false
var is_dead: bool = false
var is_attacking: bool = false
var current_attack_variant: int = 1


func _ready() -> void:
	if health != null:
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)

		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	_play_idle()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	move_and_slide()

	if not is_attacking and auto_play_movement_animations:
		_update_facing_from_velocity()
		_update_movement_animation()


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

	if sprite.sprite_frames.has_animation("Idle"):
		if sprite.animation != "Idle":
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


func play_fire_animation(variant: int = 1) -> void:
	if is_dead:
		return

	current_attack_variant = clampi(variant, 1, 3)
	is_attacking = true

	var anim_name := "Fire%d" % current_attack_variant
	if _has_animation(anim_name):
		sprite.play(anim_name)
	else:
		_play_idle()


func finish_attack() -> void:
	if is_dead:
		return

	is_attacking = false
	_update_movement_animation()


func _on_damaged(info: DamageInfo) -> void:
	if is_dead:
		return

	if info != null:
		velocity += info.knockback

	# If you add a Hurt animation later, play it here.
	# For now, keep current anim flow simple.


func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO

	if _has_animation("Death"):
		sprite.play("Death")

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


func _has_animation(anim_name: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)


func set_facing_right(value: bool) -> void:
	facing_right = value
	if not is_attacking and not is_dead:
		_update_movement_animation()
