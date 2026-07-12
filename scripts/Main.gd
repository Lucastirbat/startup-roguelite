extends Control

# Game loop: monthly tick -> draw -> render -> on button press apply effects,
# check deaths, honor next_card override, advance month.

const CHARACTERS := {
	"chad": {"name": "Chad — Head of Growth", "color": Color("c0392b"), "initial": "C", "portrait": "res://assets/graphics/chad.png"},
	"priya": {"name": "Priya — CTO", "color": Color("8e44ad"), "initial": "P", "portrait": "res://assets/graphics/pryia.png"},
	"doug": {"name": "Doug — VC", "color": Color("2c3e50"), "initial": "D", "portrait": "res://assets/graphics/Adam.png"},
	"linda": {"name": "Linda — Office Manager", "color": Color("27ae60"), "initial": "L", "portrait": "res://assets/graphics/Linda.png"},
	"angel": {"name": "The Angel", "color": Color("b7950b"), "initial": "A", "portrait": "res://assets/graphics/angel.png"},
	"mom": {"name": "Your Mom", "color": Color("c2185b"), "initial": "M", "portrait": "res://assets/graphics/Mom.png"},
	"claude": {"name": "Claude — AI Co-founder", "color": Color("d97757"), "initial": "AI", "portrait": "res://assets/graphics/claude.png"},
	"jeffrey": {"name": "Jeffrey Weinstein — Financier", "color": Color("9a7d0a"), "initial": "J", "portrait": "res://assets/graphics/jeffrey.png"},
	"fbi": {"name": "Special Agent Reyes — FBI", "color": Color("1a5276"), "initial": "FBI", "portrait": "res://assets/graphics/fbi.png"},
}

var deck: Deck
var card: Dictionary = {}
var pending_next := ""
var prev := {}  # previous stat values, for change flashes

@onready var valuation_label: Label = %ValuationLabel
@onready var month_label: Label = %MonthLabel
@onready var cash_label: Label = %CashLabel
@onready var morale_label: Label = %MoraleLabel
@onready var hype_label: Label = %HypeLabel
@onready var equity_label: Label = %EquityLabel
@onready var cash_box: PanelContainer = %CashBox
@onready var morale_box: PanelContainer = %MoraleBox
@onready var burn_label: Label = %BurnLabel
@onready var portrait_panel: Panel = %PortraitPanel
@onready var portrait_label: Label = %PortraitLabel
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var name_label: Label = %NameLabel
@onready var card_text: Label = %CardText
@onready var left_button: Button = %LeftButton
@onready var right_button: Button = %RightButton

func _ready() -> void:
	if GameState.stats.is_empty():
		GameState.reset()
	deck = Deck.new()
	left_button.pressed.connect(_choose.bind("left"))
	right_button.pressed.connect(_choose.bind("right"))
	_snapshot_stats()
	if GameState.month == 1:
		pending_next = "origin_cofounder"  # founding arc opens every run
	_start_month()

func _start_month() -> void:
	GameState.monthly_tick()
	_update_stats()
	var cause := GameState.check_death()
	if cause != "":
		_die(cause)
		return
	card = deck.draw(pending_next)
	pending_next = ""
	_render_card()

func _choose(side: String) -> void:
	Audio.play("click_left" if side == "left" else "click_right")
	var choice: Dictionary = card.get(side, {})
	GameState.apply_effects(choice.get("effects", {}))
	for f in _as_flag_list(choice.get("sets_flag", "")):
		GameState.add_flag(f)
	for f in _as_flag_list(choice.get("clears_flag", "")):
		GameState.remove_flag(f)
	pending_next = choice.get("next_card", "")
	_update_stats()
	if choice.get("arrest", false):
		GameState.death_cause = "arrested"
		_end_run()
		return
	if choice.get("exit", false):
		GameState.won = true
		GameState.exited = true
		_end_run()
		return
	var cause := GameState.check_death()
	if cause != "":
		_die(cause)
		return
	GameState.month += 1
	_start_month()

# The fatal stat pulses big and red for ~2s before the post-mortem, so the
# player sees WHAT killed them, not just that something did.
func _die(cause: String) -> void:
	GameState.death_cause = cause
	left_button.disabled = true
	right_button.disabled = true
	var box: PanelContainer = cash_box if cause == "cash" else morale_box
	box.pivot_offset = box.size / 2.0
	box.z_index = 10
	var tw := create_tween()
	for i in 3:
		tw.tween_property(box, "modulate", Color(1.0, 0.25, 0.25), 0.28)
		tw.parallel().tween_property(box, "scale", Vector2(1.4, 1.4), 0.28)
		tw.tween_property(box, "modulate", Color.WHITE, 0.28)
		tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.28)
	tw.tween_interval(0.4)
	tw.finished.connect(_end_run)

func _render_card() -> void:
	left_button.disabled = false
	right_button.disabled = false
	var who: Dictionary = CHARACTERS.get(card.get("character", "linda"), CHARACTERS["linda"])
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	var tex_path: String = who.get("portrait", "")
	if tex_path != "" and ResourceLoader.exists(tex_path):
		# Photo portrait inside a frame tinted with the character's color.
		portrait_texture.texture = load(tex_path)
		portrait_texture.visible = true
		portrait_label.visible = false
		style.bg_color = Color(0.1, 0.11, 0.14)
		style.border_color = who.color
		style.set_border_width_all(4)
	else:
		portrait_texture.visible = false
		portrait_label.visible = true
		style.bg_color = who.color
	portrait_panel.add_theme_stylebox_override("panel", style)
	portrait_label.text = who.initial
	name_label.text = who.name
	card_text.text = card.get("text", "")
	left_button.text = card.get("left", {}).get("label", "...")
	right_button.text = card.get("right", {}).get("label", "...")
	month_label.text = GameState.month_title()

func _update_stats() -> void:
	valuation_label.text = GameState.fmt_money(GameState.valuation)
	cash_label.text = GameState.fmt_money(int(GameState.stats.cash))
	var burn := GameState.current_burn()
	burn_label.text = ("-%s" % GameState.fmt_money(burn)) if burn > 0 else "$0"
	morale_label.text = "%d" % int(GameState.stats.morale)
	hype_label.text = "%d" % int(GameState.stats.hype)
	equity_label.text = "%d%%" % int(GameState.stats.equity)
	_flash("cash", cash_label)
	_flash("morale", morale_label)
	_flash("hype", hype_label)
	_flash("equity", equity_label)
	_snapshot_stats()

func _flash(key: String, label: Label) -> void:
	if not prev.has(key):
		return
	var delta := int(GameState.stats[key]) - int(prev[key])
	if delta == 0:
		return
	label.self_modulate = Color(0.4, 1.0, 0.4) if delta > 0 else Color(1.0, 0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(label, "self_modulate", Color.WHITE, 0.6)

func _snapshot_stats() -> void:
	prev = GameState.stats.duplicate()

func _end_run() -> void:
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

static func _as_flag_list(v) -> Array:
	if v is Array:
		return v
	return [v] if v != "" else []
