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

@onready var bg: ColorRect = %BG
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
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
		bg.color = Color(0.07, 0.13, 0.09)
		title_label.text = "EXIT!"
		body_label.text = _win_text()
		payout_label.text = "PAYOUT: %s" % GameState.fmt_money(payout)
	else:
		bg.color = Color(0.13, 0.07, 0.08)
		title_label.text = "STARTUP DIED"
		body_label.text = _death_text()
		payout_label.text = "PAYOUT: $0  (startups are illiquid)"
	GameState.submit_score(payout)
	high_score_label.text = "BEST EXIT: %s" % GameState.fmt_money(GameState.high_score)

func _win_text() -> String:
	var lines := []
	lines.append("You sold the company in Month %d." % GameState.month)
	lines.append("Final valuation: %s. You kept %d%% of it." %
		[GameState.fmt_money(GameState.valuation), int(GameState.stats.equity)])
	lines.append_array(_story_lines())
	return "\n".join(lines)

func _death_text() -> String:
	var lines := []
	lines.append("You died in Month %d." % GameState.month)
	match GameState.death_cause:
		"cash":
			lines.append("Cause of death: payroll. The money ran out.")
		"morale":
			lines.append("Cause of death: the whole team quit in the same Slack thread.")
	lines.append("")
	lines.append_array(_story_lines())
	lines.append("")
	lines.append("Paper valuation was %s. Your %d%% was worth %s — on paper." %
		[GameState.fmt_money(GameState.valuation), int(GameState.stats.equity),
		GameState.fmt_money(GameState.score())])
	return "\n".join(lines)

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
