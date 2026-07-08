extends Control

# Post-mortem / win screen. Flags double as the story log.

const FLAG_STORIES := {
	"chad_annoyed": "Chad was annoyed.",
	"fired_chad": "You fired Chad. He joined the competition.",
	"tech_debt": "Priya warned you about the duct tape. Twice.",
	"paid_debt": "You let Priya fix the duct tape. Wise.",
	"blamed_aws": "You blamed AWS for your own outage. AWS noticed.",
	"lowballed_dev": "You lowballed a brilliant engineer.",
	"took_moms_money": "You took your mom's savings.",
	"overpromised": "You promised AI features that did not exist.",
	"layoffs": "The layoffs were 'a hard decision'.",
	"priya_burned": "You let Priya burn out.",
	"priya_gone": "Priya left. The servers miss her.",
	"priya_stayed": "Priya stayed. It cost you equity and a four-day week.",
	"new_cto": "You hired a rockstar CTO. He keynotes a lot.",
	"intern_cto": "You made the intern CTO. The intern made history.",
	"passed_seed": "You turned down a seed round to 'keep grinding'.",
	"desperate": "You got desperate. Everyone could tell.",
	"went_bigger": "You turned down $30M because you were 'going bigger'.",
	"funded_angel": "You took money from a man who says 'jib'.",
	"funded_seed": "You raised a seed round.",
	"funded_a": "You raised a Series A. The board had opinions.",
	"funded_b": "You raised a Series B. Someone bought chairs.",
	"funded_c": "You raised a Series C. The deck said 'category-defining' six times.",
	"funded_d": "You raised a Series D at a $1B post. The ice sculpture melted on schedule.",
	"funded_growth": "You took the mega-fund's $300M. The spiral was never explained.",
	"hired_coo": "You hired a COO with 'operational rigor'. He had it.",
	"sold_secondary": "You sold 3% in a secondary. The house is real. The rest was paper.",
	"acquired_rival": "You bought your rival. Their codebase was 'spirited', as advertised.",
	"ipo_track": "You filed the S-1. Everyone learned your salary.",
	"held_out": "You turned down a $4B IPO to go bigger. Nerves of something.",
	"going_public": "You turned down $2.5B in cash because bells exist.",
	"vibe_coder": "You let the vibe coder cook. The checkout flow wrote poems.",
	"support_bot": "You replaced support with a bot. It made promises.",
	"sold_data": "You sold your users to an AI lab as 'the corpus'.",
	"rigged_benchmark": "You published Chad's benchmark. Chad wrote Chad's benchmark.",
	"ai_first": "You went 'AI-first'. The support team became a system prompt.",
	"option_pooled": "You did not read the option pool paragraph.",
	"board_tension": "You told the board you were the adult.",
	"pivoted": "You pivoted to the screenshot thing.",
	"crypto_money": "You took the crypto money, ser.",
	"covered_breach": "You covered up a security breach.",
	"db_risk": "The database held. Until it didn't.",
	"fake_users": "You didn't ask where the 50K users came from.",
	"open_sourced": "You open-sourced the core. A cloud giant said thanks.",
	"has_cofounder": "You split the company with a co-founder. 65/35.",
	"solo": "You did it alone. Well — alone with Claude.",
	"cofounder_rift": "The co-founder fight never really healed.",
	"day_job": "You never quit the day job. Doug noticed.",
	"garage": "It started in a garage. Some of it is still there.",
	"full_remote": "You went full remote. The office plants were not consulted.",
	"lean_ops": "You cut the kombucha. It was time.",
	"lean_infra": "You deleted 'staging-final-2'. Nothing broke. Probably.",
	"migrated_db": "You migrated the database before it exploded. Nobody noticed. That was the point.",
}

const COL_GOOD := "#4be38a"
const COL_BAD := "#f05a5a"
const COL_GOLD := "#f2c40f"
const COL_DIM := "#8a90a0"

@onready var bg: ColorRect = %BG
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var payout_label: Label = %PayoutLabel
@onready var high_score_label: Label = %HighScoreLabel
@onready var restart_button: Button = %RestartButton

