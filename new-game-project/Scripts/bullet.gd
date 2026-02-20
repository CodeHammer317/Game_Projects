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

# Replaces the forbidden "owner" property
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

	_y_lock = global_position.y
	_life_timer = lifetime

	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func set_instigator(node: Node) -> void:
	instigator = node

func set_direction_x(dir: int) -> void:
	direction_x = sign(dir)

func _physics_process(delta: float) -> void:
	# Lock vertical movement
	global_position.y = _y_lock

	# Lifetime
	_life_timer -= delta
	if _life_timer <= 0:
		queue_free()
		return

	# Raycast hit detection
	if _ray:
		_ray.target_position = Vector2(ray_length * direction_x, 0)
		_ray.force_raycast_update()

		if _ray.is_colliding():
			var collider := _ray.get_collider()
			var hit_pos := _ray.get_collision_point()
			_process_hit(collider, hit_pos)
			return

	# Movement
	var step := speed * direction_x * delta
	global_position.x += step
	_distance_traveled += abs(step)

	if _distance_traveled >= max_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_process_hit(area, global_position)

func _on_body_entered(body: Node) -> void:
	_process_hit(body, global_position)

func _process_hit(target: Node, hit_pos: Vector2) -> void:
	if target == null:
		return

	var id := target.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	# Filtering
	if not _should_damage(target):
		queue_free()
		return

	# Apply damage through the shared pipeline
	if target is Hurtbox:
		var info := DamageInfo.new(
			damage,
			Vector2(direction_x * 30, 0), # knockback
			instigator,
			["bullet"]
		)
		target.receive_damage(info)

	# Pierce logic
	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()

func _should_damage(target: Node) -> bool:
	var is_player := target.is_in_group("player")
	var is_enemy := target.is_in_group("enemies")
	var is_world := target.is_in_group("world")

	if is_player and not collide_with_players:
		return false
	if is_enemy and not collide_with_enemies:
		return false
	if is_world:
		return false

	return true
