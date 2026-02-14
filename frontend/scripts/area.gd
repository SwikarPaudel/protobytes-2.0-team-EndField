extends Node2D

@export var area_name: String = "Base Area"
@export var enemy_count: int = 5
@export var spawn_area_min: Vector2 = Vector2(-350, -100)
@export var spawn_area_max: Vector2 = Vector2(230, 250)
@export var min_enemy_distance: float = 150.0  # Minimum distance between enemies

# Enemy scene
var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

# Difficulty-based names
var difficulty_names_map = {
	0: ["Skeleton Scout", "Bone Grunt", "Skull Minion"],        # EASY
	1: ["Skeleton Warrior", "Bone Knight", "Dark Skeleton"],    # MEDIUM
	2: ["Skeleton Champion", "Death Knight", "Lich Guard"],     # HARD
	3: ["Bone Lord", "Skeleton King", "Death Overlord"]         # BOSS
}

# Track spawned positions
var spawned_positions: Array[Vector2] = []

func _ready():
	spawn_enemies()
	setup_transitions()
	setup_lighting()
	setup_atmosphere()

func spawn_enemies():
	spawned_positions.clear()
	var successful_spawns = 0
	
	for i in range(enemy_count):
		var enemy = enemy_scene.instantiate()
		
		# Randomly pick difficulty (weighted toward easier)
		var diff = pick_weighted_difficulty()
		enemy.difficulty = diff
		
		# Pick random name from difficulty pool
		var name_pool = difficulty_names_map.get(diff, ["Unknown Enemy"])
		enemy.enemy_name = name_pool[randi() % name_pool.size()]
		
		# Find non-overlapping position
		var spawn_pos = find_non_overlapping_position()
		if spawn_pos == Vector2.ZERO:
			print("Warning: Could not find spawn position for enemy ", i)
			enemy.queue_free()
			continue
		
		enemy.global_position = spawn_pos
		spawned_positions.append(spawn_pos)
		
		add_child(enemy)
		successful_spawns += 1
	
	print("[%s] Spawned %d/%d enemies successfully" % [area_name, successful_spawns, enemy_count])

func pick_weighted_difficulty() -> int:
	"""Pick difficulty with weighting (more easy, fewer hard)"""
	var rand_val = randf()
	
	# 60% easy, 30% medium, 8% hard, 2% boss
	if rand_val < 0.6:
		return 0  # EASY
	elif rand_val < 0.9:
		return 1  # MEDIUM
	elif rand_val < 0.98:
		return 2  # HARD
	else:
		return 3  # BOSS

func find_non_overlapping_position(max_attempts: int = 20) -> Vector2:
	"""Find a position that doesn't overlap with existing enemies"""
	for attempt in range(max_attempts):
		# Random position in spawn area
		var candidate = Vector2(
			randf_range(spawn_area_min.x, spawn_area_max.x),
			randf_range(spawn_area_min.y, spawn_area_max.y)
		)
		
		# Check distance to all spawned enemies
		var too_close = false
		for pos in spawned_positions:
			if candidate.distance_to(pos) < min_enemy_distance:
				too_close = true
				break
		
		if not too_close:
			return candidate
	
	# Failed to find position after max attempts
	return Vector2.ZERO

func setup_atmosphere():
	var canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color(1.0, 0.95, 0.9)  # Warm white
	add_child(canvas_mod)

func setup_lighting():
	# Ambient light
	var ambient = PointLight2D.new()
	ambient.energy = 0.4
	ambient.texture_scale = 15.0
	ambient.color = Color(0.9, 0.9, 1.0)
	ambient.blend_mode = PointLight2D.BLEND_MODE_ADD
	add_child(ambient)
	
	# Torch lights
	var torch_positions = [
		Vector2(100, 100),
		Vector2(300, 100),
		Vector2(500, 200),
	]
	
	for pos in torch_positions:
		var torch = PointLight2D.new()
		torch.position = pos
		torch.energy = 2.0
		torch.texture_scale = 4.0
		torch.color = Color(1.0, 0.7, 0.3)
		torch.blend_mode = PointLight2D.BLEND_MODE_ADD
		add_child(torch)
		create_torch_flicker_tween(torch)

func create_torch_flicker_tween(light: PointLight2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(light, "energy", 1.7, 0.3)
	tween.tween_property(light, "energy", 2.2, 0.3)
	tween.tween_property(light, "energy", 1.8, 0.4)
	tween.tween_property(light, "energy", 2.1, 0.5)
	tween.tween_property(light, "energy", 2.0, 0.3)

func setup_transitions():
	var transitions_node = get_node_or_null("AreaTransitions")
	if not transitions_node:
		transitions_node = get_node_or_null("AreaTransition")
	if not transitions_node:
		print("Warning: No AreaTransitions node found")
		return
	
	var transitions = transitions_node.get_children()
	for transition in transitions:
		if transition is Area2D:
			transition.body_entered.connect(_on_transition_entered.bind(transition))

func _on_transition_entered(body: Node, transition: Area2D):
	if body.is_in_group("player"):
		var target_area = transition.get_meta("target_area", "")
		if target_area:
			transition_to_area(target_area)

func transition_to_area(target_name: String):
	Global.current_area = target_name
	get_tree().change_scene_to_file("res://scenes/areas/" + target_name + ".tscn")
