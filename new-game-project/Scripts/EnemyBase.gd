extends CharacterBody2D
class_name EnemyBase

@export var gravity: float = 900.0
@export var patrol_speed: float = 40.0
@export var patrol_distance: float = 80.0
@export var accel: float = 400.0

@export var bullet_scene: PackedScene
@export var fire_range: float = 160.0
@export var fire_cooldown: float = 1.2
@export var use_line_of_sight: bool = false
@export var target_group: StringName = &"player"
@export var projectile_team: int = 2

var _start_position: Vector2
var _patrol_direction: int = -1
var _fire_timer: float = 0.0
var _target: Node2D = null
var _is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var muzzle: Node2D = get_node_or_null("Muzzle")

func _ready() -> void:
	_start_position = global_position

	if health:
		if not health.damaged.is_connected(_on_health_damaged):
			health.damaged.connect(_on_health_damaged)
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	_play_if_exists("idle")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_fire_timer = maxf(_fire_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y += gravity * delta

	_target = _get_best_target()

	if _can_attack_target(_target):
		_face_node(_target)
		velocity.x = move_toward(velocity.x, 0.0, accel * delta)
		_try_fire_at_target()
	else:
		_process_patrol(delta)

	move_and_slide()
	_update_animation()


func _get_best_target() -> Node2D:
	var candidates := get_tree().get_nodes_in_group(target_group)
	var best: Node2D = null
	var best_dist_sq := INF

	for node in candidates:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue

		var candidate := node as Node2D

		# Optional: skip dead targets if they expose a Health child/node
		var candidate_health := candidate.get_node_or_null("Health")
		if candidate_health and candidate_health.has_method("get"):
			if candidate_health.get("_is_dead"):
				continue

		var dist_sq := global_position.distance_squared_to(candidate.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate

	return best


func _can_attack_target(target: Node2D) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false

	var dist_sq := global_position.distance_squared_to(target.global_position)
	if dist_sq > fire_range * fire_range:
		return false

	if use_line_of_sight and not _has_line_of_sight(target):
		return false

	return true


func _has_line_of_sight(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.exclude = [self]

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true

	var collider = result.get("collider")
	return collider == target


func _process_patrol(delta: float) -> void:
	var offset_x := global_position.x - _start_position.x

	if offset_x <= -patrol_distance:
		_patrol_direction = 1
	elif offset_x >= patrol_distance:
		_patrol_direction = -1

	var target_speed := float(_patrol_direction) * patrol_speed
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	_face_patrol_direction()


func _face_patrol_direction() -> void:
	if sprite == null:
		return
	sprite.flip_h = _patrol_direction < 0


func _face_node(node: Node2D) -> void:
	if sprite == null:
		return
	if node == null or not is_instance_valid(node):
		return

	sprite.flip_h = node.global_position.x < global_position.x


func _try_fire_at_target() -> void:
	if bullet_scene == null:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if _fire_timer > 0.0:
		return

	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return

	var spawn_position := muzzle.global_position if muzzle else global_position

	var direction := (_target.global_position - spawn_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.LEFT if sprite and sprite.flip_h else Vector2.RIGHT

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(bullet)

	if bullet is Node2D:
		bullet.global_position = spawn_position

	# Standardize launch handling
	if bullet is Projectile:
		bullet.team = projectile_team
		bullet.launch(direction, _target, self)
	elif bullet.has_method("launch"):
		# Fallback for simpler projectile scripts
		bullet.launch(direction)

	_fire_timer = fire_cooldown
	_on_fire()


func _on_fire() -> void:
	_play_if_exists("shoot")


func _on_health_damaged(info: DamageInfo) -> void:
	if _is_dead:
		return

	velocity += info.knockback
	_flash_hit()


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	_on_death_effects()
	queue_free()


func _flash_hit() -> void:
	modulate = Color(1.425, 0.0, 0.413, 1.0)

	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			modulate = Color(1.0, 1.0, 1.0, 1.0)
	)


func _update_animation() -> void:
	if sprite == null or _is_dead:
		return

	if absf(velocity.x) > 2.0:
		if sprite.animation != "run":
			_play_if_exists("run")
	else:
		if sprite.animation != "idle":
			_play_if_exists("idle")


func _play_if_exists(anim_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func _on_death_effects() -> void:
	sprite.play("dead")
