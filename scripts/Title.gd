extends Control

@onready var high_score_label: Label = %HighScoreLabel
@onready var start_button: Button = %StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	if GameState.high_score > 0:
		high_score_label.text = "BEST EXIT: %s" % GameState.fmt_money(GameState.high_score)
	else:
		high_score_label.text = "BEST EXIT: none. yet."

func _on_start() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
