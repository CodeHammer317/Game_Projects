# Bullet.gd
extends Area2D

@export var speed: float = 560.0
@export var lifetime: float = 1.6
@export var max_distance: float = 900.0
@export var damage: int = 1
@export var ray_length: float = 16.0
@export var pierce_count: int = 0
@export var collide_with_players: bool = false
@export var collide_with_enemies: bool = true

var owner_id: int = 0
var direction_x: int = 1
var _y_lock: float = 0.0
var _life_timer: float = 0.0
var _distance_traveled: float = 0.0
var _ray: RayCast2D
var _screen_notifier: VisibleOnScreenNotifier2D
var _hit_set := {}

func _ready() -> void:
	_ray = get_node_or_null("RayCast2D")
	if _ray != null:
		_ray.enabled = true

	_screen_notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if _screen_notifier != null:
		_screen_notifier.connect("screen_exited", Callable(self, "_on_screen_exited"))

	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))

	_y_lock = global_position.y
	_life_timer = lifetime

func _physics_process(delta: float) -> void:
	# Lock Y (no vertical movement)
	global_position.y = _y_lock

	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	if _ray != null:
		var target_pos := Vector2(ray_length * float(direction_x), 0.0)
		_ray.target_position = target_pos
		_ray.force_raycast_update()

		if _ray.is_colliding():
			var obj := _ray.get_collider()
			var pos := _ray.get_collision_point()
			_handle_hit(obj, pos)
			return

	var step := speed * float(direction_x) * delta
	global_position.x += step
	_distance_traveled += abs(step)

	if _distance_traveled >= max_distance:
		queue_free()
		return

func set_owner_id(id: int) -> void:
	owner_id = id

func set_direction_x(dir: int) -> void:
	if dir < 0:
		direction_x = -1
	else:
		direction_x = 1

func _on_body_entered(body: Node) -> void:
	_handle_hit(body, global_position)

func _on_area_entered(area: Area2D) -> void:
	_handle_hit(area, global_position)

func _on_screen_exited() -> void:
	queue_free()

func _handle_hit(target: Node, _point: Vector2) -> void:
	if target == null:
		return

	var id := target.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	if not _should_damage(target):
		queue_free()
		return

	_apply_damage_if_supported(target)
	_apply_knockback_if_supported(target)

	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()

func _apply_damage_if_supported(target: Node) -> void:
	if target.has_method("apply_damage"):

		target.call("apply_damage", damage, owner_id)
	elif target.has_method("hit"):
		target.call("hit", damage, owner_id)

func _apply_knockback_if_supported(target: Node) -> void:
	if target is CharacterBody2D:
		var push := Vector2(float(direction_x) * 30.0, 0.0)
		target.velocity += push

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
