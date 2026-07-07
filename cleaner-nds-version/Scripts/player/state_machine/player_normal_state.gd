extends PlayerFsmState
class_name PlayerNormalState


func physics_process(delta: float) -> void:
	player._run_active_frame(delta, false)
