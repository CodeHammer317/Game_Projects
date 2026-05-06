extends Node
class_name PowerupSpawner

@export var powerup_scene: PackedScene

var powerup_pool: Array[int] = [
	Powerup.PowerupType.HEALTH,
	Powerup.PowerupType.RAPID_FIRE,
	Powerup.PowerupType.SPREAD_SHOT,
	Powerup.PowerupType.SHIELD,
	Powerup.PowerupType.BOMB
]


func _ready() -> void:
	randomize()

	if not GameState.powerup_earned.is_connected(_on_powerup_earned):
		GameState.powerup_earned.connect(_on_powerup_earned)


func _on_powerup_earned(killstreak: int) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	_spawn_powerup(player.global_position)


func _spawn_powerup(pos: Vector2) -> void:
	if powerup_scene == null:
		return

	var p: Powerup = powerup_scene.instantiate()
	get_tree().current_scene.add_child(p)

	p.global_position = pos

	var random_type: int = _get_random_powerup()
	p.setup(random_type)


func _get_random_powerup() -> int:
	var index: int = randi() % powerup_pool.size()
	return powerup_pool[index]   
