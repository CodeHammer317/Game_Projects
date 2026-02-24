extends CharacterBody2D
class_name SimpleEnemy

@export var speed: float = 40.0
@export var max_health: int = 3

@onready var health = $Health
@onready var hurtbox = $Hurtbox
@onready var sprite: AnimatedSprite2D =$AnimatedSprite2D

func _ready() -> void:
	health.max_health = max_health
	hurtbox.connect("damaged", Callable(self, "_on_damaged"))
	health.connect("died", Callable(self, "_on_died"))

func _physics_process(_delta: float) -> void:
	# Simple movement: drift left
	velocity.x = -speed
	move_and_slide()


# ---------------------------------------------------------
# DAMAGE + DEATH
# ---------------------------------------------------------
func _on_damaged(damage_info: DamageInfo) -> void:
	health.apply_damage(damage_info.amount)
	flash_hit()

func _on_died() -> void:
	queue_free()


# ---------------------------------------------------------
# OPTIONAL HIT FLASH
# ---------------------------------------------------------
func flash_hit() -> void:
	if not sprite:
		return
	sprite.modulate = Color(1, 0.4, 0.4)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(1, 1, 1), 0.1)
