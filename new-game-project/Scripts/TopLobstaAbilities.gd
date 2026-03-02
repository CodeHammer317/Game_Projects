extends AbilitySet
class_name TopLobstaAbilities

@export var claw_hitbox_scene: PackedScene
@export var claw_offset_right: Vector2 = Vector2(18, -6)
@export var claw_offset_left: Vector2 = Vector2(-18, -6)

@export var melee_cooldown: float = 0.20
var _melee_cd_timer: float = 0.0

func tick(player: Node, delta: float, other_player: Node = null) -> void:
	if _melee_cd_timer > 0.0:
		_melee_cd_timer -= delta
		if _melee_cd_timer < 0.0:
			_melee_cd_timer = 0.0

	# Optional co-op synergy
	if other_player != null:
		var dist = player.global_position.distance_to(other_player.global_position)
		if dist < 400.0:
			# Example: faster melee or stronger effect
			pass

func on_attack_pressed(player: Node) -> void:
	if _melee_cd_timer > 0.0 or claw_hitbox_scene == null:
		return
	if not (player is Node2D):
		return

	var sprite := player.get_node_or_null("Sprite2D")
	var offset := claw_offset_right
	if sprite != null and sprite.flip_h:
		offset = claw_offset_left

	var hb := claw_hitbox_scene.instantiate()
	var world := player.get_tree().current_scene
	if world == null:
		return
	world.add_child(hb)

	if hb is Node2D:
		hb.global_position = player.global_position + offset

	if hb.has_method("set_owner_id"):
		var owner_id := 1
		if "player_id" in player:
			owner_id = player.player_id
		hb.set_owner_id(owner_id)

	_melee_cd_timer = melee_cooldown

func on_shoot_pressed(player: Node) -> void:
	if player.has_method("spawn_bullet"):
		player.spawn_bullet()
