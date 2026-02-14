extends Node

enum EnemyDifficulty {
	EASY,
	MEDIUM,
	HARD,
	EXPERT,
	LEGENDARY
}

# Game State
var current_area: String = "area_1"
var player_position: Vector2 = Vector2.ZERO
var defeated_enemies: Array = []

# Battle Start
var in_battle: bool = false
var current_enemy: Node = null
var current_question: Dictionary = {}

# API Setting
var api_base_url: String = "http://127.0.0.1:8000"

# Signals
signal battle_started(enemy)
signal battle_ended(victory: bool)
signal question_received(question_Data)

signal code_submitted(code:String)

func _ready():
	print("Global manager initialized")
	print("API base URL: ", api_base_url)
	
func save_game():
	var save_data = {
	"current_area": current_area,
	"player_position": {"x": player_position.x, "y": player_position.y},
	"defeated_enemies": defeated_enemies
	}
	
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	
func load_game():
	if not FileAccess.file_exists("user://savegame.json"):
		return
		
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	var json = JSON.new()
	
	json.parse(file.get_as_text())
	var save_data = json.get_data()
	
	file.close()
	current_area = save_data.get("current_area", "area_1")
	var pos = save_data.get("player_position", {})
	player_position = Vector2(pos.get("x", 0), pos.get("y", 0))
	defeated_enemies = save_data.get("defeated_enemies", [])
