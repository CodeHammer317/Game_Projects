# Hurtbox.gd
extends Area2D
class_name Hurtbox

@export var health_path: NodePath
@export var team: int = 0

@onready var health: Health = get_node(health_path)


func take_damage(info: DamageInfo) -> void:
	if info == null:
		return

	if info.team == team:
		return

	health.apply_damage(info)
