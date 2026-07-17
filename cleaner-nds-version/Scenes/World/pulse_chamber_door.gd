extends Node2D

signal opened

@export var auto_open_on_player_approach: bool = true

@onready var door_sprite: AnimatedSprite2D = $NephilimVault
@onready var approach_trigger: Area2D = $ApproachTrigger

var is_open: bool = false
var is_opening: bool = false


func _ready() -> void:
	approach_trigger.body_entered.connect(_on_approach_trigger_body_entered)


func open_door() -> void:
	if is_open or is_opening:
		return

	is_opening = true
	door_sprite.play(&"open")
	await door_sprite.animation_finished
	is_opening = false
	is_open = true
	approach_trigger.set_deferred(&"monitoring", false)
	opened.emit()


func reset_door() -> void:
	is_open = false
	is_opening = false
	door_sprite.stop()
	door_sprite.animation = &"open"
	door_sprite.frame = 0
	approach_trigger.set_deferred(&"monitoring", true)


func _on_approach_trigger_body_entered(body: Node2D) -> void:
	if not auto_open_on_player_approach:
		return
	if body.is_in_group(&"player") or body.name == &"Player":
		open_door()
