extends Area2D
class_name Powerup

@export var powerup_type: StringName = &"spread"
@export var lifetime: float = 8.0
@export var fall_speed: float = 45.0

@onready var lifetime_timer: Timer = $LifetimeTimer


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if lifetime_timer != null:
		lifetime_timer.one_shot = true
		lifetime_timer.wait_time = lifetime

		if not lifetime_timer.timeout.is_connected(_on_lifetime_timer_timeout):
			lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)

		lifetime_timer.start()


func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		queue_free()
		return

	global_position.y += fall_speed * delta


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if body.has_method("apply_powerup"):
		body.apply_powerup(powerup_type)
		queue_free()


func _on_lifetime_timer_timeout() -> void:
	queue_free()
