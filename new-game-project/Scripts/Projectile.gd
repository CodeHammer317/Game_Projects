extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 1
@export var pierce_count: int = 0
@export var lifetime: float = 1.5
@export var knockback_force: float = 90.0
@export var team: int = 0

var instigator: Node = null

var _velocity: Vector2 = Vector2.ZERO
var _life_timer: float = 0.0
var _hit_set: Dictionary = {}
var _target: Node2D = null


func _ready() -> void:
	_life_timer = lifetime

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

	rotation = _velocity.angle()


func _physics_process(delta: float) -> void:
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	_process_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_process_hit(area)


func _process_hit(target: Node) -> void:
	if target == null:
		return

	if target == instigator:
		return

	var hurtbox := _find_hurtbox(target)
	if hurtbox == null:
		return

	var owner_node := hurtbox.get_parent()
	var id := owner_node.get_instance_id()

	if _hit_set.has(id):
		return
	_hit_set[id] = true

	var info := get_damage_info()
	hurtbox.take_damage(info)

	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()


func get_damage_info() -> DamageInfo:
	var safe_instigator: Node = null
	if is_instance_valid(instigator):
		safe_instigator = instigator

	var knockback := Vector2.ZERO
	if _velocity != Vector2.ZERO:
		knockback = _velocity.normalized() * knockback_force

	return DamageInfo.new(
		damage,
		knockback,
		safe_instigator,
		["projectile"],
		team
	)


func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node as Hurtbox

	for child in node.get_children():
		var hb := _find_hurtbox(child)
		if hb != null:
			return hb

	return null
