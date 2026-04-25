extends Area2D
class_name GlitchBullet

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var knockback: Vector2 = Vector2(90.0, -30.0)

@export var fly_anim_name: StringName = &"fly"
@export var hit_anim_name: StringName = &"hit"

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


func setup(direction: Vector2, owner: Node) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_owner = owner

	if sprite:
		if _direction.x < 0.0:
			sprite.scale.x = -absf(sprite.scale.x)
		else:
			sprite.scale.x = absf(sprite.scale.x)


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	global_position += _direction * speed * delta

	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _has_hit or body == _owner:
		return

	if body.has_method("apply_damage"):
		_apply_hit_to(body)


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or area == null or area == _owner:
		return

	var parent := area.get_parent()

	if parent == _owner:
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
		_owner
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
		_owner
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
