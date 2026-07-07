extends RefCounted
class_name PlayerFsmState

var player = null
var state_name: StringName = &"state"


func setup(owner, name: StringName) -> PlayerFsmState:
	player = owner
	state_name = name
	return self


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_process(_delta: float) -> void:
	pass
