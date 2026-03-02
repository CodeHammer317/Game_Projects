# res://autoload/InputBindings.gd
extends Node

const KEYBOARD_DEVICE := -1
const ACTIONS := {
	"left":   {"key": KEY_A, "axis": JOY_AXIS_LEFT_X, "axis_dir": -1.0},
	"right":  {"key": KEY_D, "axis": JOY_AXIS_LEFT_X, "axis_dir": 1.0},
	"jump":   {"key": KEY_SPACE, "button": JOY_BUTTON_A},
	"attack": {"key": KEY_K, "button": JOY_BUTTON_X},
	"shoot":  {"key": KEY_J, "button": JOY_BUTTON_RIGHT_SHOULDER},
	"dash":   {"key": KEY_L, "button": JOY_BUTTON_B}
}

var player_devices: Dictionary = {}

func setup_single_player() -> void:
	player_devices.clear()
	_assign_player(1, KEYBOARD_DEVICE)
	_debug_dump()

func setup_local_coop(p1_device: int, p2_device: int) -> void:
	player_devices.clear()
	_assign_player(1, p1_device)
	_assign_player(2, p2_device)
	_debug_dump()

func setup_auto_local_coop() -> void:
	player_devices.clear()
	var pads = Input.get_connected_joypads()
	if pads.size() == 0:
		_assign_player(1, KEYBOARD_DEVICE)
	else:
		_assign_player(1, KEYBOARD_DEVICE)
		_assign_player(2, pads[0])
	_debug_dump()

func assign_player_device(player_num: int, device_id: int) -> void:
	_assign_player(player_num, device_id)
	_debug_dump()

func _assign_player(player_num: int, device_id: int) -> void:
	player_devices[player_num] = device_id
	for base_action in ACTIONS.keys():
		var action_name = "p%d_%s" % [player_num, base_action]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)

		if device_id == KEYBOARD_DEVICE:
			var ev = InputEventKey.new()
			ev.device = KEYBOARD_DEVICE
			ev.keycode = ACTIONS[base_action]["key"]
			ev.physical_keycode = ACTIONS[base_action]["key"]
			InputMap.action_add_event(action_name, ev)
		else:
			if base_action == "left" or base_action == "right":
				var evm = InputEventJoypadMotion.new()
				evm.device = device_id
				evm.axis = ACTIONS[base_action]["axis"]
				evm.axis_value = ACTIONS[base_action]["axis_dir"]
				InputMap.action_add_event(action_name, evm)
			else:
				var evb = InputEventJoypadButton.new()
				evb.device = device_id
				evb.button_index = ACTIONS[base_action]["button"]
				InputMap.action_add_event(action_name, evb)

func _debug_dump() -> void:
	print("\n=== INPUT BINDINGS ===")
	for player_num in player_devices.keys():
		var device_id = player_devices[player_num]
		var device_label = ""
		if device_id == KEYBOARD_DEVICE:
			device_label = "Keyboard"
		else:
			device_label = "Gamepad %d" % device_id
		print("Player %d -> %s" % [player_num, device_label])

		for base_action in ACTIONS.keys():
			var action_name = "p%d_%s" % [player_num, base_action]
			if not InputMap.has_action(action_name):
				continue
			var events = InputMap.action_get_events(action_name)
			var labels: Array[String] = []
			for ev in events:
				if ev is InputEventKey:
					labels.append("Key(%s)" % OS.get_keycode_string(ev.keycode))
				elif ev is InputEventJoypadButton:
					labels.append("PadBtn(%d)" % ev.button_index)
				elif ev is InputEventJoypadMotion:
					labels.append("PadAxis(%d=%.1f)" % [ev.axis, ev.axis_value])
			print("  %s -> %s" % [action_name, ", ".join(labels)])
	print("======================\n")



