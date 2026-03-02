extends AbilitySet
class_name RavenAbilities

@export var heavy_punch_hitbox_scene: PackedScene
@export var punch_offset_right: Vector2 = Vector2(14, -6)
@export var punch_offset_left: Vector2 = Vector2(-14, -6)

@export var dive_hitbox_scene: PackedScene
@export var dive_cooldown: float = 0.60
@export var dive_velocity_y: float = 720.0
var _dive_timer: float = 0.0

func tick(player: Node, delta: float, other_player: Node = null) -> void:
	if _dive_timer > 0.0:
		_dive_timer -= delta
		if _dive_timer < 0.0:
			_dive_timer = 0.0

	# Optional: implement co-op synergy effects here
	if other_player != null:
		# Example: increase damage if close to other player
		var dist = player.global_position.distance_to(other_player.global_position)
		if dist < 400.0:
			# Some effect, e.g., boost attack damage or speed
			pass

func on_attack_pressed(player: Node) -> void:
	if not (player is CharacterBody2D):
		return

	# --- AIRBORNE: Dive Kick ---
	if not player.is_on_floor():
		if _dive_timer > 0.0:
			return
		player.velocity.y = dive_velocity_y
		_spawn_dive_hitbox(player)
		_dive_timer = dive_cooldown
		return

	# --- GROUNDED: Heavy Punch ---
	if heavy_punch_hitbox_scene == null:
		return

	var sprite := player.get_node_or_null("Sprite2D")
	var offset := punch_offset_right
	if sprite != null and sprite.flip_h:
		offset = punch_offset_left

	var hb := heavy_punch_hitbox_scene.instantiate()
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

func on_shoot_pressed(player: Node) -> void:
	if player.has_method("spawn_bullet"):
		player.spawn_bullet()

func _spawn_dive_hitbox(player: CharacterBody2D) -> void:
	if dive_hitbox_scene == null:
		return
	var hb := dive_hitbox_scene.instantiate()
	var world := player.get_tree().current_scene
	if world == null:
		return
	world.add_child(hb)

	if hb is Node2D:
		hb.global_position = player.global_position + Vector2(0, 10)

	if hb.has_method("set_owner_id"):
		var owner_id := 1
		if "player_id" in player:
			owner_id = player.player_id
		hb.set_owner_id(owner_id)
