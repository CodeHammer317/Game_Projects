# TopLobstaAbilities.gd
extends AbilitySet
class_name TopLobstaAbilities

@export var claw_hitbox_scene: PackedScene
@export var claw_offset_right: Vector2 = Vector2(18, -6)
@export var claw_offset_left: Vector2 = Vector2(-18, -6)

# Optionally gate melee with a brief cooldown so players can’t spam it
@export var melee_cooldown: float = 0.20
var _melee_cd_timer: float = 0.0

func tick(_player: Node, delta: float) -> void:
	if _melee_cd_timer > 0.0:
		_melee_cd_timer -= delta
		if _melee_cd_timer < 0.0:
			_melee_cd_timer = 0.0

func on_attack_pressed(player: Node) -> void:
	if _melee_cd_timer > 0.0:
		return
	if claw_hitbox_scene == null:
		return
	if not (player is Node2D):
		return

	# We expect PlayerBase to expose _facing_left (as provided)
	var _facing_left := false
	if player.has_method("_update_facing"):
		# We assume facing updated already in _physics_process
		pass
	# Access private field carefully (GDScript allows it within same project)
	##Sif " _facing_left" in String.keys(): # (No-op safety; can't reflect like this)
		# We cannot reflect private members reliably; instead assume a method or property
		pass

	# Safer: infer from sprite.flip_h if available
	var offset := claw_offset_right
	var sprite := player.get_node_or_null("Sprite2D")
	var is_left := false
	if sprite != null:
		is_left = sprite.flip_h
	if is_left:
		offset = claw_offset_left

	var hb := claw_hitbox_scene.instantiate()
	var world := player.get_tree().current_scene
	if world == null:
		return

	world.add_child(hb)
	if hb is Node2D:
		hb.global_position = player.global_position + offset

	# Optional: tell the HB who owns it (so it can filter friendly fire)
	if hb.has_method("set_owner_id"):
		if player.has_method("get"):
			# Prefer a direct field if exposed; otherwise pass 1 by default
			var owner_id := 1
			if "player_id" in player:
				owner_id = player.player_id
			hb.set_owner_id(owner_id)

	_melee_cd_timer = melee_cooldown

func on_shoot_pressed(player: Node) -> void:
	# Delegate to PlayerBase so bullet cap/cooldown apply, and Muzzle is used
	if player.has_method("spawn_bullet"):
		player.spawn_bullet()
