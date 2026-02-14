extends Node2D

@export var area_name: String = "Dark Cavern"
@export var enemy_count: int = 5
@export var spawn_area_min: Vector2 = Vector2(-350, -100)
@export var spawn_area_max: Vector2 = Vector2(230, 250)

# Enemy scene to instantiate
var enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")

# Difficulty-based names
var difficulty_names_map = {
	0: ["Skeleton Scout", "Bone Grunt", "Skull Minion"],        # EASY
	1: ["Skeleton Warrior", "Bone Knight", "Dark Skeleton"],    # MEDIUM
}

func _ready():
	spawn_enemies()
	setup_transitions()
	setup_lighting()

func setup_lighting():
	var light = PointLight2D.new()
	light.energy = 1.5
	light.texture_scale = 3.0
	light.color = Color(1.0, 0.9, 0.7)  # Warm white
	add_child(light)
	
func spawn_enemies():
	for i in range(enemy_count):
		var enemy = enemy_scene.instantiate()
		
		# Randomly pick EASY (0) or MEDIUM (1)
		var diff = randi() % 2
		enemy.difficulty = diff
		
		# Pick a random name from the difficulty pool
		var name_pool = difficulty_names_map[diff]
		enemy.enemy_name = name_pool[randi() % name_pool.size()]
		
		# Random position within spawn bounds
		var rand_x = randf_range(spawn_area_min.x, spawn_area_max.x)
		var rand_y = randf_range(spawn_area_min.y, spawn_area_max.y)
		enemy.global_position = Vector2(rand_x, rand_y)
		
		add_child(enemy)
	
	print("[%s] Spawned %d enemies with random EASY/MEDIUM difficulty" % [area_name, enemy_count])
		
func setup_transitions():
	var transitions_node = get_node_or_null("AreaTransitions")
	if not transitions_node:
		transitions_node = get_node_or_null("AreaTransition")
	if not transitions_node:
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
