extends CharacterBody2D
class_name EnemyBase

@export var gravity: float = 900.0
@export var patrol_speed: float = 40.0
@export var patrol_distance: float = 80.0
@export var accel: float = 400.0

var _start_position: Vector2
var _patrol_direction: int = -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	_start_position = global_position

	hurtbox.damaged.connect(_on_hurtbox_damaged)
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	_process_patrol(delta)
	move_and_slide()

func _process_patrol(delta: float) -> void:
	var dist := absf(global_position.x - _start_position.x)
	if dist >= patrol_distance:
		_patrol_direction *= -1

	var target_speed := float(_patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	if sprite:
		sprite.flip_h = velocity.x < 0

# --- Damage Flow ---

func _on_hurtbox_damaged(info: DamageInfo) -> void:
	health.apply_damage(info)

func _on_health_damaged(info: DamageInfo) -> void:
	# Knockback happens AFTER health confirmed
	velocity += info.knockback
	_on_hit_effects()

func _on_died() -> void:
	_on_death_effects()
	queue_free()

func _on_hit_effects() -> void:
	pass

func _on_death_effects() -> void:
	pass
