extends Area2D
class_name HeavyPunchHitbox

@export var damage: int = 2
@export var lifetime: float = 0.12
@export var knockback_force: float = 140.0
@export var team: int = 1

var instigator: Node = null
var facing: Vector2 = Vector2.RIGHT

@onready var timer: Timer = $Timer
@onready var punch_hit: AnimatedSprite2D = $YellowHit/AnimatedSprite2D
var _hit_set: Dictionary = {}


func _ready() -> void:
	timer.one_shot = true
	timer.wait_time = lifetime
	timer.start()

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


func setup(owner_node: Node, dir: Vector2, owner_team: int = 1) -> void:
	instigator = owner_node
	facing = dir.normalized()
	team = owner_team


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
		return

	var owner_node: Node = hurtbox.get_parent()
	if owner_node == null:
		owner_node = hurtbox

	var id := owner_node.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	var info := DamageInfo.new(
		damage,
		facing * knockback_force,
		instigator if is_instance_valid(instigator) else null,
		["melee", "punch"],
		team
	)
	punch_hit.play("default")
	hurtbox.take_damage(info)


func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node as Hurtbox

	for child in node.get_children():
		var hb := _find_hurtbox(child)
		if hb != null:
			return hb

	return null


func _on_timer_timeout() -> void:
	queue_free()
