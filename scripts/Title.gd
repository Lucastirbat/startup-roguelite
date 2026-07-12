extends Control

const BOARD_ROWS := 5

@onready var high_score_label: Label = %HighScoreLabel
@onready var start_button: Button = %StartButton
@onready var board_label: RichTextLabel = %BoardLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	if GameState.high_score > 0:
		high_score_label.text = "BEST EXIT: %s" % GameState.fmt_money(GameState.high_score)
	else:
		high_score_label.text = "BEST EXIT: none. yet."
	Leaderboard.fetch_top(_render_board)

func _render_board(ok: bool, entries: Array) -> void:
	if not ok:
		board_label.text = "[center]leaderboard unreachable — exits happen offline too[/center]"
		return
	if entries.is_empty():
		board_label.text = "[center]no exits on the board yet. be the first.[/center]"
		return
	var out := "[center]"
	for i in mini(entries.size(), BOARD_ROWS):
		var e: Dictionary = entries[i]
		out += "%d. [b]%s[/b] — [color=#f2c40f]%s[/color] (month %d)\n" % [
			i + 1, str(e.get("name", "?")),
			GameState.fmt_money(int(e.get("score", 0))), int(e.get("month", 0))]
	board_label.text = out + "[/center]"

func _on_start() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
