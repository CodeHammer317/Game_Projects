extends Area2D
class_name PlayerBullet

@export var damage: int = 1
@export var lifetime: float = 3.5
@export var knockback: Vector2 = Vector2(90.0, -30.0)

@export_group("Arc Throw")
@export var projectile_gravity: float = 900.0
@export_range(1.0, 89.0, 1.0) var launch_angle_degrees: float = 45.0
@export var tile_size: float = 16.0
@export var minimum_range_tiles: float = 1.0
@export var maximum_range_tiles: float = 10.0
@export var target_group: StringName = &"enemies"
@export var rotate_with_velocity: bool = true

@export_group("Animation")
@export var fly_anim_name: StringName = &"fly"
@export var hit_anim_name: StringName = &"hit"

var _direction: Vector2 = Vector2.RIGHT
var _velocity: Vector2 = Vector2.ZERO
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}
var _has_hit: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var damage_radius: Area2D = $DamageRadius
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var fire_sound: AudioStreamPlayer = $BulletFireSound
@onready var hit_sound: AudioStreamPlayer = $BulletHitSound


func _ready() -> void:
	_time_left = lifetime

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)

	if sprite:
		sprite.animation_finished.connect(_on_sprite_animation_finished)
		_play_fly_animation()

	if fire_sound and fire_sound.stream:
		fire_sound.play()


func setup(direction: Vector2, source_node: Node, charge_ratio: float = 0.0) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_owner = source_node
	if _owner != null and not _owner.tree_exiting.is_connected(_on_owner_tree_exiting):
		_owner.tree_exiting.connect(_on_owner_tree_exiting, CONNECT_ONE_SHOT)

	var facing_sign := signf(_direction.x)
	if is_zero_approx(facing_sign):
		facing_sign = 1.0

	var clamped_charge := clampf(charge_ratio, 0.0, 1.0)
	var range_tiles := lerpf(minimum_range_tiles, maximum_range_tiles, clamped_charge)
	var maximum_range := range_tiles * tile_size
	var target := _find_target(facing_sign, maximum_range)

	if target:
		_velocity = _calculate_launch_velocity(
			target.global_position,
			facing_sign,
			maximum_range
		)
	else:
		_velocity = _calculate_fallback_velocity(facing_sign, maximum_range)

	if sprite:
		sprite.scale.x = absf(sprite.scale.x) * facing_sign


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	_velocity.y += projectile_gravity * delta
	global_position += _velocity * delta

	if not _velocity.is_zero_approx():
		_direction = _velocity.normalized()
		if rotate_with_velocity:
			rotation = _velocity.angle()

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _find_target(facing_sign: float, maximum_range: float) -> Node2D:
	var closest_target: Node2D = null
	var closest_distance := INF

	for candidate in get_tree().get_nodes_in_group(target_group):
		var target := candidate as Node2D
		if target == null or target == _owner or not is_instance_valid(target):
			continue

		var offset := target.global_position - global_position
		if signf(offset.x) != facing_sign:
			continue

		if absf(offset.x) > maximum_range:
			continue

		var distance := offset.length()
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target

	return closest_target


func _calculate_launch_velocity(
	target_position: Vector2,
	facing_sign: float,
	fallback_range: float
) -> Vector2:
	var horizontal_distance := absf(target_position.x - global_position.x)
	var vertical_offset := target_position.y - global_position.y
	var angle := deg_to_rad(launch_angle_degrees)
	var cosine := cos(angle)
	var denominator := 2.0 * cosine * cosine * (
		horizontal_distance * tan(angle) + vertical_offset
	)

	if horizontal_distance <= 0.0 or denominator <= 0.0:
		return _calculate_fallback_velocity(facing_sign, fallback_range)

	var launch_speed := sqrt(
		projectile_gravity * horizontal_distance * horizontal_distance / denominator
	)

	return Vector2(
		facing_sign * launch_speed * cosine,
		-launch_speed * sin(angle)
	)


func _calculate_fallback_velocity(facing_sign: float, throw_range: float) -> Vector2:
	var angle := deg_to_rad(launch_angle_degrees)
	var range_factor := sin(2.0 * angle)

	if range_factor <= 0.0:
		range_factor = 1.0

	var launch_speed := sqrt(throw_range * projectile_gravity / range_factor)
	return Vector2(
		facing_sign * launch_speed * cos(angle),
		-launch_speed * sin(angle)
	)


func _on_body_entered(body: Node) -> void:
	if _has_hit or body == _owner:
		return

	_detonate()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or area == null or area == _owner:
		return

	var parent := area.get_parent()
	if parent == _owner:
		return

	_detonate()


func _detonate() -> void:
	if _has_hit:
		return

	# The small parent collision shape decides when the projectile makes
	# contact. Damage is sourced exclusively from DamageRadius overlaps.
	_apply_radius_damage()
	_enter_hit_state()


func _apply_radius_damage() -> void:
	if damage_radius == null:
		push_warning("PlayerBullet: DamageRadius is unavailable.")
		return

	for area in damage_radius.get_overlapping_areas():
		_try_damage_radius_target(area)

	for body in damage_radius.get_overlapping_bodies():
		_try_damage_radius_target(body)


func _try_damage_radius_target(overlap: Node) -> void:
	var target := _resolve_damage_target(overlap)
	if target == null or target == _owner or _already_hit(target):
		return

	var info := DamageInfo.new(
		damage,
		Vector2(_direction.x * knockback.x, knockback.y),
		_get_valid_owner()
	)

	if target.has_method("apply_damage"):
		target.apply_damage(info)
	elif target.has_method("apply_hit"):
		target.apply_hit(info)

	_mark_hit(target)


func _resolve_damage_target(overlap: Node) -> Node:
	if overlap == null or overlap == _owner:
		return null

	var candidate := overlap
	while candidate != null and candidate != self:
		if candidate == _owner:
			return null
		if candidate.has_method("apply_damage"):
			return candidate
		candidate = candidate.get_parent()

	if overlap.has_method("apply_hit"):
		return overlap

	return null


func _enter_hit_state() -> void:
	if _has_hit:
		return

	_has_hit = true

	if fire_sound and fire_sound.playing:
		fire_sound.stop()

	if hit_sound and hit_sound.stream:
		hit_sound.play()

	if collision:
		collision.set_deferred("disabled", true)

	if damage_radius:
		damage_radius.set_deferred("monitoring", false)
		damage_radius.set_deferred("monitorable", false)

	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(hit_anim_name):
			sprite.play(hit_anim_name)
			return

	queue_free()


func _on_sprite_animation_finished() -> void:
	if _has_hit and sprite.animation == hit_anim_name:
		queue_free()


func _play_fly_animation() -> void:
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(fly_anim_name):
			sprite.play(fly_anim_name)
		else:
			sprite.play()


func _already_hit(target: Object) -> bool:
	return _hit_targets.has(target)


func _mark_hit(target: Object) -> void:
	_hit_targets[target] = true


func _get_valid_owner() -> Node:
	if _owner != null and is_instance_valid(_owner):
		return _owner

	_owner = null
	return null


func _on_owner_tree_exiting() -> void:
	_owner = null


func _on_screen_exited() -> void:
	queue_free()
