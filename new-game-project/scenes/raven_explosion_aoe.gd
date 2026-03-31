extends Area2D
class_name RavenExplosionAOE

@export var damage: int = 1
@export var lifetime: float = 0.12
@export var knockback_force: float = 100.0

var instigator: Node = null
var team: int = 1
var _hit_set: Dictionary = {}

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


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

	if sprite != null:
		sprite.play("explode")


func setup(owner_node: Node, owner_team: int, new_damage: int, new_knockback_force: float) -> void:
	instigator = owner_node
	team = owner_team
	damage = new_damage
	knockback_force = new_knockback_force


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	if target == null:
		return
	if target == instigator:
		return
	if _hit_set.has(target.get_instance_id()):
		return

	if target.has_method("apply_damage"):
		var dir := Vector2.RIGHT
		if instigator is Node2D and target is Node2D:
			dir = (target.global_position - instigator.global_position).normalized()
		var info := DamageInfo.new(damage, dir * knockback_force, instigator, ["raven", "aoe"])
		target.apply_damage(info)
		_hit_set[target.get_instance_id()] = true
		return

	var parent := target.get_parent()
	if parent != null and parent != instigator and parent.has_method("apply_damage"):
		var dir := Vector2.RIGHT
		if instigator is Node2D and parent is Node2D:
			dir = (parent.global_position - global_position).normalized()
		var info := DamageInfo.new(damage, dir * knockback_force, instigator, ["raven", "aoe"])
		parent.apply_damage(info)
		_hit_set[parent.get_instance_id()] = true


func _on_timer_timeout() -> void:
	queue_free()
