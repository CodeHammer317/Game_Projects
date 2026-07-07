extends Area2D
class_name EnemyMissle

@export var speed: float = 180.0
@export var turn_speed: float = 5.0
@export var damage: int = 1
@export var lifetime: float = 4.0
@export var knockback: Vector2 = Vector2(100.0, -20.0)
@export var target_group: StringName = &"player"

var _direction: Vector2 = Vector2.LEFT
var _owner: Node = null
var _target: Node2D = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite != null:
		sprite.play(&"default")

	_find_target()
	_update_rotation()


func setup(direction: Vector2, source_node: Node) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.LEFT
	_owner = source_node
	_find_target()
	_update_rotation()


func launch(direction: Vector2, target: Node2D = null, source_node: Node = null) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.LEFT
	_target = target
	_owner = source_node
	if _target == null or not is_instance_valid(_target):
		_find_target()
	_update_rotation()


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return

	_update_homing(delta)
	global_position += _direction * speed * delta
	_update_rotation()


func _update_homing(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_find_target()

	if _target == null or not is_instance_valid(_target):
		return

	var desired_direction := global_position.direction_to(_target.global_position)
	if desired_direction == Vector2.ZERO:
		return

	var turn_amount := clampf(turn_speed * delta, 0.0, 1.0)
	_direction = _direction.slerp(desired_direction, turn_amount).normalized()


func _find_target() -> void:
	var candidates := get_tree().get_nodes_in_group(target_group)
	var closest_target: Node2D = null
	var closest_distance := INF

	for candidate_node in candidates:
		var candidate := candidate_node as Node2D
		if candidate == null or not is_instance_valid(candidate):
			continue

		var distance := global_position.distance_to(candidate.global_position)
		if distance < closest_distance:
			closest_target = candidate
			closest_distance = distance

	_target = closest_target


func _update_rotation() -> void:
	if _direction != Vector2.ZERO:
		rotation = _direction.angle()


func _on_body_entered(body: Node) -> void:
	if body == null or body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)
	else:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area == null or area == _owner:
		return

	if area.has_method("apply_hit"):
		_apply_hit_area(area)
		return

	var parent := area.get_parent()
	if parent != null and parent != _owner and parent.has_method("apply_damage"):
		_apply_hit_to(parent)
	else:
		queue_free()


func _apply_hit_area(area: Area2D) -> void:
	if _already_hit(area):
		return

	var info := DamageInfo.new(
		damage,
		Vector2(_direction.x * knockback.x, knockback.y),
		_owner
	)

	area.apply_hit(info)
	_mark_hit(area)
	queue_free()


func _apply_hit_to(target: Node) -> void:
	if _already_hit(target):
		return

	var info := DamageInfo.new(
		damage,
		Vector2(_direction.x * knockback.x, knockback.y),
		_owner
	)

	target.apply_damage(info)
	_mark_hit(target)
	queue_free()


func _already_hit(target: Object) -> bool:
	return _hit_targets.has(target)


func _mark_hit(target: Object) -> void:
	_hit_targets[target] = true
