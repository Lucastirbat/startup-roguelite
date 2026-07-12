extends SceneTree

# Headless sanity test for the balance changes. Run with:
# godot --headless --path . -s test_balance.gd

func _initialize() -> void:
	var gs = root.get_node("GameState")
	var failures := 0

	# Hype is clamped to 100.
	gs.reset()
	gs.apply_effects({"hype": 500})
	if gs.stats.hype != 100:
		printerr("FAIL: hype not clamped, got ", gs.stats.hype)
		failures += 1

	# High hype decays proportionally (100 -> -10).
	gs.stats.cash = 100000
	gs.monthly_tick()
	if gs.stats.hype != 90:
		printerr("FAIL: proportional decay, expected 90 got ", gs.stats.hype)
		failures += 1

	# Valuation drift is capped at +15%/month.
	gs.reset()
	gs.stats.cash = 100000
	gs.valuation = 100000
	gs.valuation_floor = 100000
	gs.stats.hype = 100
	gs.monthly_tick()  # hype decays to 90 first, still above cap threshold
	var expected := 100000 + int(100000 * 0.15) + (90 - 15) * 15
	if gs.valuation != expected:
		printerr("FAIL: drift cap, expected ", expected, " got ", gs.valuation)
		failures += 1

	# Term-sheet flags reduce the payout.
	gs.reset()
	gs.valuation = 100000
	gs.stats.equity = 50
	var base: int = gs.score()
	gs.add_flag("liq_pref")
	if gs.score() != int(base * 0.8):
		printerr("FAIL: liq_pref payout, got ", gs.score(), " want ", int(base * 0.8))
		failures += 1

	# Deck parses and the new cards exist.
	var deck = load("res://scripts/Deck.gd").new()
	if deck.cards.is_empty():
		printerr("FAIL: cards.json did not parse")
		failures += 1
	var want := ["angel_uncapped_safe", "safe_conversion", "angel_revenue_share",
		"rev_share_buyout", "fund_seed_party", "party_round_paperwork",
		"fund_seed_debt", "debt_covenant", "fund_a_preempt", "fund_a_pref",
		"fund_b_crossover", "fund_b_structured", "fund_c_sovereign", "fund_d_ratchet"]
	var ids := {}
	for c in deck.cards:
		ids[c.get("id", "")] = true
	for id in want:
		if not ids.has(id):
			printerr("FAIL: missing card ", id)
			failures += 1

	# Hidden island quest: all chapters exist, next_card refs resolve,
	# and the raid actually arrests you.
	var quest := ["jw_invite", "jw_island", "jw_shell", "jw_books",
		"jw_raid", "jw_subpoena", "jw_news"]
	for id in quest:
		if not ids.has(id):
			printerr("FAIL: missing quest card ", id)
			failures += 1
	for c in deck.cards:
		for side in ["left", "right"]:
			var next: String = c.get(side, {}).get("next_card", "")
			if next != "" and not ids.has(next):
				printerr("FAIL: ", c.get("id"), " points at missing card ", next)
				failures += 1
	var raid := {}
	for c in deck.cards:
		if c.get("id", "") == "jw_raid":
			raid = c
	if not (raid.get("left", {}).get("arrest", false) and raid.get("right", {}).get("arrest", false)):
		printerr("FAIL: jw_raid must arrest on both choices")
		failures += 1

	# Burn: venture debt and rev share raise it, seed trap counts as funded_seed.
	gs.reset()
	gs.month = 10
	gs.flags = ["venture_debt", "rev_share"]
	if gs.current_burn() != 25 + 30 + 15:
		printerr("FAIL: debt/revshare burn, got ", gs.current_burn())
		failures += 1

	print("PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
