extends Node

var max_health: int = 10
var current_health: int = 10
var player_dead: bool = false

func reset_all() -> void:
	current_health = max_health
	player_dead = false
