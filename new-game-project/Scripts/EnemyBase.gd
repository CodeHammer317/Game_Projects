extends CharacterBody2D
class_name EnemyBase

# -----------------------------
# EXPORTED SETTINGS
# -----------------------------
@export var max_speed: float = 60.0
@export var gravity: float = 900.0
@export var friction: float = 600.0
@export var accel: float = 400.0

@export var patrol_speed: float = 40.0
@export var patrol_distance: float = 80.0

# -----------------------------
# INTERNAL STATE
# -----------------------------
var _facing_left: bool = true
var _start_position: Vector2
var _patrol_direction: int = -1
#var _velocity: Vector2 = Vector2.ZERO

# -----------------------------
# NODE REFERENCES
# -----------------------------
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var health: Health = get_node_or_null("Health")
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox")

# -----------------------------
# READY
# -----------------------------
func _ready() -> void:
	_start_position = global_position

	if hurtbox != null:
		hurtbox.connect("damaged", Callable(self, "_on_damaged"))

	if health != null:
		health.connect("died", Callable(self, "_on_died"))

# -----------------------------
# MAIN LOOP
# -----------------------------
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_process_ai(delta)
	_update_facing()
	move_and_slide()

# -----------------------------
# GRAVITY
# -----------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# -----------------------------
# SIMPLE PATROL AI
# -----------------------------
func _process_ai(delta: float) -> void:
	# Basic left-right patrol
	var distance_from_start := absf(global_position.x - _start_position.x)

	if distance_from_start >= patrol_distance:
		_patrol_direction *= -1

	var target_speed := float(_patrol_direction) * patrol_speed

	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

# -----------------------------
# FACING
# -----------------------------
func _update_facing() -> void:
	if velocity.x < 0.0:
		_facing_left = true
	elif velocity.x > 0.0:
		_facing_left = false

	if sprite != null:
		sprite.flip_h = _facing_left

# -----------------------------
# DAMAGE REACTION
# -----------------------------
func _on_damaged(info: DamageInfo) -> void:
	# Knockback
	velocity.x = info.knockback.x
	velocity.y = info.knockback.y

	# Optional: flash, play animation, sound, etc.
	_on_hit_effects()

func _on_hit_effects() -> void:
	# Override in child classes for custom behavior
	pass

# -----------------------------
# DEATH
# -----------------------------
func _on_died() -> void:
	_on_death_effects()
	queue_free()

func _on_death_effects() -> void:
	# Override in child classes for particles, sound, loot, etc.
	pass
