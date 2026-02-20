# Hurtbox.gd
extends Area2D
class_name Hurtbox

signal damaged(info: DamageInfo)

@export var invincible: bool = false
@export var accepted_tags: Array[String] = []   # optional filtering

func receive_damage(info: DamageInfo) -> void:
	if invincible:
		return

	if accepted_tags.size() > 0:
		for tag in info.tags:
			if tag in accepted_tags:
				emit_signal("damaged", info)
				return
		return

	emit_signal("damaged", info)
