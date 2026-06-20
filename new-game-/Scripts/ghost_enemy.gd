extends CharacterBody2D

# --- Export Variables ---
@export var chase_speed := 120.0 # Speed when chasing the player
@export var gravity := 500.0     # Gravity applied to the enemy
@export var detection_range := 200 # How far the enemy can detect the player
@export var attack_range := 30.0  # How close the enemy needs to be to attack
@export var damage := 10      # Damage dealt by the enemy's melee attack
@export var max_health := 50      # Maximum health of the enemy
@export var damage_cooldown := 0.5 # How often this enemy can hit an overlapping player
@export var health_bar_offset := Vector2(0, -30) # NEW: Offset for the health bar relative to the enemy's origin

# --- Node References (Assign in Editor) ---
@onready var animated_sprite = $AnimatedSprite2D
@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var main_collision_shape = $CollisionShape2D # Added for disabling on death
@onready var health_bar = $HealthBar # NEW: Reference to the instanced health bar node (assuming it's named "HealthBar")

# --- Enemy States ---
enum States { IDLE, CHASE, ATTACK, HIT, DEAD }
var current_state = States.IDLE:
	set(new_state):
		if current_state == new_state: # Only change if different
			return
		_exit_state(current_state)
		current_state = new_state
		_enter_state(current_state)

# --- Internal Variables ---
var current_health = max_health
var player: CharacterBody2D = null # Reference to the detected player node
var facing_left = false # To control sprite flipping
var can_deal_damage = true # Flag to control enemy's damage output frequency

# NEW: Create a Timer node in code for enemy's internal damage cooldown
var enemy_hit_cooldown_timer: Timer

# --- Called when the node enters the scene tree for the first time. ---
func _ready():
	
	# Ensure the initial state is set up
	_enter_state(current_state)

	# --- Setup for new enemy hit cooldown timer ---
	enemy_hit_cooldown_timer = Timer.new()
	enemy_hit_cooldown_timer.wait_time = damage_cooldown
	enemy_hit_cooldown_timer.one_shot = true # We want it to run once per damage instance
	# Connect the timeout signal to reset the damage flag
	enemy_hit_cooldown_timer.timeout.connect(func(): can_deal_damage = true)
	add_child(enemy_hit_cooldown_timer) # Add the timer as a child of the enemy node

		# Disable attack area initially; only enable when attacking or checking overlaps
	attack_area.monitoring = false
	attack_area.monitorable = false
	print("Enemy AttackArea initially disabled.")

	# NEW: Initialize the health bar position and values
	if health_bar != null:
		health_bar.position = health_bar_offset # Set initial offset
		health_bar.update_health_bar(current_health, max_health) # Update initial health value
		print("Enemy health bar initialized.")

	print("SkeletonEnemy _ready() finished.")

# --- Physics Processing (called every physics frame) ---
func _physics_process(delta):
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0 # Reset vertical velocity if grounded

	# Handle behavior based on current state
	match current_state:
		States.IDLE:
			# If player detected, transition to CHASE
			if player:
				current_state = States.CHASE
				print("Enemy: Player detected, transitioning to CHASE.")
			else:
				velocity.x = 0 # Ensure idle skeleton stops if no player

		States.CHASE:
			# Move towards the player
			if player:
				move_towards_point(player.global_position, chase_speed)
				# If player is within attack range, transition to ATTACK
				if global_position.distance_to(player.global_position) < attack_range:
					current_state = States.ATTACK
					print("Enemy: Player in attack range, transitioning to ATTACK.")
			else:
				# If player is lost, go back to IDLE
				current_state = States.IDLE # Go back to IDLE if player lost
				print("Enemy: Player lost, transitioning to IDLE.")

		States.ATTACK:
			# While in ATTACK state, periodically check for overlapping players
			# and deal damage if our internal cooldown allows and player is not invincible
			if player != null and can_deal_damage:
				# Use get_overlapping_bodies to check for current overlaps
				var overlapping_bodies = attack_area.get_overlapping_bodies()
				for body in overlapping_bodies:
					# Ensure the overlapping body is the player and has a take_damage method
					if body.is_in_group("player") and body.has_method("take_damage"):
						body.take_damage(damage) # Pass the enemy's 'damage' to the player
						print("Enemy hit player (from physics_process check) for ", damage, " damage!")
						can_deal_damage = false # Set our internal damage cooldown
						enemy_hit_cooldown_timer.start() # Start the cooldown timer
						break # Only hit one player per check if multiple overlap
			pass # Keep pass as other attack logic (animation, etc.) is handled in _enter_state / _exit_state

		States.HIT:
			# Movement is stopped in _enter_state(HIT)
			pass # Animation and recovery handled in _enter_state
		States.DEAD:
			# No movement or actions when dead
			pass

	# Apply the calculated velocity and move the character
	move_and_slide()
	update_facing_direction()
