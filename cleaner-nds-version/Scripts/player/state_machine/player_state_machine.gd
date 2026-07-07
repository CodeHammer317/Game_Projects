extends RefCounted
class_name PlayerStateMachine

const PlayerFsmStateScript := preload("res://Scripts/player/state_machine/player_fsm_state.gd")
const PlayerLockedStateScript := preload("res://Scripts/player/state_machine/player_locked_state.gd")
const PlayerInactiveStateScript := preload("res://Scripts/player/state_machine/player_inactive_state.gd")
const PlayerHitstunStateScript := preload("res://Scripts/player/state_machine/player_hitstun_state.gd")
const PlayerNormalStateScript := preload("res://Scripts/player/state_machine/player_normal_state.gd")

var player = null
var current_state = null
var _states: Dictionary = {}


func setup(owner) -> PlayerStateMachine:
	player = owner
	_states = {
		&"locked": PlayerLockedStateScript.new().setup(player, &"locked"),
		&"game_over": PlayerInactiveStateScript.new().setup(player, &"game_over"),
		&"dead": PlayerInactiveStateScript.new().setup(player, &"dead"),
		&"hitstun": PlayerHitstunStateScript.new().setup(player, &"hitstun"),
		&"normal": PlayerNormalStateScript.new().setup(player, &"normal"),
	}
	_change_state(&"normal")
	return self


func physics_process(delta: float) -> void:
	_change_state(_choose_state())

	if current_state != null:
		current_state.physics_process(delta)


func _choose_state() -> StringName:
	if player.control_locked:
		return &"locked"

	if player._is_game_over:
		return &"game_over"

	if player._is_dead:
		return &"dead"

	if player._hitstun_timer > 0.0:
		return &"hitstun"

	return &"normal"


func _change_state(next_state_name: StringName) -> void:
	var next_state = _states.get(next_state_name)
	if next_state == null:
		return

	if current_state == next_state:
		return

	if current_state != null:
		current_state.exit()

	current_state = next_state
	current_state.enter()
