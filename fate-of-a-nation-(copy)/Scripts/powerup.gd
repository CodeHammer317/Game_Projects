extends Area2D
class_name Powerup

enum PowerupType {
	HEALTH,
	RAPID_FIRE,
	SPREAD_SHOT,
	SHIELD,
	BOMB
}

@export var powerup_type: PowerupType = PowerupType.HEALTH
@export var fall_speed: float = 30.0
@export var amount: int = 1
@export var duration: float = 6.0
@export var remove_when_offscreen: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var visible_notifier: VisibleOnScreenNotifier2D = get_node_or_null("VisibleOnScreenNotifier2D")


func _ready() -> void:
	_update_visual()
	_connect_signals()


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		return

	global_position.y += fall_speed * delta


func setup(new_powerup_type: int = -1, new_amount: int = 1, new_duration: float = 6.0) -> void:
	if new_powerup_type < 0:
		powerup_type = randi_range(0, PowerupType.size() - 1) as PowerupType
	else:
		powerup_type = new_powerup_type as PowerupType

	amount = new_amount
	duration = new_duration

	_update_visual()


func _connect_signals() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if visible_notifier != null:
		if not visible_notifier.screen_exited.is_connected(_on_screen_exited):
			visible_notifier.screen_exited.connect(_on_screen_exited)


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	var receiver: Node = _find_powerup_receiver(body)

	if receiver == null:
		return

	receiver.apply_powerup(powerup_type, amount, duration)
	queue_free()


func _find_powerup_receiver(body: Node) -> Node:
	if body.has_method("apply_powerup"):
		return body

	var parent: Node = body.get_parent()

	if parent != null:
		if parent.has_method("apply_powerup"):
			return parent

	return null


func _update_visual() -> void:
	match powerup_type:
		PowerupType.HEALTH:
			_play_if_exists(&"health")

		PowerupType.RAPID_FIRE:
			_play_if_exists(&"rapid_fire")

		PowerupType.SPREAD_SHOT:
			_play_if_exists(&"spread_shot")

		PowerupType.SHIELD:
			_play_if_exists(&"shield")

		PowerupType.BOMB:
			_play_if_exists(&"bomb")


func _play_if_exists(anim_name: StringName) -> void:
	if sprite == null:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation(anim_name):
		return

	if sprite.animation != anim_name:
		sprite.play(anim_name)


func _on_screen_exited() -> void:
	if not remove_when_offscreen:
		return

	queue_free()
