extends Node2D
class_name Main


func shake_camera(strength: float = 0.35) -> void:
	var camera: CameraShake = get_tree().get_first_node_in_group("camera_shake") as CameraShake

	if camera == null:
		print("Main: No CameraShake found in group camera_shake.")
		return

	camera.shake(strength)
