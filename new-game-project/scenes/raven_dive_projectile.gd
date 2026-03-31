extends Area2D
class_name RavenDiveProjectile

@export var rise_speed: float = 180.0
@export var dive_speed: float = 320.0
@export var transform_time: float = 0.28
@export var lifetime: float = 1.2
@export var damage: int = 2
@export var aoe_damage: int = 1
@export var knockback_force: float = 180.0
@export var aoe_scene: PackedScene

var instigator: Node = null
var team: int = 1
var dive_direction: Vector2 = Vector2(1, 1).normalized()

var _state: String = "rise"
var _transform_timer: float = 0.0
var _life_timer: float = 0.0
var _hit_set: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_transform_timer = transform_time
	_life_timer = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite != null:
		sprite.play("stone")


func launch(dir: Vector2, owner_node: Node, owner_team: int = 1) -> void:
	dive_direction = dir.normalized()
	instigator = owner_node
	team = owner_team

	if sprite != null:
		sprite.flip_h = dive_direction.x < 0.0


func _physics_process(delta: float) -> void:
	_life_timer -= delta
	if _life_timer <= 0.0:
		_explode()
		return

	match _state:
		"rise":
			global_position += Vector2(0, -rise_speed) * delta
			_transform_timer -= delta
			if _transform_timer <= 0.0:
				_become_raven()

		"dive":
			global_position += dive_direction * dive_speed * delta
			rotation = dive_direction.angle()

		_:
			pass


func _become_raven() -> void:
	_state = "dive"
	if sprite != null:
		sprite.play("raven")


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _try_hit(target: Node) -> void:
	if target == null:
		return
	if target == instigator:
		return
	if _already_hit(target):
		return

	if target.has_method("apply_damage"):
		var knockback := dive_direction * knockback_force
		var info := DamageInfo.new(damage, knockback, instigator, ["raven", "projectile", "dive"])
		target.apply_damage(info)
		_mark_hit(target)
		_explode()
		return

	if target.has_method("get_parent"):
		var p := target.get_parent()
		if p != null and p != instigator and p.has_method("apply_damage"):
			var knockback := dive_direction * knockback_force
			var info := DamageInfo.new(damage, knockback, instigator, ["raven", "projectile", "dive"])
			p.apply_damage(info)
			_mark_hit(p)
			_explode()


func _explode() -> void:
	if aoe_scene != null:
		var aoe := aoe_scene.instantiate()
		if get_parent() != null:
			get_parent().add_child(aoe)

			if aoe is Node2D:
				aoe.global_position = global_position

			if aoe.has_method("setup"):
				aoe.setup(instigator, team, aoe_damage, knockback_force * 0.6)

	queue_free()


func _already_hit(target: Node) -> bool:
	return _hit_set.has(target.get_instance_id())


func _mark_hit(target: Node) -> void:
	_hit_set[target.get_instance_id()] = true
