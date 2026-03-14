extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 1
@export var pierce_count: int = 0
@export var lifetime: float = 1.5
@export var instigator: Node = null
@export var knockback_force: float = 90.0

var _velocity: Vector2 = Vector2.ZERO
var _life_timer: float = 0.0
var _hit_set := {}
var _target: Node2D = null

func _ready() -> void:
	_life_timer = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func launch(direction: Vector2, target: Node2D = null) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	_velocity = direction.normalized() * speed
	_target = target

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

	var id := target.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	var hurtbox := _find_hurtbox(target)
	if hurtbox == null:
		return

	var safe_instigator: Node = null
	if is_instance_valid(instigator):
		safe_instigator = instigator

	var hit_tags: Array[String] = ["projectile"]

	var info := DamageInfo.new(
		damage,
		_velocity.normalized() * knockback_force,
		safe_instigator,
		hit_tags
	)

	hurtbox.take_damage(info)

	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()

func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node as Hurtbox

	for child in node.get_children():
		var hb := _find_hurtbox(child)
		if hb != null:
			return hb

	return null
