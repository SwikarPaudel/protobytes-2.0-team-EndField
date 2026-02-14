extends Node
@onready var current_area_node: Node2D = $"Current Area"
@onready var player: CharacterBody2D = $Player
@onready var battle_console: Control = $CanvasLayer/BattleConsole
@onready var api_client: Node = $APIClient

func _ready():
	# Initialize game
	load_area(Global.current_area)
	
	# Position player
	if Global.player_position != Vector2.ZERO:
		player.global_position = Global.player_position
		
func load_area(area_name: String):
	# Clear current area
	if current_area_node.get_child_count() > 0:
		for child in current_area_node.get_children():
			child.queue_free()
			
	# Load new area
	var area_scene = load("res://scenes/areas/" + area_name + ".tscn")
	
	if area_scene:
		var area_instance = area_scene.instantiate()
		current_area_node.add_child(area_instance)
		
	else:
		push_error("Failed to load area: " + area_name)
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Save player position before quit
		Global.player_position = player.global_position
		get_tree().quit()
