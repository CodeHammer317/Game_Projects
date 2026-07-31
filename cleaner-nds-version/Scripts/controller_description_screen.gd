extends Control

signal closed

@onready var back_button: Button = $Frame/Margin/Layout/BackButton


func _ready() -> void:
	back_button.pressed.connect(close)
	visible = false


func open() -> void:
	visible = true
	back_button.grab_focus()


func close() -> void:
	if not visible:
		return

	visible = false
	back_button.release_focus()
	closed.emit()
