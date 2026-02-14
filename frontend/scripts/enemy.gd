extends Area2D

# Enemy properties
@export var enemy_name: String = "Skeleton"
@export_enum("EASY", "MEDIUM", "HARD", "BOSS") var difficulty: int = 0
@export var move_speed: float = 50.0
@export var patrol_radius: float = 100.0

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# State
var is_frozen: bool = false
var is_defeated: bool = false
var start_position: Vector2
var patrol_direction: Vector2

# Outline colors by difficulty
var difficulty_colors = {
	0: Color(0.0, 1.0, 0.0, 0.9),      # EASY - Bright Green
	1: Color(1.0, 1.0, 0.0, 0.9),      # MEDIUM - Yellow
	2: Color(1.0, 0.0, 0.0, 0.9),      # HARD - Red
	3: Color(0.2, 0.6, 1.0, 0.9)       # BOSS - Blue
}

func _ready():
	add_to_group("enemies")
	start_position = global_position
	patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	# Setup colored outline
	setup_outline()
	
	# Check if already defeated
	if str(get_instance_id()) in Global.defeated_enemies:
		queue_free()
		return
	
	# Start animation
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")
	
	# Connect signals
	Global.battle_started.connect(_on_battle_started)
	Global.battle_ended.connect(_on_battle_ended)
	input_event.connect(_on_input_event)

func setup_outline():
	"""Apply colored outline shader based on difficulty"""
	if not sprite:
		push_error("No Sprite2D found on enemy!")
		return
	
	# Create shader material
	var shader_material = ShaderMaterial.new()
	var shader = load("res://assets/shaders/outline.gdshader")
	
	if not shader:
		push_error("Outline shader not found at res://assets/shaders/outline.gdshader")
		return
	
	shader_material.shader = shader
	
	# Set color based on difficulty
	var outline_color = difficulty_colors.get(difficulty, Color.WHITE)
	shader_material.set_shader_parameter("outline_color", outline_color)
	shader_material.set_shader_parameter("outline_width", 2.5)
	
	# Apply to sprite
	sprite.material = shader_material
	
	print("[", enemy_name, "] Outline applied - Difficulty: ", difficulty, " Color: ", outline_color)

func _process(delta: float) -> void:
	if is_defeated or Global.in_battle:
		return
	
	if not is_frozen:
		# Simple patrol AI
		global_position += patrol_direction * move_speed * delta
		
		# Flip sprite based on direction
		if patrol_direction.x != 0:
			sprite.flip_h = patrol_direction.x < 0
		
		# Stay within patrol radius
		if global_position.distance_to(start_position) > patrol_radius:
			patrol_direction = (start_position - global_position).normalized()
		
		# Random direction changes (1% chance per frame)
		if randf() < 0.01:
			patrol_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_defeated and not Global.in_battle:
			on_clicked()

func on_clicked() -> void:
	print("[", enemy_name, "] clicked - Starting battle")
	start_battle()

func start_battle() -> void:
	Global.in_battle = true
	Global.current_enemy = self
	Global.battle_started.emit(self)
	
	# Freeze all enemies
	get_tree().call_group("enemies", "freeze")
	
	# Request question by difficulty
	request_question()

func freeze() -> void:
	is_frozen = true

func unfreeze() -> void:
	is_frozen = false

func request_question() -> void:
	print("=== REQUESTING QUESTION BY DIFFICULTY ===")
	
	var difficulty_names = ["easy", "medium", "hard", "boss"]
	var difficulty_str = difficulty_names[difficulty]
	
	print("Enemy: ", enemy_name, " | Difficulty: ", difficulty_str)
	
	var api_client = get_node_or_null("/root/APIClient")
	if not api_client:
		api_client = get_node_or_null("/root/GameManager/APIClient")
	
	if api_client:
		api_client.get_random_challenge_by_difficulty(difficulty_str)
	else:
		push_error("APIClient not found!")
		use_dummy_question(difficulty_str)

func use_dummy_question(difficulty_str: String) -> void:
	"""Fallback dummy questions"""
	var dummy_questions = {
		"easy": [
			{"id": "hello_world", "title": "Hello World", "question": "Print 'Hello, World!'", "hint": "Use cout"},
			{"id": "sum_two", "title": "Add Numbers", "question": "Add two integers", "hint": "Use +"}
		],
		"medium": [
			{"id": "reverse", "title": "Reverse String", "question": "Reverse a string", "hint": "Two pointers"},
			{"id": "factorial", "title": "Factorial", "question": "Calculate n!", "hint": "Loop or recursion"}
		]
	}
	
	var pool = dummy_questions.get(difficulty_str, dummy_questions["easy"])
	var template = pool[randi() % pool.size()]
	
	var dummy_question = {
		"id": template.id,
		"title": template.title,
		"question": template.question,
		"difficulty": difficulty_str,
		"hint": template.hint,
		"base_damage": 10 + (difficulty * 5),
		"base_xp": 100 + (difficulty * 50)
	}
	
	Global.question_received.emit(dummy_question)

func on_defeat() -> void:
	is_defeated = true
	Global.defeated_enemies.append(str(get_instance_id()))
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _on_battle_started(enemy: Node) -> void:
	if enemy != self:
		freeze()

func _on_battle_ended(victory: bool) -> void:
	if Global.current_enemy == self:
		if victory:
			on_defeat()
	else:
		unfreeze()
