extends Resource
class_name AbilitySet

# Tick is called every physics frame
# _player = owner player, _delta = delta, _other_player = optional co-op
func tick(_player: Node, _delta: float, _other_player: Node = null) -> void:
	pass

func on_attack_pressed(_player: Node) -> void:
	pass

func on_shoot_pressed(_player: Node) -> void:
	pass
