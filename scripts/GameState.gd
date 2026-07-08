extends Node

# Autoload: holds the run state, applies effects, saves the high score.

const SAVE_PATH := "user://save.cfg"
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
	"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const BASE_BURN := 25      # $K per month pre-funding, grows with each stage
const HYPE_DECAY := 3

var stats := {}            # cash ($K), morale, hype, equity (%)
var month := 1
var flags: Array = []
var valuation := 500       # $K, derived: ratchets on funding, drifts with hype
var valuation_floor := 500
var high_score := 0        # best payout in $K
var death_cause := ""      # "cash" | "morale" | "" if alive
var won := false
var exited := false        # sold the company via an exit card

func _ready() -> void:
	_load_save()
	reset()

func reset() -> void:
	stats = {"cash": 200, "morale": 60, "hype": 5, "equity": 100}
	month = 1
	flags = []
	valuation = 100
	valuation_floor = 100
	death_cause = ""
	won = false
	exited = false

# Bigger company, bigger payroll: each funding stage raises the burn,
# so the game gets harder the longer you refuse to exit. Lifestyle and
# ops flags pull it back down.
func current_burn() -> int:
	# Founding arc (months 1-4): two people and a laptop, not a payroll.
	# Ramen, hosting, and a domain name. The day job nearly covers it.
	if month <= 4:
		return 3 if flags.has("day_job") else 10
	var burn := BASE_BURN
	if flags.has("funded_angel"):
		burn += 25
	if flags.has("funded_seed") or flags.has("option_pooled"):
		burn += 50
	if flags.has("funded_a"):
		burn += 100
	if flags.has("funded_b"):
		burn += 250
	if flags.has("funded_c"):
		burn += 400
	if flags.has("funded_d"):
		burn += 900
	if flags.has("funded_growth"):
		burn += 2000
	if flags.has("day_job"):
		burn -= 25
	if flags.has("garage"):
		burn -= 10
	if flags.has("full_remote"):
		burn -= 15
	if flags.has("lean_ops"):
		burn -= 15
	if flags.has("lean_infra"):
		burn -= 10
	return maxi(burn, 10)

func monthly_tick() -> void:
	stats.cash -= current_burn()
	stats.hype = maxi(stats.hype - HYPE_DECAY, 0)
	# Hype drives valuation; the effect scales with company size so later
	# funding tiers stay reachable after a round ratchets the floor up.
	var drift_per_point := 25 + valuation / 100
	valuation = maxi(valuation + (stats.hype - 15) * drift_per_point, valuation_floor)

func apply_effects(effects: Dictionary) -> void:
	for key in effects:
		var v := int(effects[key])
		match key:
			"cash":
				stats.cash += v
			"morale":
				stats.morale = clampi(stats.morale + v, 0, 100)
			"hype":
				stats.hype = maxi(stats.hype + v, 0)
			"equity":
				stats.equity = clampi(stats.equity + v, 0, 100)
			"valuation":
				valuation += v
				valuation_floor = maxi(valuation_floor, valuation)
			"set_valuation":
				valuation = v
				valuation_floor = maxi(valuation_floor, v)

func add_flag(flag: String) -> void:
	if flag != "" and not flags.has(flag):
		flags.append(flag)

func remove_flag(flag: String) -> void:
	if flag != "":
		flags.erase(flag)

func check_death() -> String:
	if stats.cash <= 0:
		return "cash"
	if stats.morale <= 0:
		return "morale"
	return ""

# Score = Valuation x Equity%
func score() -> int:
	return int(valuation * stats.equity / 100.0)

func month_title() -> String:
	var year := (month - 1) / 12 + 1
	return "%s, Year %d  (Month %d)" % [MONTH_NAMES[(month - 1) % 12], year, month]

func submit_score(payout: int) -> void:
	if payout > high_score:
		high_score = payout
		_save()

static func fmt_money(k: int) -> String:
	if absi(k) >= 1000000:
		var b := k / 1000000.0
		if is_equal_approx(b, roundf(b)):
			return "$%dB" % int(roundf(b))
		return "$%.1fB" % b
	if absi(k) >= 1000:
		var m := k / 1000.0
		if is_equal_approx(m, roundf(m)):
			return "$%dM" % int(roundf(m))
		return "$%.1fM" % m
	return "$%dK" % k

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("meta", "high_score", 0))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "high_score", high_score)
	cfg.save(SAVE_PATH)
