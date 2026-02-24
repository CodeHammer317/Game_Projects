# Bullet.gd
extends Area2D
class_name Bullet

@export var speed: float = 560.0
@export var lifetime: float = 1.6
@export var max_distance: float = 900.0
@export var damage: int = 1
@export var ray_length: float = 100.0
@export var pierce_count: int = 0

@export var collide_with_players: bool = false
@export var collide_with_enemies: bool = true

@export var instigator: Node = null

var direction_x: int = 1
var _y_lock: float
var _life_timer: float
var _distance_traveled: float = 0.0
var _ray: RayCast2D
var _hit_set := {}

func _ready() -> void:
	_ray = get_node_or_null("RayCast2D")
	if _ray:
		_ray.enabled = true
		_ray.collide_with_areas = true
		_ray.collide_with_bodies = true
		# Make sure collision mask matches enemies
		_ray.collision_mask = 0b10 # adjust based on your enemy layer

	_y_lock = global_position.y
	_life_timer = lifetime

	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func set_instigator(node: Node) -> void:
	instigator = node

func set_direction_x(dir: int) -> void:
	direction_x = sign(dir)

func _physics_process(delta: float) -> void:
	global_position.y = _y_lock

	# Lifetime
	_life_timer -= delta
	if _life_timer <= 0:
		queue_free()
		return

	# Raycast detection for fast bullets
	if _ray:
		_ray.target_position = Vector2(ray_length * direction_x, 0)
		_ray.force_raycast_update()
		if _ray.is_colliding():
			var collider = _ray.get_collider()
			var hit_pos = _ray.get_collision_point()
			_process_hit(collider, hit_pos)
			return

	# Movement
	var step_vector = Vector2(speed * direction_x * delta, 0)
	global_position += step_vector
	_distance_traveled += step_vector.length()

	if _distance_traveled >= max_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_process_hit(area, global_position)

func _on_body_entered(body: Node) -> void:
	_process_hit(body, global_position)

func _process_hit(target: Node, hit_pos: Vector2) -> void:
	if target == null:
		return

	# Avoid hitting the same target multiple times
	var id = target.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	if not _should_damage(target):
		queue_free()
		return

	# Find Hurtbox recursively
	var hurtbox = _find_hurtbox(target)
	if hurtbox:
		var info = DamageInfo.new(
			damage,
			Vector2(direction_x * 20, 0), # knockback
			instigator,
			["bullet"]
		)
		hurtbox.take_damage(info)

	# Piercing logic
	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()

func _should_damage(target: Node) -> bool:
	var is_player = _is_in_group_recursive(target, "player")
	var is_enemy = _is_in_group_recursive(target, "enemies")
	var is_world = _is_in_group_recursive(target, "world")

	if is_player and not collide_with_players:
		return false
	if is_enemy and not collide_with_enemies:
		return false
	if is_world:
		return false

	return true

# Recursive check for groups (handles parent/child relationships)
func _is_in_group_recursive(node: Node, group_name: String) -> bool:
	var current = node
	while current:
		if current.is_in_group(group_name):
			return true
		current = current.get_parent()
	return false

# Recursive search for a Hurtbox in target or children
func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node
	for child in node.get_children():
		var hb = _find_hurtbox(child)
		if hb:
			return hb
	return null
