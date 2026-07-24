extends Area2D
class_name GlitchBullet

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var knockback: Vector2 = Vector2(90.0, -30.0)

@export var fly_anim_name: StringName = &"fly"
@export var hit_anim_name: StringName = &"hit"
@export var rotate_visual_to_trajectory: bool = true
# Treat the bright leading edge as facing right; trajectory rotation handles
# every other firing angle from this authored orientation.
@export var sprite_forward_direction: Vector2 = Vector2.RIGHT

var _direction: Vector2 = Vector2.RIGHT
var _owner: Node = null
var _time_left: float = 0.0
var _hit_targets: Dictionary = {}
var _has_hit: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

# 🔊 Audio
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

	# ✅ PLAY FIRE SOUND ON SPAWN
	if fire_sound and fire_sound.stream:
		fire_sound.play()


func setup(direction: Vector2, source_node: Node) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_owner = source_node
	if _owner != null and is_instance_valid(_owner):
		if not _owner.tree_exiting.is_connected(_on_owner_tree_exiting):
			_owner.tree_exiting.connect(_on_owner_tree_exiting, CONNECT_ONE_SHOT)
	_align_visual_to_trajectory()


func _align_visual_to_trajectory() -> void:
	if sprite == null:
		return

	# Keep the animation's native scale. Rotating from its authored forward
	# vector makes every spread/radial shot visually follow its velocity.
	sprite.scale.x = absf(sprite.scale.x)
	if rotate_visual_to_trajectory:
		sprite.flip_h = false
		var authored_forward := sprite_forward_direction.normalized()
		if authored_forward == Vector2.ZERO:
			authored_forward = Vector2.RIGHT
		sprite.rotation = _direction.angle() - authored_forward.angle()
	else:
		sprite.rotation = 0.0
		sprite.flip_h = _direction.x > 0.0


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	global_position += _direction * speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _has_hit or body == _get_valid_owner():
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)


func _on_area_entered(area: Area2D) -> void:
	var source := _get_valid_owner()
	if _has_hit or area == null or area == source:
		return

	var parent := area.get_parent()

	if parent == source:
		return

	if area.has_method("apply_hit"):
		_apply_hit_area(area)
	elif parent and parent.has_method("apply_damage"):
		_apply_hit_to(parent)


func _apply_hit_area(area: Area2D) -> void:
	if _already_hit(area):
		return

	var info := DamageInfo.new(
		damage,
		Vector2(_direction.x * knockback.x, knockback.y),
		_get_valid_owner()
	)

	area.apply_hit(info)
	_mark_hit(area)
	_enter_hit_state()


func _apply_hit_to(target: Node) -> void:
	if _already_hit(target):
		return

	var info := DamageInfo.new(
		damage,
		Vector2(_direction.x * knockback.x, knockback.y),
		_get_valid_owner()
	)

	target.apply_damage(info)
	_mark_hit(target)
	_enter_hit_state()


func _enter_hit_state() -> void:
	if _has_hit:
		return

	_has_hit = true

	# ❌ stop fire sound immediately
	if fire_sound and fire_sound.playing:
		fire_sound.stop()

	# 🔊 play hit sound
	if hit_sound and hit_sound.stream:
		hit_sound.play()

	# disable collision
	if collision:
		collision.set_deferred("disabled", true)

	# play hit animation
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


func _on_screen_exited() -> void:
	queue_free()


func _get_valid_owner() -> Node:
	if _owner != null and is_instance_valid(_owner):
		return _owner

	_owner = null
	return null


func _on_owner_tree_exiting() -> void:
	# Enemy projectiles live under the room, not under their source. Remove them
	# before a freed source can be passed into typed DamageInfo construction.
	_owner = null
	queue_free()
