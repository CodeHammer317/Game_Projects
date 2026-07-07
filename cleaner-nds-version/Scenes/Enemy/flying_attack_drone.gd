extends CharacterBody2D
class_name FlyingAttackDrone

@export var player_group: StringName = &"player"
@export var detection_range: float = 360.0
@export var preferred_attack_range: float = 210.0
@export var move_speed: float = 80.0
@export var fire_cooldown: float = 1.4
@export var projectile_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var muzzle: Node2D = $Muzzle

var _target: Node2D = null
var _fire_timer: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_play_animation(&"flying")


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	if _fire_timer > 0.0:
		_fire_timer = maxf(_fire_timer - delta, 0.0)

	_find_target()

	if _target == null or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_face_target()
	_move_into_attack_range()

	if _fire_timer <= 0.0 and global_position.distance_to(_target.global_position) <= detection_range:
		_fire_missle()
		_fire_timer = fire_cooldown

	move_and_slide()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group(player_group)
	var closest_player: Node2D = null
	var closest_distance := INF

	for player in players:
		var candidate := player as Node2D
		if candidate == null or not is_instance_valid(candidate):
			continue

		var distance := global_position.distance_to(candidate.global_position)
		if distance <= detection_range and distance < closest_distance:
			closest_player = candidate
			closest_distance = distance

	_target = closest_player


func _move_into_attack_range() -> void:
	var distance := global_position.distance_to(_target.global_position)
	if distance <= preferred_attack_range:
		velocity = Vector2.ZERO
		return

	velocity = global_position.direction_to(_target.global_position) * move_speed


func _fire_missle() -> void:
	if projectile_scene == null:
		push_warning("%s: projectile_scene is not assigned." % name)
		return

	var projectile := projectile_scene.instantiate()
	if projectile == null:
		return

	var spawn_parent := get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_parent()
	if spawn_parent == null:
		spawn_parent = self

	spawn_parent.add_child(projectile)

	if projectile is Node2D:
		(projectile as Node2D).global_position = _get_muzzle_position()

	var direction := _get_muzzle_position().direction_to(_target.global_position)
	if projectile.has_method("launch"):
		projectile.launch(direction, _target, self)
	elif projectile.has_method("setup"):
		projectile.setup(direction, self)


func _get_muzzle_position() -> Vector2:
	if muzzle != null:
		return muzzle.global_position

	return global_position


func _face_target() -> void:
	if sprite == null or _target == null:
		return

	sprite.flip_h = _target.global_position.x < global_position.x


func _play_animation(animation_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	_play_animation(&"drop")


func _on_sprite_animation_finished() -> void:
	if _is_dead and sprite != null and sprite.animation == &"drop":
		queue_free()
