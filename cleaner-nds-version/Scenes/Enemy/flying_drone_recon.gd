extends CharacterBody2D
class_name FlyingReconDrone

signal spawned_attack_drones(drones: Array[Node])

@export var player_group: StringName = &"player"
@export var detection_range: float = 300.0
@export var scan_delay: float = 1.5
@export var summon_interval: float = 30.0
@export var attack_drone_scene: PackedScene
@export var spawned_drone_target_group: StringName = &"enemies"
@export var scan_ray_scene: PackedScene
@export var flip_scan_animation_horizontally: bool = true
@export var scan_flip_delay: float = 0.25

@export var patrol_speed: float = 70.0
@export var patrol_width: float = 360.0
@export var hover_amplitude: float = 14.0
@export var hover_frequency: float = 2.0
@export var vertical_follow_speed: float = 90.0
@export_range(0.0, 1.0, 0.01) var upper_third_bias: float = 0.45

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: Health = $Health
@onready var muzzle: Node2D = $Muzzle

var _home_position: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _scan_ray_instance: Node2D = null
var _scan_ray_animation: AnimatedSprite2D = null
var _is_scanning: bool = false
var _is_dead: bool = false
var _scan_sequence_id: int = 0
var _patrol_direction: float = 1.0
var _hover_time: float = 0.0
var _summon_timer: float = 0.0


func _ready() -> void:
	_home_position = global_position

	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_summon_timer = 0.0
	_play_animation(&"walk_scan")


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		return

	_hover_time += delta
	_update_patrol_motion(delta)
	move_and_slide()

	_find_target()
	if _target != null and is_instance_valid(_target):
		_face_target()
		_update_summon_timer(delta)
	elif not _is_scanning:
		_face_patrol_direction()
		_play_animation(&"walk_scan")
		_hide_scan_ray()


func _update_patrol_motion(delta: float) -> void:
	var left_limit := _home_position.x - patrol_width * 0.5
	var right_limit := _home_position.x + patrol_width * 0.5

	if global_position.x <= left_limit:
		_turn_patrol_right()
	elif global_position.x >= right_limit:
		_patrol_direction = -1.0

	var desired_y := _get_upper_third_target_y()
	var hover_offset := sin(_hover_time * TAU * hover_frequency) * hover_amplitude
	var y_delta := (desired_y + hover_offset) - global_position.y

	velocity.x = _patrol_direction * patrol_speed
	velocity.y = clampf(y_delta * 4.0, -vertical_follow_speed, vertical_follow_speed)

	if _is_scanning:
		velocity *= 0.45


func _turn_patrol_right() -> void:
	_patrol_direction = 1.0


func _get_upper_third_target_y() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return _home_position.y

	var viewport_size := get_viewport_rect().size / camera.zoom
	var screen_top := camera.global_position.y - viewport_size.y * 0.5
	var upper_third_height := viewport_size.y / 3.0
	return screen_top + upper_third_height * upper_third_bias


func _update_summon_timer(delta: float) -> void:
	if _is_scanning:
		return

	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_start_scan()


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


func _face_target() -> void:
	if sprite == null or _target == null:
		return

	sprite.flip_h = _target.global_position.x < global_position.x


func _face_patrol_direction() -> void:
	if sprite != null:
		sprite.flip_h = _patrol_direction < 0.0


func _start_scan() -> void:
	_is_scanning = true
	_play_animation(&"scan")
	_play_scan_ray()
	call_deferred("_finish_scan_after_delay")


func _finish_scan_after_delay() -> void:
	await get_tree().create_timer(scan_delay).timeout

	if _is_dead or not is_inside_tree():
		return

	if _target != null and is_instance_valid(_target):
		var spawned_drones := _spawn_attack_drone()
		spawned_attack_drones.emit(spawned_drones)

	_is_scanning = false
	_summon_timer = summon_interval
	_hide_scan_ray()
	_play_animation(&"walk_scan")


func _spawn_attack_drone() -> Array[Node]:
	var spawned_drones: Array[Node] = []
	if attack_drone_scene == null:
		push_warning("%s: attack_drone_scene is not assigned." % name)
		return spawned_drones

	var spawn_parent := get_parent()
	if spawn_parent == null:
		spawn_parent = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = self

	var drone := attack_drone_scene.instantiate()
	if drone == null:
		return spawned_drones

	spawn_parent.add_child(drone)

	if drone is Node2D:
		(drone as Node2D).global_position = _get_spawn_origin()

	if spawned_drone_target_group != &"" and not drone.is_in_group(spawned_drone_target_group):
		drone.add_to_group(spawned_drone_target_group)

	spawned_drones.append(drone)
	return spawned_drones


func _get_spawn_origin() -> Vector2:
	if muzzle != null:
		return muzzle.global_position

	return global_position


func _play_scan_ray() -> void:
	_clear_scan_ray_instance()

	if scan_ray_scene == null:
		push_warning("%s: scan_ray_scene is not assigned." % name)
		return

	_scan_sequence_id += 1
	var sequence_id := _scan_sequence_id

	var instance := scan_ray_scene.instantiate() as Node2D
	if instance == null:
		return

	var parent_node := muzzle if muzzle != null else self
	parent_node.add_child(instance)
	instance.position = Vector2.ZERO

	_scan_ray_instance = instance
	_scan_ray_animation = instance.get_node_or_null("ScanRayAnimation") as AnimatedSprite2D

	if _scan_ray_animation != null:
		_scan_ray_animation.flip_h = false
		_scan_ray_animation.play(&"Scan")

	if flip_scan_animation_horizontally:
		call_deferred("_flip_scan_ray_after_delay", sequence_id)


func _flip_scan_ray_after_delay(sequence_id: int) -> void:
	await get_tree().create_timer(scan_flip_delay).timeout

	if _is_dead or not _is_scanning or sequence_id != _scan_sequence_id:
		return

	if _scan_ray_animation != null and is_instance_valid(_scan_ray_animation):
		_scan_ray_animation.flip_h = true


func _hide_scan_ray() -> void:
	_scan_sequence_id += 1
	_clear_scan_ray_instance()


func _clear_scan_ray_instance() -> void:
	if _scan_ray_instance != null and is_instance_valid(_scan_ray_instance):
		_scan_ray_instance.queue_free()

	_scan_ray_instance = null
	_scan_ray_animation = null


func _play_animation(animation_name: StringName) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name:
			sprite.play(animation_name)


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_scanning = false
	velocity = Vector2.ZERO
	_hide_scan_ray()

	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"death"):
		sprite.play(&"death")
	else:
		queue_free()


func _on_sprite_animation_finished() -> void:
	if _is_dead and sprite != null and sprite.animation == &"death":
		queue_free()
