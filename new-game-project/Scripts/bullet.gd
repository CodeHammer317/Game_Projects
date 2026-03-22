extends Projectile
class_name Bullet

@onready var sprite: Sprite2D = $Sprite2D


func launch(direction: Vector2, target: Node2D = null, owner_node: Node = null) -> void:
	super.launch(direction, target, owner_node)

	if sprite:
		sprite.flip_h = direction.x < 0.0
