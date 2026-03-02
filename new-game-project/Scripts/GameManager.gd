extends Node


# -----------------------------
# PLAYER PATHS
# -----------------------------
@export var player1_path: NodePath
@export var player2_path: NodePath

# References
var player1: PlayerBase
var player2: PlayerBase

func _ready() -> void:
	# Grab nodes
	player1 = get_node_or_null(player1_path)
	player2 = get_node_or_null(player2_path)

	# Connect joypad changes
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# Assign devices initially
	_assign_devices()

# -----------------------------
# JOYPAD CONNECT/DISCONNECT
# -----------------------------
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_assign_devices()

# -----------------------------
# DEVICE ASSIGNMENT
# -----------------------------
func _assign_devices() -> void:
	var pads := Input.get_connected_joypads()  # Array[int]

	# Default: keyboard -> Player 1
	var p1_device := -1
	var p2_device := 0

	if pads.size() >= 1:
		p2_device = pads[0]  # first controller -> Player 2

	# Apply input binding
	InputBindings.setup_local_coop(p1_device, p2_device)

	# Assign to PlayerBase nodes
	if player1 != null and player1.has_method("set_device_id"):
		player1.set_device_id(p1_device)
	if player2 != null and player2.has_method("set_device_id"):
		player2.set_device_id(p2_device)

	# Optional: register devices with PlayerManager
	if Engine.has_singleton("PlayerManager"):
		var pm := Engine.get_singleton("PlayerManager")
		if pm != null:
			if player1 != null:
				pm.register_player(player1, p1_device)
			if player2 != null:
				pm.register_player(player2, p2_device)
func setup_players_auto() -> void:
	InputBindings.setup_auto_local_coop()
	for i in InputBindings.player_devices.keys():
		var dev = InputBindings.player_devices[i]
		PlayerManager.register_player_device(i, dev)
