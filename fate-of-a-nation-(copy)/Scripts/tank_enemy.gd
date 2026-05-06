extends CharacterBody2D
class_name TankEnemy

@export var move_speed: float = 40.0
@export var fire_cooldown: float = 2.0
@export var bullet_scene: PackedScene
@export var damage: int = 50

var _fire_timer: float = 0.0
var _target: Node2D = null
var _is_dead: bool = false

@onready var turret: Node2D = $Turret
@onready var muzzle: Node2D = $Turret/Muzzle
@onready var hurtbox: Area2D = $Turret/Hurtbox


func _ready() -> void:
	_fire_timer = fire_cooldown

	if hurtbox != null:
		hurtbox.set_meta("owner_enemy", self)


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		velocity = Vector2.ZERO
		return

	if _is_dead:
		return

	if _target == null:
		_find_target()

	_move_tank()
	_aim_turret()
	_update_fire(delta)


func _move_tank() -> void:
	velocity.x = 0.0
	velocity.y = move_speed
	move_and_slide()


func _aim_turret() -> void:
	if _target == null:
		return

	var dir: Vector2 = (_target.global_position - turret.global_position).normalized()
	turret.rotation = dir.angle()


func _update_fire(delta: float) -> void:
	if _target == null:
		return

	_fire_timer -= delta

	if _fire_timer <= 0.0:
		_fire()
		_fire_timer = fire_cooldown


func _find_target() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		_target = players[0] as Node2D


func _fire() -> void:
	if bullet_scene == null:
		return

	if muzzle == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	get_parent().add_child(bullet)

	bullet.global_position = muzzle.global_position

	var dir: Vector2 = Vector2.RIGHT.rotated(turret.global_rotation)

	if bullet.has_method("setup"):
		bullet.setup(dir, self)


func take_damage(amount: int = 1, attacker: Node = null) -> void:
	damage -= amount

	if damage <= 0:
		die()


func die() -> void:
	if _is_dead:
		return

	_is_dead = true
	queue_free()
