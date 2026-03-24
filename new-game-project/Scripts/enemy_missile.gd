extends Area2D
class_name EnemyMissile

@export var speed: float = 360.0
@export var turn_rate_deg: float = 45.0
@export var damage: int = 1
@export var lifetime: float = 1.0
@export var knockback_scale: float = 0.2
@export var team: int = 2

var instigator: Node = null
var _velocity: Vector2 = Vector2.ZERO
var _time_left: float = 0.0
var _hit_set: Dictionary = {}
var _target: Node2D = null


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func launch(direction: Vector2, target: Node2D = null, owner_node: Node = null) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	_velocity = direction.normalized() * speed
	_target = target
	instigator = owner_node


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return

	if is_instance_valid(_target):
		var desired_dir := (_target.global_position - global_position).normalized()
		var current_dir := _velocity.normalized()
		var max_turn := deg_to_rad(turn_rate_deg) * delta
		var angle_diff = clamp(current_dir.angle_to(desired_dir), -max_turn, max_turn)
		_velocity = current_dir.rotated(angle_diff) * speed

	rotation = _velocity.angle()
	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	_process_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_process_hit(area)


func _process_hit(target_node: Node) -> void:
	if target_node == null:
		return

	if target_node == instigator:
		return

	var hurtbox := _find_hurtbox(target_node)
	if hurtbox == null:
		if target_node is PhysicsBody2D or target_node is TileMap:
			queue_free()
		return

	var owner_node: Node = hurtbox.get_parent()
	if owner_node == null:
		owner_node = hurtbox

	var id := owner_node.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	var knockback := Vector2.ZERO
	if _velocity != Vector2.ZERO:
		knockback = _velocity.normalized() * (100.0 * knockback_scale)

	var info := DamageInfo.new(
		damage,
		knockback,
		instigator if is_instance_valid(instigator) else null,
		["missile"],
		team
	)

	hurtbox.take_damage(info)
	queue_free()


func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node as Hurtbox

	for child in node.get_children():
		var hb := _find_hurtbox(child)
		if hb != null:
			return hb

	return null
