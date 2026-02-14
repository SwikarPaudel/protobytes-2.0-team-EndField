extends CharacterBody2D

# Movement
@export var speed: float = 200.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# State
var can_move: bool = true

func _ready():
	# Add player to group for identification
	add_to_group("player")
	
	# Connect to battle signals
	Global.battle_started.connect(_on_battle_started)
	Global.battle_ended.connect(_on_battle_ended)
	
	# Setup camera
	camera.enabled = true
	camera.zoom = Vector2(1.0, 1.0)  # Adjust zoom as needed
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.15)
	env.glow_enabled = true
	env.glow_intensity = 0.8
	environment.environment = env
	add_child(environment)
	
	# Start with idle animation
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func print_tree_recursive(node: Node, depth: int):
	var indent = "  ".repeat(depth)
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_tree_recursive(child, depth + 1)

func _physics_process(delta: float) -> void:
	# Get input direction
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	input_vector = input_vector.normalized()
	
	# Handle movement if allowed
	if can_move and not Global.in_battle:
		# Apply movement
		if input_vector != Vector2.ZERO:
			velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
			
			# Flip sprite based on direction
			if input_vector.x != 0:
				sprite.flip_h = input_vector.x < 0
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		# In battle or can't move - slow down
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
	
	# Update animation based on input and velocity
	update_animation(input_vector)

func update_animation(input_vector: Vector2) -> void:
	if not animation_player:
		return
	
	# Don't interrupt attack animation
	if animation_player.current_animation == "attack" and animation_player.is_playing():
		return
	
	# In battle, stay idle
	if Global.in_battle:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")
		return
	
	# Determine if player is actively trying to move
	var trying_to_move = input_vector != Vector2.ZERO
	var actually_moving = velocity.length() > 20.0
	
	# Play run animation if trying to move OR if still have momentum
	if trying_to_move or actually_moving:
		if animation_player.current_animation != "run":
			animation_player.play("run")
	else:
		if animation_player.current_animation != "idle":
			animation_player.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	# Click detection for enemies
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not Global.in_battle:
			check_enemy_click(event.position)

func check_enemy_click(_screen_pos: Vector2) -> void:
	var world_pos = get_global_mouse_position()
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	
	var result = space_state.intersect_point(query, 1)
	
	if result.size() > 0:
		var collider = result[0].collider
		if collider.is_in_group("enemies"):
			collider.on_clicked()

func play_attack_animation() -> void:
	if animation_player and animation_player.has_animation("attack"):
		animation_player.play("attack")
		# Wait for attack animation to finish
		await animation_player.animation_finished
		# Return to idle
		if Global.in_battle:
			animation_player.play("idle")

func _on_battle_started(enemy: Node) -> void:
	can_move = false
	# Play idle during battle
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func _on_battle_ended(victory: bool) -> void:
	can_move = true
	
	# Play attack animation only on victory
	if victory:
		play_attack_animation()
	else:
		# Return to idle immediately on loss/cancel
		if animation_player and animation_player.has_animation("idle"):
			animation_player.play("idle")
