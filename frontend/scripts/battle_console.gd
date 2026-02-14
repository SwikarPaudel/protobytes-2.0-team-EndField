extends Control

# Components
@onready var question_label: Label = $Panel/VBoxContainer/QuestionLabel
@onready var code_input: TextEdit = $Panel/VBoxContainer/CodeInput
@onready var submit_button: Button = $Panel/VBoxContainer/ButtonContainer/SubmitButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonContainer/CancelButton
@onready var panel: Panel = $Panel

# State
var current_question: Dictionary = {}

func _ready():
	hide()
	
	# Connect signals
	Global.question_received.connect(_on_question_received)
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Setup code editor appearance
	setup_code_editor_style()
	
	# Setup syntax highlighting
	code_input.syntax_highlighter = CodeHighlighter.new()
	setup_syntax_highlighting()

func setup_code_editor_style():
	"""Configure TextEdit appearance"""
	
	# Load custom font (if you have one)
	var custom_font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	code_input.add_theme_font_override("font", custom_font)
	
	# Font size
	code_input.add_theme_font_size_override("font_size", 16)
	
	# Line spacing
	code_input.add_theme_constant_override("line_spacing", 4)
	
	# Colors
	code_input.add_theme_color_override("background_color", Color(0.12, 0.12, 0.12))  # Dark background
	code_input.add_theme_color_override("font_color", Color(0.83, 0.83, 0.83))  # Light text
	code_input.add_theme_color_override("caret_color", Color(1.0, 1.0, 1.0))  # White cursor
	code_input.add_theme_color_override("selection_color", Color(0.3, 0.5, 0.8, 0.4))  # Blue selection
	code_input.add_theme_color_override("current_line_color", Color(0.2, 0.2, 0.2, 0.5))  # Highlight current line
	
	# Scrolling
	code_input.scroll_smooth = true
	code_input.scroll_v_scroll_speed = 80

func setup_syntax_highlighting():
	var highlighter = code_input.syntax_highlighter as CodeHighlighter
	
	# ── C++ Keywords ────────────────────────────────────────
	var keywords = [
		# Control flow
		"if", "else", "switch", "case", "default", "break",
		"for", "while", "do", "continue", "return",
		
		# Types
		"int", "float", "double", "char", "bool", "void",
		"string", "auto", "long", "short", "unsigned", "signed",
		
		# OOP
		"class", "struct", "public", "private", "protected",
		"virtual", "override", "this", "new", "delete",
		
		# STL
		"vector", "map", "set", "unordered_map", "pair",
		"string", "queue", "stack", "priority_queue",
		
		# Other
		"const", "static", "inline", "extern", "typedef",
		"using", "namespace", "template", "typename",
		"true", "false", "nullptr", "NULL",
		
		# Preprocessor
		"include", "define", "ifdef", "ifndef", "endif"
	]
	
	for keyword in keywords:
		highlighter.add_keyword_color(keyword, Color(0.86, 0.47, 0.95))  # Purple (VSCode-like)
	
	# ── Special Keywords (different color) ─────────────────
	var control_keywords = ["return", "break", "continue"]
	for keyword in control_keywords:
		highlighter.add_keyword_color(keyword, Color(0.8, 0.47, 0.95))  # Lighter purple
	
	# ── Types (different color) ────────────────────────────
	var types = ["int", "float", "double", "char", "bool", "void", "string", "auto"]
	for type in types:
		highlighter.add_keyword_color(type, Color(0.34, 0.61, 0.84))  # Blue
	
	# ── Numbers ─────────────────────────────────────────────
	highlighter.number_color = Color(0.71, 0.81, 0.66)  # Light green
	
	# ── Strings ─────────────────────────────────────────────
	highlighter.add_color_region('"', '"', Color(0.81, 0.57, 0.47), false)  # Orange
	highlighter.add_color_region("'", "'", Color(0.81, 0.57, 0.47), false)
	
	# ── Comments ────────────────────────────────────────────
	highlighter.add_color_region("//", "", Color(0.42, 0.60, 0.33), true)  # Green
	highlighter.add_color_region("/*", "*/", Color(0.42, 0.60, 0.33), false)
	
	# ── Preprocessor ────────────────────────────────────────
	highlighter.add_color_region("#", "", Color(0.64, 0.51, 0.78), true)  # Light purple
	
	# ── Function Color ──────────────────────────────────────
	highlighter.function_color = Color(0.86, 0.86, 0.67)  # Yellow
	
	# ── Member Variables ────────────────────────────────────
	highlighter.member_variable_color = Color(0.59, 0.76, 0.95)  # Light blue
	
	# ── Symbols ─────────────────────────────────────────────
	highlighter.symbol_color = Color(0.83, 0.83, 0.83)  # Light gray

func _on_question_received(question_data: Dictionary) -> void:
	current_question = question_data
	
	# Format the question display
	var title = question_data.get("title", "Challenge")
	var description = question_data.get("question", "No description")
	var difficulty = question_data.get("difficulty", "easy")
	var hint = question_data.get("hint", "")
	var starter_code = question_data.get("starter_code", "")
	
	# Build display text
	var display_text = title + " (" + difficulty.to_upper() + ")\n\n"
	display_text += description
	if hint:
		display_text += "\n\nHint: " + hint
	
	question_label.text = display_text
	
	# Pre-fill code editor with starter code
	code_input.text = starter_code
	
	# Show console
	show_console()

func show_console() -> void:
	show()
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	code_input.grab_focus()

func hide_console() -> void:
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hide)

func _on_submit_pressed() -> void:
	var code = code_input.text
	if code.strip_edges().is_empty():
		show_error("Please write some code!")
		return
	
	# Send code to API for validation
	var api_client = get_node_or_null("/root/APIClient")
	if not api_client:
		# Try alternate path if not using AutoLoad
		api_client = get_node_or_null("/root/GameManager/APIClient")
	
	if api_client:
		api_client.submit_code(current_question.get("id", ""), code)
	else:
		push_error("APIClient not found!")
		show_error("Error: Cannot connect to API")

func _on_cancel_pressed() -> void:
	# End battle without victory
	end_battle(false)

func end_battle(victory: bool) -> void:
	hide_console()
	Global.in_battle = false
	Global.battle_ended.emit(victory)
	Global.current_enemy = null

func show_error(message: String) -> void:
	# Show temporary error message
	var error_label = Label.new()
	error_label.text = message
	error_label.modulate = Color(1.0, 0.3, 0.3)
	error_label.position = Vector2(10, panel.size.y - 100)
	panel.add_child(error_label)
	
	# Auto-remove after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(error_label):
		error_label.queue_free()

func show_victory(damage: int, xp: int) -> void:
	# Show victory message
	var victory_text = "[color=green][b]SUCCESS![/b][/color]\n"
	victory_text += "Damage Dealt: " + str(damage) + "\n"
	victory_text += "XP Earned: " + str(xp)
	
	var victory_label = Label.new()
	victory_label.text = victory_text
	victory_label.position = Vector2(10, 10)
	victory_label.add_theme_color_override("font_color", Color(0, 1, 0))
	panel.add_child(victory_label)
	
	# Remove after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(victory_label):
		victory_label.queue_free()
