extends CharacterBody2D
class_name EnemyBase

@export var gravity: float = 900.0
@export var patrol_speed: float = 40.0
@export var patrol_distance: float = 80.0
@export var accel: float = 400.0

@export var bullet_scene: PackedScene
@export var fire_range: float = 160.0
@export var fire_cooldown: float = 1.2

var _start_position: Vector2
var _patrol_direction: int = -1
var _fire_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var player: Node2D = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	_start_position = global_position

	hurtbox.damaged.connect(_on_hurtbox_damaged)
	health.damaged.connect(_on_health_damaged)
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	_face_player()

	var distance_to_player := 99999.0
	if player:
		distance_to_player = global_position.distance_to(player.global_position)

	# Stop moving if firing range is met
	if distance_to_player <= fire_range:
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		_try_fire_at_player(delta)
	else:
		_process_patrol(delta)

	move_and_slide()

# -------------------------
# PATROL
# -------------------------
func _process_patrol(delta: float) -> void:
	var dist := absf(global_position.x - _start_position.x)
	if dist >= patrol_distance:
		_patrol_direction *= -1

	var target_speed := float(_patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

# -------------------------
# FACING
# -------------------------
func _face_player() -> void:
	if player:
		sprite.flip_h = player.global_position.x < global_position.x

# -------------------------
# FIRING
# -------------------------
func _try_fire_at_player(delta: float) -> void:
	if not player or not bullet_scene:
		return

	_fire_timer -= delta

	if _fire_timer > 0.0:
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player > fire_range:
		return

	# Instantiate projectile
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position

	# Set instigator (your projectile expects this)
	bullet.instigator = self

	# Compute direction toward player
	var direction := (player.global_position - global_position).normalized()

	# Launch using your projectile API
	bullet.launch(direction)

	# Add to scene
	get_tree().current_scene.add_child(bullet)

	# Reset cooldown
	_fire_timer = fire_cooldown

# -------------------------
# DAMAGE FLOW
# -------------------------
func _on_hurtbox_damaged(info: DamageInfo) -> void:
	health.apply_damage(info)

func _on_health_damaged(info: DamageInfo) -> void:
	velocity += info.knockback
	_on_hit_effects()

func _on_died() -> void:
	_on_death_effects()
	queue_free()

func _on_hit_effects() -> void:
	pass

func _on_death_effects() -> void:
	pass
