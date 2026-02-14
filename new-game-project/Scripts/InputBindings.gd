# res://autoload/InputBindings.gd
extends Node

# Call this whenever device assignments change.
func setup_local_coop(p1_device: int, p2_device: int) -> void:
	_bind_player_actions("_p1", p1_device)
	_bind_player_actions("_p2", p2_device)
	# Optional debug
	_debug_dump(["left","right","jump","attack","shoot","dash"])

# Define your action names once here (base names only).
const ACTIONS := {
	"left":    {"key": KEY_A,            "axis": JOY_AXIS_LEFT_X,  "axis_dir": -1.0},
	"right":   {"key": KEY_D,            "axis": JOY_AXIS_LEFT_X,  "axis_dir":  1.0},
	"jump":    {"key": KEY_SPACE,        "button": JOY_BUTTON_A},
	"attack":  {"key": KEY_K,            "button": JOY_BUTTON_X},
	"shoot":   {"key": KEY_J,            "button": JOY_BUTTON_RIGHT_SHOULDER},
	"dash":    {"key": KEY_L,            "button": JOY_BUTTON_B}
}

func _bind_player_actions(tag: String, device_id: int) -> void:
	for base_action in ACTIONS.keys():
		var action_name := "p%s_%s" % [tag.substr(1, tag.length()), base_action] # p1_left, p2_jump, etc.
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)

		if device_id == 0:
			# Keyboard events bound to device 0 only
			var evk := InputEventKey.new()
			evk.device = 0
			evk.keycode = ACTIONS[base_action]["key"]
			InputMap.action_add_event(action_name, evk)
		else:
			# Joypad motion for left/right
			if base_action == "left" or base_action == "right":
				var evm := InputEventJoypadMotion.new()
				evm.device = device_id
				evm.axis = ACTIONS[base_action]["axis"]
				evm.axis_value = ACTIONS[base_action]["axis_dir"]
				InputMap.action_add_event(action_name, evm)
			else:
				# Joypad button
				var evb := InputEventJoypadButton.new()
				evb.device = device_id
				evb.button_index = ACTIONS[base_action]["button"]
				InputMap.action_add_event(action_name, evb)

# Optional: helpful to verify bindings and devices
func _debug_dump(which: Array[String]) -> void:
	for base_action in which:
		for player in ["p1_", "p2_"]:
			var action_name = player + base_action
			if not InputMap.has_action(action_name):
				continue
			var evs := InputMap.action_get_events(action_name)
			var labels := []
			for ev in evs:
				var dev := ev.device
				if ev is InputEventKey:
					labels.append("Key(%s) dev=%d" % [OS.get_keycode_string(ev.keycode), dev])
				elif ev is InputEventJoypadButton:
					labels.append("PadBtn(%d) dev=%d" % [ev.button_index, dev])
				elif ev is InputEventJoypadMotion:
					labels.append("PadAxis(%d=%.1f) dev=%d" % [ev.axis, ev.axis_value, dev])
			print_rich("[b]%s[/b] -> %s" % [action_name, ", ".join(labels)])
