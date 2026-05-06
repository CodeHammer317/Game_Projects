extends Area2D
class_name TankBullet

@export var speed: float = 240.0
@export var damage: int = 1
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.DOWN
var owner_node: Node = null
var time_left: float = 0.0
var hit_targets: Dictionary = {}


func _ready() -> void:
	time_left = lifetime

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(new_direction: Vector2, new_owner: Node = null) -> void:
	if new_direction == Vector2.ZERO:
		direction = Vector2.DOWN
	else:
		direction = new_direction.normalized()

	owner_node = new_owner
	rotation = direction.angle() + deg_to_rad(90)


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		queue_free()
		return

	global_position += direction * speed * delta

	time_left -= delta
	if time_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_try_hit_target(area)


func _on_body_entered(body: Node) -> void:
	_try_hit_target(body)


func _try_hit_target(target: Node) -> void:
	if target == null:
		return

	if target == owner_node:
		return

	if hit_targets.has(target):
		return

	hit_targets[target] = true

	if target.has_meta("owner_player"):
		var player: Node = target.get_meta("owner_player")

		if player != null and player.has_method("take_damage"):
			player.take_damage(damage, owner_node)
			queue_free()
			return

	if target.has_method("take_damage"):
		target.take_damage(damage)
		queue_free()
		return

	var parent: Node = target.get_parent()

	if parent != null and parent.has_method("take_damage"):
		parent.take_damage(damage)
		queue_free()
