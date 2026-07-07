extends PlayerFsmState
class_name PlayerHitstunState


func physics_process(delta: float) -> void:
	player._run_active_frame(delta, true)
