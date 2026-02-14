# AbilitySet.gd
extends Resource
class_name AbilitySet

# Shared interface all characters follow
func on_attack_pressed(_player: Node) -> void:
	pass

func on_shoot_pressed(_player: Node) -> void:
	pass

func tick(_player: Node, _delta: float) -> void:
	pass
