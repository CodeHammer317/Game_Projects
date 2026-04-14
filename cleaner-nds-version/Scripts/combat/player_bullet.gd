extends Area2D
class_name PlayerBullet

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var knockback: Vector2 = Vector2(90.0, -30.0)

var _direction: Vector2 = Vector2.RIGHT
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

@onready var sprite: Node2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if notifier and not notifier.screen_exited.is_connected(_on_screen_exited):
		notifier.screen_exited.connect(_on_screen_exited)


func setup(direction: Vector2, owner: Node) -> void:
	if direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()

	_owner = owner

	if sprite:
		if _direction.x < 0.0:
			sprite.scale.x = -absf(sprite.scale.x)
		elif _direction.x > 0.0:
			sprite.scale.x = absf(sprite.scale.x)


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return

	if area == _owner:
		return

	if area.has_method("apply_hit"):
		_apply_hit_area(area)
		return

	var parent := area.get_parent()
	if parent != null and parent != _owner and parent.has_method("apply_damage"):
		_apply_hit_to(parent)


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


func _on_screen_exited() -> void:
	queue_free()
