extends CharacterBody2D
class_name EnemyBasic

signal died(enemy: Node)

@export var move_speed: float = 70.0
@export var max_health: int = 2
@export var point_value: int = 100
@export var contact_damage: int = 1

@export var hit_flash_color: Color = Color(0.728, 0.0, 0.142, 1.0)
@export var hit_flash_return_time: float = 0.18
@export var hit_shake_amount: float = 4.0
@export var hit_shake_step_time: float = 0.035

var current_health: int = 0
var is_dead: bool = false
var hit_tween: Tween = null
var original_sprite_position: Vector2 = Vector2.ZERO
var original_sprite_modulate: Color = Color.WHITE

@onready var hurtbox: Area2D = $Hurtbox
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	current_health = max_health

	if sprite != null:
		original_sprite_position = sprite.position
		original_sprite_modulate = sprite.modulate

	if hurtbox != null:
		hurtbox.set_meta("owner_enemy", self)


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

	if hit_tween != null:
		hit_tween.kill()
		hit_tween = null

	GameState.add_kill(point_value)
	died.emit(self)

	var level: Node = get_tree().current_scene

	if level != null and level.has_method("shake_camera"):
		level.shake_camera(0.25)

	_scale_and_die()


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
