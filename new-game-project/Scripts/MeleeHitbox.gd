# MeleeHitbox.gd (optional helper for claw/punch/dive)
extends Area2D

@export var damage: int = 1
@export var lifetime: float = 0.12
@export var knockback: Vector2 = Vector2(90, -40)
@export var affect_enemies: bool = true
@export var affect_players: bool = false

var _owner_id: int = 0
var _timer: float = 0.0
var _hit_ids := {}

func _ready() -> void:
	_timer = lifetime
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		queue_free()

func set_owner_id(id: int) -> void:
	_owner_id = id

func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _hit(target: Node) -> void:
	if target == null:
		return
	var iid := target.get_instance_id()
	if _hit_ids.has(iid):
		return
	_hit_ids[iid] = true

	# Simple friend/foe filter using groups (same pattern as Bullet.gd)
	var is_enemy := target.is_in_group("Enemies")
	var is_player := target.is_in_group("Players")

	if is_enemy and not affect_enemies:
		return
	if is_player and not affect_players:
		return

	if target.has_method("apply_damage"):
		target.call("apply_damage", damage, _owner_id)
	elif target.has_method("hit"):
		target.call("hit", damage, _owner_id)

	if target is CharacterBody2D:
		target.velocity += knockback
