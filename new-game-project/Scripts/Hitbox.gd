# Hitbox.gd
extends Area2D
class_name Hitbox

@export var damage: int = 1
@export var knockback: Vector2 = Vector2.ZERO
@export var tags: Array[String] = []
@export var instigator: Node = null
@export var one_shot: bool = false   # bullets, projectiles

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))

func _on_area_entered(area: Area2D) -> void:
	if not area is Hurtbox:
		return

	var info := DamageInfo.new(damage, knockback, instigator, tags)
	area.receive_damage(info)

	if one_shot:
		queue_free()
