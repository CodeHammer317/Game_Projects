# res://autoload/PlayerManager.gd
extends Node

signal players_changed

# -------------------------------------------------
# Player registry & input devices
# -------------------------------------------------
var players: Array[Node2D] = []
var player_devices: Dictionary = {}   # { player_node : device_id }

# -------------------------------------------------
# Co-op synergy / resonance
# -------------------------------------------------
var resonance_strength: float = 0.0
var max_resonance_distance: float = 800.0

# -------------------------------------------------
# Player registration
# -------------------------------------------------
func register_player(player: Node2D, device_id: int) -> void:
	if players.has(player):
		return

	players.append(player)
	player_devices[player] = device_id

	emit_signal("players_changed")


func unregister_player(player: Node2D) -> void:
	if players.has(player):
		players.erase(player)

	if player_devices.has(player):
		player_devices.erase(player)

	emit_signal("players_changed")


# -------------------------------------------------
# Device helpers
# -------------------------------------------------
func get_player_device(player: Node2D) -> int:
	if player_devices.has(player):
		return player_devices[player]

	# Fallback to keyboard safely
	return InputBindings.KEYBOARD_DEVICE


func get_player_by_device(device_id: int) -> Node2D:
	for p in player_devices.keys():
		if player_devices[p] == device_id:
			return p

	return null


func sync_devices_from_inputbindings() -> void:
	# Call this after InputBindings.setup_*()
	for i in InputBindings.player_devices.keys():
		var device_id = InputBindings.player_devices[i]

		# Assign devices to already spawned players in order
		if i - 1 < players.size():
			var player_node = players[i - 1]
			player_devices[player_node] = device_id


# -------------------------------------------------
# Co-op helpers
# -------------------------------------------------
func get_other_player(player: Node2D) -> Node2D:
	for p in players:
		if p != player:
			return p

	return null


func update_resonance() -> void:
	if players.size() < 2:
		resonance_strength = 0.0
		return

	var p1 = players[0]
	var p2 = players[1]

	var dist = p1.global_position.distance_to(p2.global_position)

	var t = 1.0 - (dist / max_resonance_distance)

	if t < 0.0:
		t = 0.0
	elif t > 1.0:
		t = 1.0

	resonance_strength = t


# -------------------------------------------------
# Auto-update resonance each frame
# -------------------------------------------------
func _process(delta: float) -> void:
	update_resonance()
