extends Area2D
class_name CatProjectile

@export var speed: float = 260.0
@export var fall_gravity: float = 90.0
@export var max_fall_speed: float = 420.0

@export var damage: int = 1
@export var lifetime: float = 2.5
@export var knockback: Vector2 = Vector2(100.0, -25.0)

var _direction: Vector2 = Vector2.LEFT
var _velocity: Vector2 = Vector2.ZERO
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var meow_sound: AudioStreamPlayer = get_node_or_null("CatMeowSound")


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if notifier != null:
		if not notifier.screen_exited.is_connected(_on_screen_exited):
			notifier.screen_exited.connect(_on_screen_exited)

	if meow_sound != null:
		meow_sound.play()

	_build_velocity()
	_update_visual_facing()


func setup(direction: Vector2, owner: Node) -> void:
	if direction == Vector2.ZERO:
		_direction = Vector2.LEFT
	else:
		_direction = direction.normalized()

	_owner = owner
	_build_velocity()
	_update_visual_facing()


func _physics_process(delta: float) -> void:
	_velocity.y += fall_gravity * delta

	if _velocity.y > max_fall_speed:
		_velocity.y = max_fall_speed

	global_position += _velocity * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _build_velocity() -> void:
	_velocity = _direction.normalized() * speed


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)
		return

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

	if parent != null:
		if parent != _owner:
			if parent.has_method("apply_damage"):
				_apply_hit_to(parent)
				return

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


func _update_visual_facing() -> void:
	if sprite == null:
		return

	if _direction.x < 0.0:
		sprite.flip_h = false
	elif _direction.x > 0.0:
		sprite.flip_h = true


func _on_screen_exited() -> void:
	queue_free()






















'''extends Area2D
class_name CatProjectile

@export var speed: float = 260.0
@export var damage: int = 1
@export var lifetime: float = 2.5
@export var knockback: Vector2 = Vector2(100.0, -25.0)

var _direction: Vector2 = Vector2.LEFT
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var meow_sound: AudioStreamPlayer = $CatMeowSound


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if notifier != null:
		if not notifier.screen_exited.is_connected(_on_screen_exited):
			notifier.screen_exited.connect(_on_screen_exited)

	if meow_sound != null:
		meow_sound.play()

	_update_visual_facing()


func setup(direction: Vector2, owner: Node) -> void:
	if direction == Vector2.ZERO:
		_direction = Vector2.LEFT
	else:
		_direction = direction.normalized()

	_owner = owner
	_update_visual_facing()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)
		return

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

	if parent != null:
		if parent != _owner:
			if parent.has_method("apply_damage"):
				_apply_hit_to(parent)
				return

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


func _update_visual_facing() -> void:
	if sprite == null:
		return

	if _direction.x < 0.0:
		sprite.flip_h = false
	elif _direction.x > 0.0:
		sprite.flip_h = true


func _on_screen_exited() -> void:
	queue_free()'''













'''extends Area2D
class_name CatProjectile

@export var speed: float = 260.0
@export var damage: int = 1
@export var lifetime: float = 2.5
@export var knockback: Vector2 = Vector2(100.0, -25.0)
@export var spin_speed: float = 10.0
@export var use_spin: bool = true

var _direction: Vector2 = Vector2.LEFT
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

@onready var meow_sound: AudioStreamPlayer = $CatMeowSound


func _ready() -> void:
	_time_left = lifetime

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if notifier != null:
		if not notifier.screen_exited.is_connected(_on_screen_exited):
			notifier.screen_exited.connect(_on_screen_exited)

	if meow_sound != null:
		meow_sound.play()

	_update_visual_facing()


func setup(direction: Vector2, owner: Node) -> void:
	if direction == Vector2.ZERO:
		_direction = Vector2.LEFT
	else:
		_direction = direction.normalized()

	_owner = owner
	_update_visual_facing()


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

	if use_spin == true and sprite != null:
		sprite.rotation += spin_speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)
		return

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

	if parent != null:
		if parent != _owner:
			if parent.has_method("apply_damage"):
				_apply_hit_to(parent)
				return

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


func _update_visual_facing() -> void:
	if sprite == null:
		return

	if _direction.x < 0.0:
		sprite.flip_h = false

	if _direction.x > 0.0:
		sprite.flip_h = true


func _on_screen_exited() -> void:
	queue_free()'''
