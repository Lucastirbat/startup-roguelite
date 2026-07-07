class_name Deck
extends RefCounted

# Loads cards.json, draw() = filter by requires -> weighted pick -> pop if once.

const CARDS_PATH := "res://data/cards.json"

const FALLBACK_CARD := {
	"id": "quiet_month",
	"character": "linda",
	"text": "A quiet month. Nothing explodes. Suspicious.",
	"left": {"label": "Enjoy it", "effects": {"morale": 5}},
	"right": {"label": "Stay paranoid", "effects": {"hype": 2}},
}

# A character with any of these flags set is not around: their cards stop
# appearing, unless a card explicitly requires that flag (aftermath cards).
# "solo" blocks Priya entirely — she only exists if she co-founded.
const GONE_FLAGS := {
	"chad": ["fired_chad"],
	"priya": ["priya_gone", "solo"],
}
const RECENT_LIMIT := 8  # don't repeat a card within this many draws

var cards: Array = []
var used := {}       # ids of consumed once-cards
var recent: Array = []

func _init() -> void:
	var text := FileAccess.get_file_as_string(CARDS_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		cards = parsed
	else:
		push_error("cards.json failed to parse")

func draw(forced_id := "") -> Dictionary:
	if forced_id != "":
		for c in cards:
			if c.get("id", "") == forced_id:
				_mark(c)
				return c
	var pool := _build_pool(true)
	if pool.is_empty():
		pool = _build_pool(false)  # relax the cooldown before giving up
	if pool.is_empty():
		return FALLBACK_CARD
	var card := _weighted_pick(pool)
	_mark(card)
	return card

func _build_pool(use_cooldown: bool) -> Array:
	var out := []
	for c in cards:
		if used.has(c.get("id", "")):
			continue
		if use_cooldown and recent.has(c.get("id", "")):
			continue
		if _character_gone(c):
			continue
		if not _requires_met(c):
			continue
		out.append(c)
	return out

func _character_gone(c: Dictionary) -> bool:
	var r: Dictionary = c.get("requires", {})
	for gone in GONE_FLAGS.get(c.get("character", ""), []):
		if not GameState.flags.has(gone):
			continue
		# Aftermath cards that require the departure flag may still star them.
		if r.get("flag", "") == gone or (r.get("flags", []) as Array).has(gone):
			continue
		return true
	return false

func _requires_met(c: Dictionary) -> bool:
	var r: Dictionary = c.get("requires", {})
	var s: Dictionary = GameState.stats
	if GameState.valuation < int(r.get("min_valuation", 0)):
		return false
	if GameState.month < int(r.get("min_month", 0)):
		return false
	if GameState.month > int(r.get("max_month", 9999)):
		return false
	if int(s.cash) > int(r.get("max_cash", 9999999)):
		return false
	if int(s.morale) > int(r.get("max_morale", 999)):
		return false
	if int(s.hype) < int(r.get("min_hype", 0)):
		return false
	if int(s.hype) > int(r.get("max_hype", 999)):
		return false
	var flag: String = r.get("flag", "")
	if flag != "" and not GameState.flags.has(flag):
		return false
	for f in r.get("flags", []):
		if not GameState.flags.has(f):
			return false
	var not_flag: String = r.get("not_flag", "")
	if not_flag != "" and GameState.flags.has(not_flag):
		return false
	for f in r.get("not_flags", []):
		if GameState.flags.has(f):
			return false
	return true

func _weighted_pick(pool: Array) -> Dictionary:
	var weights := []
	var total := 0
	for c in pool:
		var w := int(c.get("weight", 10))
		# Funding cards loom large when runway is short (< 4 months of burn).
		if c.get("funding", false) and int(GameState.stats.cash) < GameState.current_burn() * 4:
			w *= 6
		weights.append(w)
		total += w
	var roll := randi_range(1, total)
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0:
			return pool[i]
	return pool.back()

func _mark(c: Dictionary) -> void:
	if c.get("once", false):
		used[c.get("id", "")] = true
	recent.push_back(c.get("id", ""))
	if recent.size() > RECENT_LIMIT:
		recent.pop_front()