# res://autoload/InputBindings.gd
'''extends Node

# ==========================================================
# CONFIG
# ==========================================================

# Keyboard is always -1 in Godot 4
const KEYBOARD_DEVICE := -1

# Base logical actions
const ACTIONS := {
	"left": {
		"key": KEY_A,
		"axis": JOY_AXIS_LEFT_X,
		"axis_dir": -1.0
	},
	"right": {
		"key": KEY_D,
		"axis": JOY_AXIS_LEFT_X,
		"axis_dir": 1.0
	},
	"jump": {
		"key": KEY_SPACE,
		"button": JOY_BUTTON_A
	},
	"attack": {
		"key": KEY_K,
		"button": JOY_BUTTON_X
	},
	"shoot": {
		"key": KEY_J,
		"button": JOY_BUTTON_RIGHT_SHOULDER
	},
	"dash": {
		"key": KEY_L,
		"button": JOY_BUTTON_B
	}
}

# Track assigned devices
var player_devices: Dictionary = {}

# ==========================================================
# PUBLIC API
# ==========================================================

func setup_single_player() -> void:
	player_devices.clear()
	_assign_player(1, KEYBOARD_DEVICE)
	_debug_dump()


func setup_local_coop(p1_device: int, p2_device: int) -> void:
	player_devices.clear()

	_assign_player(1, p1_device)
	_assign_player(2, p2_device)

	_debug_dump()


func setup_auto_local_coop() -> void:
	player_devices.clear()

	var pads := Input.get_connected_joypads()

	if pads.is_empty():
		_assign_player(1, KEYBOARD_DEVICE)
	else:
		_assign_player(1, KEYBOARD_DEVICE)
		_assign_player(2, pads[0])

	_debug_dump()


func assign_player_device(player_num: int, device_id: int) -> void:
	_assign_player(player_num, device_id)
	_debug_dump()


# ==========================================================
# CORE BINDING LOGIC
# ==========================================================

func _assign_player(player_num: int, device_id: int) -> void:
	player_devices[player_num] = device_id

	for base_action in ACTIONS.keys():
		var action_name := _build_action_name(player_num, base_action)

		_ensure_action_exists(action_name)
		InputMap.action_erase_events(action_name)

		if device_id == KEYBOARD_DEVICE:
			_bind_keyboard(action_name, base_action)
		else:
			_bind_joypad(action_name, base_action, device_id)


func _bind_keyboard(action_name: String, base_action: String) -> void:
	var keycode = ACTIONS[base_action]["key"]

	var ev := InputEventKey.new()
	ev.device = KEYBOARD_DEVICE
	ev.keycode = keycode
	ev.physical_keycode = keycode

	InputMap.action_add_event(action_name, ev)


func _bind_joypad(action_name: String, base_action: String, device_id: int) -> void:

	if base_action in ["left", "right"]:
		var evm := InputEventJoypadMotion.new()
		evm.device = device_id
		evm.axis = ACTIONS[base_action]["axis"]
		evm.axis_value = ACTIONS[base_action]["axis_dir"]
		InputMap.action_add_event(action_name, evm)
	else:
		var evb := InputEventJoypadButton.new()
		evb.device = device_id
		evb.button_index = ACTIONS[base_action]["button"]
		InputMap.action_add_event(action_name, evb)


# ==========================================================
# UTILITIES
# ==========================================================

func _build_action_name(player_num: int, base_action: String) -> String:
	return "p%d_%s" % [player_num, base_action]


func _ensure_action_exists(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)


# ==========================================================
# DEBUG
# ==========================================================

func _debug_dump() -> void:
	print("\n=== INPUT BINDINGS ===")

	for player_num in player_devices.keys():
		var device_id = player_devices[player_num]

		var device_label := "Keyboard" if device_id == KEYBOARD_DEVICE else "Gamepad %d" % device_id
		print("Player %d -> %s" % [player_num, device_label])

		for base_action in ACTIONS.keys():
			var action_name := _build_action_name(player_num, base_action)
			if not InputMap.has_action(action_name):
				continue

			var events := InputMap.action_get_events(action_name)
			var labels: Array[String] = []

			for ev in events:
				if ev is InputEventKey:
					labels.append("Key(%s)" % OS.get_keycode_string(ev.keycode))
				elif ev is InputEventJoypadButton:
					labels.append("PadBtn(%d)" % ev.button_index)
				elif ev is InputEventJoypadMotion:
					labels.append("PadAxis(%d=%.1f)" % [ev.axis, ev.axis_value])

			print("  %s -> %s" % [action_name, ", ".join(labels)])

	print("======================\n")'''
