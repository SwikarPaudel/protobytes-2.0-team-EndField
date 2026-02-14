extends Node

# HTTP client
var http_request: HTTPRequest  # ← Remove @onready
var pending_request_type: String = ""

func _ready():
	print("=== API CLIENT READY ===")
	
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Connect signal
	http_request.request_completed.connect(_on_request_completed)
	print("HTTPRequest created and signal connected")

# ── Get random challenge by difficulty ────────────────────────────
func get_random_challenge_by_difficulty(difficulty: String) -> void:
	print("=== API: GET RANDOM CHALLENGE ===")
	print("Difficulty: ", difficulty)
	print("URL: ", Global.api_base_url + "/challenge/random/" + difficulty)
	
	var url = Global.api_base_url + "/challenge/random/" + difficulty
	var headers = ["Content-Type: application/json"]
	
	pending_request_type = "challenge"
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		push_error("Failed to request random challenge: " + str(error))
		show_error("Failed to connect to server")
	else:
		print("Request sent successfully!")

# ── Get challenge by ID (old method - keep for compatibility) ─────
func get_challenge(challenge_id: String) -> void:
	print("=== API: GET CHALLENGE BY ID ===")
	print("Challenge ID: ", challenge_id)
	print("URL: ", Global.api_base_url + "/challenge/" + challenge_id)
	
	var url = Global.api_base_url + "/challenge/" + challenge_id
	var headers = ["Content-Type: application/json"]
	
	pending_request_type = "challenge"
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		push_error("Failed to send challenge request: " + str(error))
		show_error("Failed to connect to server")
	else:
		print("Request sent successfully!")

# ── Submit code for evaluation ─────────────────────────────────────
func submit_code(challenge_id: String, code: String) -> void:
	print("=== API: SUBMIT CODE ===")
	var url = Global.api_base_url + "/submit"
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"challenge_id": challenge_id,
		"code": code
	})
	
	pending_request_type = "submit"
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("Failed to send code submission: " + str(error))
		show_error("Failed to submit code")
	else:
		print("Code submission sent!")

# ── Get all challenges (optional - for menu/selection) ────────────
func get_all_challenges() -> void:
	var url = Global.api_base_url + "/challenges"
	var headers = ["Content-Type: application/json"]
	
	pending_request_type = "challenges_list"
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		push_error("Failed to fetch challenges list: " + str(error))

# ── Handle HTTP responses ──────────────────────────────────────────
func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	print("=== REQUEST COMPLETED ===")
	print("Result: ", result)
	print("Response code: ", response_code)
	print("Body length: ", body.size())
	
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("HTTP request failed: " + str(result))
		show_error("Network error occurred")
		return
	
	if response_code != 200:
		push_error("Server returned error: " + str(response_code))
		var error_body = body.get_string_from_utf8()
		print("Error response: ", error_body)
		show_error("Server error: " + str(response_code))
		return
	
	# Parse JSON response
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		push_error("Failed to parse JSON response")
		print("Raw body: ", body.get_string_from_utf8())
		show_error("Invalid server response")
		return
	
	var data = json.get_data()
	print("Parsed data successfully")
	
	# Route based on request type
	match pending_request_type:
		"challenge":
			handle_challenge_response(data)
		"submit":
			handle_submit_response(data)
		"challenges_list":
			handle_challenges_list_response(data)
		_:
			push_error("Unknown request type: " + pending_request_type)

# ── Handle challenge data ──────────────────────────────────────────
func handle_challenge_response(data: Dictionary) -> void:
	print("=== HANDLING CHALLENGE RESPONSE ===")
	
	# Get first hint from hints array
	var hints_array = data.get("hints", [])
	var hint = ""
	if hints_array.size() > 0:
		hint = hints_array[0]
	
	var question_data = {
		"id": data.get("id", ""),
		"title": data.get("title", "Challenge"),
		"question": data.get("description", "No description"),
		"difficulty": data.get("difficulty", "easy"),
		"hint": hint,
		"base_damage": data.get("base_damage", 10),
		"base_xp": data.get("xp_reward", 100),
		"starter_code": data.get("starter_code", ""),
		"test_cases": data.get("test_cases", [])
	}
	
	print("Challenge loaded: ", question_data.get("title"))
	
	# Store in Global
	Global.current_question = question_data
	
	# Emit signal to console
	Global.question_received.emit(question_data)

# ── Handle submit response ─────────────────────────────────────────
func handle_submit_response(data: Dictionary) -> void:
	print("=== HANDLING SUBMIT RESPONSE ===")
	
	var is_success = data.get("success", false)
	var compiled = data.get("compiled", false)
	var passed_count = data.get("passed_count", 0)
	var total_count = data.get("total_count", 0)
	var damage = data.get("damage", 0)
	var xp = data.get("xp_earned", 0)
	var compiler_output = data.get("compiler_output", "")
	var hint = data.get("hint", "")
	
	if not compiled:
		print("Compilation failed: ", compiler_output)
		show_error("Compilation Error:\n" + compiler_output)
		return
	
	if is_success and passed_count == total_count:
		print("All tests passed! Damage: ", damage, " XP: ", xp)
		
		# Trigger player attack animation
		trigger_player_attack()
		
		# Show victory
		get_battle_console().show_victory(damage, xp)
		
		# Wait a bit, then end battle
		await get_tree().create_timer(1.0).timeout
		get_battle_console().end_battle(true)
	else:
		var feedback = "Passed " + str(passed_count) + "/" + str(total_count) + " tests"
		if hint:
			feedback += "\nHint: " + hint
		if compiler_output:
			feedback += "\n\nOutput:\n" + compiler_output
		
		print("Tests failed: ", feedback)
		show_error(feedback)

func trigger_player_attack() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("play_attack_animation"):
		player.play_attack_animation()

# ── Handle challenges list (optional) ──────────────────────────────
func handle_challenges_list_response(data) -> void:
	print("Loaded ", data.size(), " challenges")

# ── Helper functions ───────────────────────────────────────────────
func show_error(message: String) -> void:
	var console = get_battle_console()
	if console:
		console.show_error(message)
	else:
		push_error("Battle console not found: " + message)

func get_battle_console():
	var console = get_node_or_null("/root/GameManager/CanvasLayer/BattleConsole")
	if not console:
		console = get_node_or_null("/root/Main/CanvasLayer/BattleConsole")
	return console
