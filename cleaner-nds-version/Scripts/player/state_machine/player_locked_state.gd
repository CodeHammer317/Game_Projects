extends PlayerFsmState
class_name PlayerLockedState


func physics_process(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player._input_dir = 0.0
	player._force_idle_pose()
	player.move_and_slide()
