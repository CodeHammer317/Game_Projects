extends AbilitySet
class_name RavenAbilities

@export var heavy_punch_hitbox_scene: PackedScene
@export var punch_offset_right: Vector2 = Vector2(14, -6)
@export var punch_offset_left: Vector2 = Vector2(-14, -6)

@export var raven_projectile_scene: PackedScene
@export var raven_cooldown: float = 0.60
@export var raven_spawn_offset_right: Vector2 = Vector2(4, -18)
@export var raven_spawn_offset_left: Vector2 = Vector2(-4, -18)

# 45-degree downward attack angle once projectile transforms
@export var raven_dive_angle_right: Vector2 = Vector2(1, 1)
@export var raven_dive_angle_left: Vector2 = Vector2(-1, 1)

var _raven_timer: float = 0.0


func tick(player: Node, delta: float, other_player: Node = null) -> void:
	if _raven_timer > 0.0:
		_raven_timer = max(_raven_timer - delta, 0.0)

	# Optional co-op synergy hook
	if player is Node2D and other_player is Node2D:
		var dist = player.global_position.distance_to(other_player.global_position)
		if dist < 400.0:
			# Add synergy effects here later if desired
			pass


func on_attack_pressed(player: Node) -> void:
	if not (player is CharacterBody2D):
		return

	var body := player as CharacterBody2D

	# Air attack -> Raven projectile
	if not body.is_on_floor():
		_try_spawn_raven_projectile(body)
		return

	# Ground attack -> Heavy punch
	_try_heavy_punch(body)


func on_shoot_pressed(player: Node) -> void:
	if player.has_method("spawn_bullet"):
		player.spawn_bullet()


func _try_spawn_raven_projectile(player: CharacterBody2D) -> void:
	if raven_projectile_scene == null:
		return

	if _raven_timer > 0.0:
		return

	var projectile := raven_projectile_scene.instantiate()
	var spawn_parent := _get_spawn_parent(player)
	if spawn_parent == null:
		return

	spawn_parent.add_child(projectile)

	if projectile is Node2D:
		projectile.global_position = player.global_position + _get_raven_spawn_offset(player)

	if projectile.has_method("launch"):
		var dir := _get_raven_dive_direction(player)
		var owner_team := _get_int_property(player, "team", 1)
		projectile.launch(dir, player, owner_team)

	_raven_timer = raven_cooldown


func _try_heavy_punch(player: CharacterBody2D) -> void:
	if heavy_punch_hitbox_scene == null:
		return

	var hb := heavy_punch_hitbox_scene.instantiate()
	var spawn_parent := _get_spawn_parent(player)
	if spawn_parent == null:
		return

	spawn_parent.add_child(hb)

	if hb is Node2D:
		hb.global_position = player.global_position + _get_punch_offset(player)

	# Prefer a unified setup API if your punch hitbox supports it
	if hb.has_method("setup"):
		var facing := _get_facing_vector(player)
		var owner_team := _get_int_property(player, "team", 1)
		hb.setup(player, facing, owner_team)
	elif hb.has_method("set_owner_id"):
		var owner_id := _get_int_property(player, "player_id", 1)
		hb.set_owner_id(owner_id)


func _get_spawn_parent(player: Node) -> Node:
	if player.get_parent() != null:
		return player.get_parent()
	return player.get_tree().current_scene


func _get_sprite(player: Node) -> Node:
	if player.has_node("AnimatedSprite2D"):
		return player.get_node("AnimatedSprite2D")
	if player.has_node("Sprite2D"):
		return player.get_node("Sprite2D")
	return null


func _is_facing_left(player: Node) -> bool:
	var sprite := _get_sprite(player)
	if sprite == null:
		return false

	# Works for AnimatedSprite2D / Sprite2D if flip_h exists
	for prop in sprite.get_property_list():
		if prop.name == "flip_h":
			return bool(sprite.get("flip_h"))

	return false


func _get_facing_vector(player: Node) -> Vector2:
	return Vector2.LEFT if _is_facing_left(player) else Vector2.RIGHT


func _get_punch_offset(player: Node) -> Vector2:
	return punch_offset_left if _is_facing_left(player) else punch_offset_right


func _get_raven_spawn_offset(player: Node) -> Vector2:
	return raven_spawn_offset_left if _is_facing_left(player) else raven_spawn_offset_right


func _get_raven_dive_direction(player: Node) -> Vector2:
	var dir := raven_dive_angle_left if _is_facing_left(player) else raven_dive_angle_right
	return dir.normalized()


func _get_int_property(target: Object, property_name: String, fallback: int) -> int:
	for prop in target.get_property_list():
		if prop.name == property_name:
			return int(target.get(property_name))
	return fallback