func _ready() -> void:
	restart_button.pressed.connect(_on_restart)
	Audio.play("win" if GameState.won else "lose")
	restart_button.text = "Start Game" if GameState.won else "Try Again"
	# Grace period so a stray card-click doesn't instantly restart the run.
	restart_button.disabled = true
	get_tree().create_timer(2.0).timeout.connect(
		func(): restart_button.disabled = false)
	var payout := 0
	if GameState.won:
		payout = GameState.score()
		_tint_bg(Color(0.05, 0.09, 0.07), Color(0.07, 0.16, 0.11), Color(0.29, 0.89, 0.54))
		title_label.text = "EXIT!"
		title_label.add_theme_color_override("font_color", Color(0.29, 0.89, 0.54))
		subtitle_label.text = "THE WIRE CLEARED. IT'S REAL."
		body_label.text = _win_text()
		payout_label.text = "PAYOUT: %s" % GameState.fmt_money(payout)
		payout_label.add_theme_color_override("font_color", Color(0.95, 0.77, 0.06))
	else:
		_tint_bg(Color(0.09, 0.05, 0.06), Color(0.16, 0.07, 0.09), Color(0.94, 0.35, 0.35))
		title_label.text = "STARTUP DIED"
		title_label.add_theme_color_override("font_color", Color(0.94, 0.35, 0.35))
		subtitle_label.text = "POST-MORTEM"
		body_label.text = _death_text()
		payout_label.text = "PAYOUT: $0"
	GameState.submit_score(payout)
	high_score_label.text = "BEST EXIT: %s" % GameState.fmt_money(GameState.high_score)

# Material is resource_local_to_scene, so this only tints this screen.
func _tint_bg(base: Color, glow: Color, accent: Color) -> void:
	var mat: ShaderMaterial = bg.material
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("glow_color", glow)
	mat.set_shader_parameter("accent_color", accent)

func _win_text() -> String:
	var text := "[center][b]You sold the company in Month %d.[/b]\n" % GameState.month
	text += "Final valuation: [color=%s]%s[/color]. You kept [color=%s]%d%%[/color] of it.[/center]" % [
		COL_GOOD, GameState.fmt_money(GameState.valuation),
		COL_GOLD, int(GameState.stats.equity)]
	return text + _story_bbcode()

func _death_text() -> String:
	var text := "[center][b]You died in Month %d.[/b]\n" % GameState.month
	match GameState.death_cause:
		"cash":
			text += "[color=%s]Cause of death: payroll. The money ran out.[/color]" % COL_BAD
		"morale":
			text += "[color=%s]Cause of death: the whole team quit in the same Slack thread.[/color]" % COL_BAD
	text += "[/center]"
	text += _story_bbcode()
	text += "\n\n[center][color=%s]Paper valuation was %s. Your %d%% was worth %s — on paper.[/color][/center]" % [
		COL_DIM, GameState.fmt_money(GameState.valuation),
		int(GameState.stats.equity), GameState.fmt_money(GameState.score())]
	return text

# Cap the log so it fits without scrolling; keep the most recent chapters.
const MAX_STORY_LINES := 8

func _story_bbcode() -> String:
	var lines := _story_lines()
	if lines.is_empty():
		return ""
	if lines.size() > MAX_STORY_LINES:
		lines = lines.slice(lines.size() - MAX_STORY_LINES)
	var out := "\n\n[center][color=%s]— HOW IT WENT —[/color][/center]\n" % COL_DIM
	for line in lines:
		out += "\n[color=%s]-[/color]  %s" % [COL_DIM, line]
	return out

# Some flags are set by different characters depending on the run:
# solo runs get Claude flavor instead of Priya.
const SOLO_STORIES := {
	"tech_debt": "Claude prepared a 14-step refactor plan. You ignored it.",
	"paid_debt": "You approved Claude's 14-step refactor. All three apologies included.",
	"blamed_aws": "You blamed AWS for a bug Claude wrote. AWS noticed.",
}

func _story_lines() -> Array:
	var lines := []
	var solo: bool = GameState.flags.has("solo")
	for flag in GameState.flags:
		if solo and SOLO_STORIES.has(flag):
			lines.append(SOLO_STORIES[flag])
		elif FLAG_STORIES.has(flag):
			lines.append(FLAG_STORIES[flag])
	return lines

func _on_restart() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
