extends Area2D
class_name Projectile

@export var speed: float = 450.0
@export var damage: int = 1
@export var pierce_count: int = 0
@export var lifetime: float = 1.5
@export var instigator: Node = null

var _velocity: Vector2
var _life_timer: float
var _hit_set := {}
var _target: Node2D = null  # optional, for homing projectiles

func _ready() -> void:
	_life_timer = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

# Unified launch: all projectiles take dir + optional target
func launch(direction: Vector2, target: Node2D = null) -> void:
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

	var id = target.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	var hurtbox = _find_hurtbox(target)
	if hurtbox == null:
		return

	var info = DamageInfo.new(
		damage,
		_velocity * 0.2,
		instigator,
		["projectile"]
	)

	hurtbox.take_damage(info)

	if pierce_count > 0:
		pierce_count -= 1
	else:
		queue_free()

func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node
	for child in node.get_children():
		var hb = _find_hurtbox(child)
		if hb:
			return hb
	return null
