# Example: res://Main/GameManager.gd
extends Node

@export var player1: NodePath
@export var player2: NodePath

func _ready() -> void:
	_assign_devices_and_bind()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	# Re-evaluate on any change
	_assign_devices_and_bind()

func _assign_devices_and_bind() -> void:
	var pads := Input.get_connected_joypads() # Array[int]
	
	var p1_device := 0       # Keyboard -> Player 1 (choose your policy)
	var p2_device := 0
	if pads.size() > 0:
		p2_device = pads[0]  # First controller -> Player 2
		print("Device ID: ",pads)
	# Bind InputMap for both players
	InputBindings.setup_local_coop(p1_device, p2_device)

	# (Optional) if your Player scenes also track a device id for aiming, etc.,
	# you can set it here as well.
	var p1 := get_node_or_null(player1)
	var p2 := get_node_or_null(player2)
	if p1 and p1.has_method("set_device_id"):
		p1.set_device_id(p1_device)
	if p2 and p2.has_method("set_device_id"):
		p2.set_device_id(p2_device)
