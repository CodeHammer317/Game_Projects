extends Node

signal upgrade_unlocked(upgrade_name: StringName)

const UPGRADE_DEFINITIONS := {
	&"double_jump": {
		"display_name": "Double Jump",
		"description": "Jump once more while airborne."
	},
	&"wall_slide": {
		"display_name": "Wall Slide",
		"description": "Slide down walls and wall jump."
	},
	&"charge_shot": {
		"display_name": "Charge Shot",
		"description": "Hold shoot to charge a stronger projectile."
	}
}

var max_health: int = 10
var current_health: int = 10
var player_dead: bool = false
var starting_upgrades: Array[StringName] = [&"double_jump"]
var unlocked_upgrades: Dictionary = {}


func _ready() -> void:
	reset_upgrades()


func reset_all() -> void:
	current_health = max_health
	player_dead = false
	reset_upgrades()


func has_upgrade(upgrade_name: StringName) -> bool:
	return unlocked_upgrades.get(upgrade_name, false)


func unlock_upgrade(upgrade_name: StringName) -> bool:
	if not UPGRADE_DEFINITIONS.has(upgrade_name):
		push_warning("Unknown upgrade: " + str(upgrade_name))
		return false

	if has_upgrade(upgrade_name):
		return false

	unlocked_upgrades[upgrade_name] = true
	upgrade_unlocked.emit(upgrade_name)
	return true


func reset_upgrades() -> void:
	unlocked_upgrades.clear()

	for upgrade_name in starting_upgrades:
		if UPGRADE_DEFINITIONS.has(upgrade_name):
			unlocked_upgrades[upgrade_name] = true


func get_upgrade_display_name(upgrade_name: StringName) -> String:
	if not UPGRADE_DEFINITIONS.has(upgrade_name):
		return str(upgrade_name).capitalize()

	return UPGRADE_DEFINITIONS[upgrade_name].get("display_name", str(upgrade_name).capitalize())
