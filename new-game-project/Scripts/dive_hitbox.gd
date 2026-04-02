extends Area2D
class_name DiveHitbox

@export var damage: int = 2
@export var lifetime: float = 0.16
@export var knockback_x: float = 120.0
@export var knockback_y: float = 180.0
@export var team: int = 1
@export var destroy_on_hit: bool = false
@export var one_hit_per_target: bool = true

var instigator: Node = null
var owner_id: int = -1
var facing: Vector2 = Vector2.DOWN
var _hit_set: Dictionary = {}

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	if timer:
		timer.one_shot = true
		timer.wait_time = lifetime
		if not timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.connect(_on_timer_timeout)
		timer.start()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite:
		sprite.play()


func setup(owner_node: Node, dir: Vector2 = Vector2.DOWN, owner_team: int = 1) -> void:
	instigator = owner_node
	team = owner_team

	if owner_node != null and "player_id" in owner_node:
		owner_id = owner_node.player_id

	if dir == Vector2.ZERO:
		facing = Vector2.DOWN
	else:
		facing = dir.normalized()


func set_owner_id(id: int) -> void:
	owner_id = id


func _on_body_entered(body: Node) -> void:
	_process_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_process_hit(area)


func _process_hit(target: Node) -> void:
	if target == null:
		return

	if target == instigator:
		return

	if one_hit_per_target and _hit_set.has(target):
		return

	if not _is_valid_target(target):
		return

	_hit_set[target] = true

	var kb := _build_knockback()
	var info := DamageInfo.new(damage, kb, instigator, ["dive", "melee"])

	if target.has_method("apply_damage"):
		target.apply_damage(info)
	else:
		var health := target.get_node_or_null("Health")
		if health and health.has_method("apply_damage"):
			health.apply_damage(info)

	if destroy_on_hit:
		queue_free()


func _is_valid_target(target: Node) -> bool:
	if target == null:
		return false

	if target == instigator:
		return false

	if "player_id" in target and owner_id != -1 and target.player_id == owner_id:
		return false

	if "team" in target and target.team == team:
		return false

	var health := target.get_node_or_null("Health")
	if health == null and not target.has_method("apply_damage"):
		return false

	return true


func _build_knockback() -> Vector2:
	var x_dir := 0.0

	if facing.x > 0.05:
		x_dir = 1.0
	elif facing.x < -0.05:
		x_dir = -1.0

	return Vector2(knockback_x * x_dir, knockback_y)


func _on_timer_timeout() -> void:
	queue_free()
