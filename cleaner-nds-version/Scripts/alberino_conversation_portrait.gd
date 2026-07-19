extends AnimatedSprite2D

@export var speaking := true:
	set(value):
		speaking = value
		_update_animation()


func _ready() -> void:
	_update_animation()


func set_speaking(value: bool) -> void:
	speaking = value


func _update_animation() -> void:
	if not is_node_ready():
		return
	play(&"talk" if speaking else &"idle")