# --- State Machine Callbacks ---
# Called when entering a new state
func _enter_state(new_state):
	print("Enemy Entering state:", new_state)
	match new_state:
		States.IDLE:
			animated_sprite.play("idle")
			velocity.x = 0
		States.CHASE:
			animated_sprite.play("run") # Assuming a "run" animation for chasing
		States.ATTACK:
			animated_sprite.play("attack") # Play attack animation
			velocity.x = 0 # Stop movement during attack
			# Use set_deferred for enabling/disabling areas to avoid physics conflicts
			if attack_area != null:
				attack_area.set_deferred("monitoring", true) # Enable attack hitbox
				attack_area.set_deferred("monitorable", true)
				print("Enemy AttackArea enabled for ATTACK.")
			# IMPORTANT: The damage itself is now handled by the _physics_process check
			# This await is primarily for the *animation completion* and transition logic.
			await animated_sprite.animation_finished # Wait for animation to finish
			# After attack animation, if still in ATTACK state:
			if current_state == States.ATTACK:
				if attack_area != null:
					attack_area.set_deferred("monitoring", false) # Disable attack hitbox
					attack_area.set_deferred("monitorable", false)
					print("Enemy AttackArea disabled after ATTACK animation finished.")
				# Decide next state after attack
				if player and global_position.distance_to(player.global_position) < attack_range:
					current_state = States.ATTACK # Stay in attack if player still in range (to start another attack)
				elif player:
					current_state = States.CHASE # Go back to chasing if player moved out of range
				else:
					current_state = States.IDLE # Go back to idle if player lost
		States.HIT:
			animated_sprite.play("hit")
			velocity.x = 0 # Stop movement when hit
			# Optionally add a small knockback here
			await animated_sprite.animation_finished
			if current_state == States.HIT:
				current_state = States.IDLE # Recover to idle
		States.DEAD:
			animated_sprite.play("death")
			set_physics_process(false) # Stop physics processing
			# Disable collisions and areas immediately to prevent further interactions
			# Use set_deferred for these property changes
			if main_collision_shape != null:
				main_collision_shape.set_deferred("disabled", true)
				print("Enemy Main CollisionShape disabled.")
			if detection_area != null:
				detection_area.set_deferred("monitoring", false)
				detection_area.set_deferred("monitorable", false)
				print("Enemy DetectionArea disabled.")
			if attack_area != null:
				attack_area.set_deferred("monitoring", false)
				attack_area.set_deferred("monitorable", false)
				print("Enemy AttackArea disabled on death.")
			# Death timer for queue_free() is handled here for the enemy.
			print("Enemy death timer started.")
			await get_tree().create_timer(1.5).timeout # Wait for 1.5 seconds (or whatever duration anim needs)
			print("Enemy death timer finished. Queueing free.")
			queue_free() # Remove the enemy node from the scene tree


# Called when exiting a state
func _exit_state(old_state):
	print("Enemy Exiting state:", old_state)
	match old_state:
		States.ATTACK:
			# Ensure attack area is disabled when exiting attack state
			# (though _physics_process manages re-enabling for repeated attacks)
			if attack_area != null:
				attack_area.set_deferred("monitoring", false)
				attack_area.set_deferred("monitorable", false)
				print("Enemy AttackArea explicitly disabled on exit from ", old_state)
		# Add any other cleanup when exiting specific states
		pass

# --- Movement Helper ---
func move_towards_point(point: Vector2, speed_val: float):
	var direction = (point - global_position).normalized()
	velocity.x = direction.x * speed_val

# --- Damage and Health ---

# Call this function from player's attack or projectile script
func take_damage(amount: int):
	print("Enemy take_damage called with amount: ", amount)
	if current_state == States.DEAD:
		print("Enemy not taking damage: already dead.")
		return # Cannot take damage if already dead

	current_health -= amount
	print("Enemy took ", amount, " damage. Current health: ", current_health)

	# NEW: Update the health bar
	if health_bar != null:
		health_bar.update_health_bar(current_health, max_health)

	if current_health <= 0:
		current_health = 0
		current_state = States.DEAD # This will trigger the death logic in _enter_state
		print("Enemy health <= 0, transitioning to DEAD state.")
	else:
		current_state = States.HIT # Transition to hit state if not dead
		print("Enemy health > 0, transitioning to HIT state.")


# --- Signal Callbacks ---

# Player detection callback
func _on_detection_area_body_entered(body: Node2D):
	print("Enemy DetectionArea body_entered: ", body.name, " (Type: ", body.get_class(), ")")
	if body.is_in_group("player"): # Ensure player node is in "player" group
		player = body # Assign player reference
		print("Enemy: Player node identified: ", player.name)
		current_state = States.CHASE # Start chasing
		print("Enemy: Transitioning to CHASE due to player detection.")
	else:
		print("Enemy: Colliding body '", body.name, "' is NOT in 'player' group for detection.")

# Player lost callback
func _on_detection_area_body_exited(body: Node2D):
	print("Enemy DetectionArea body_exited: ", body.name, " (Type: ", body.get_class(), ")")
	if body.is_in_group("player"):
		player = null # Clear player reference
		print("Enemy: Player node lost: ", body.name)
		current_state = States.IDLE # Go back to idle when player leaves
		print("Enemy: Transitioning to IDLE due to player lost.")
	else:
		print("Enemy: Colliding body '", body.name, "' is NOT in 'player' group for exit.")


func update_facing_direction():
	# Always flip to face the player if one is detected, otherwise rely on velocity (which will be 0 when idle)
	if player:
		if player.global_position.x < global_position.x:
			facing_left = true
		elif player.global_position.x > global_position.x:
			facing_left = false
	elif velocity.x > 0: # Fallback to velocity if no player (e.g., if somehow still moving)
		facing_left = false
	elif velocity.x < 0:
		facing_left = true

	animated_sprite.flip_h = facing_left
