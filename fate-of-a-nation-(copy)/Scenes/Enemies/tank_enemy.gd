extends CharacterBody2D
class_name TankEnemy

@export var move_speed: float = 40.0
@export var fire_cooldown: float = 2.0
@export var bullet_scene: PackedScene

var _fire_timer: float = 0.0
var _target: Node2D = null

@onready var turret: Node2D = $Turret
@onready var muzzle: Node2D = $Turret/Muzzle


func _physics_process(delta: float) -> void:
	if _target == null:
		_find_target()

	# Move forward
	velocity.y = move_speed
	move_and_slide()

	# Aim turret
	if _target != null:
		var dir: Vector2 = (_target.global_position - turret.global_position).normalized()
		turret.rotation = dir.angle()

	# Fire logic
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire()
		_fire_timer = fire_cooldown


func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]


func _fire() -> void:
	if bullet_scene == null:
		return

	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	bullet.global_position = muzzle.global_position

	var dir: Vector2 = Vector2.RIGHT.rotated(turret.global_rotation)

	if bullet.has_method("setup"):
		bullet.setup(self, dir)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
