class_name UtilityAI
extends RefCounted
## Utility AI (GDD §11.4). At each decision tick it scores candidate actions over the lane state
## with personality weights, and issues commands through MatchSim like a player would.
## The same class drives both sides in the balance harness.

var personality: AiPersonalityDef
var difficulty: AiDifficultyDef
var side: int
var rng := RandomNumberGenerator.new()
## Harness override: when true, doctrine picks are random instead of personality preferences.
var random_doctrines := false
## Harness override: doctrine ids to pick whenever offered (wins over everything else).
var forced_doctrines: Array = []

var _timer := 0.0
var _released_hold := false
var _pushing := false
var _staged_since := 0.0


func _init(p_personality: AiPersonalityDef, p_difficulty: AiDifficultyDef, p_side: int, p_seed: int = 1) -> void:
	personality = p_personality
	difficulty = p_difficulty
	side = p_side
	rng.seed = p_seed
	# Seeded stagger of the first decision: sides don't act on identical ticks, and seeds differ.
	_timer = rng.randf_range(0.0, p_difficulty.decision_interval)


static func make(data: GameData, personality_id: StringName, difficulty_id: StringName, p_side: int, p_seed: int = 1) -> UtilityAI:
	return UtilityAI.new(data.personalities[personality_id], data.difficulties[difficulty_id], p_side, p_seed)


func setup(sim: MatchSim) -> void:
	var s := sim.sides[side]
	s.income_bonus = difficulty.income_bonus
	s.controller_name = "%s (%s)" % [personality.display_name, difficulty.display_name]


func update(sim: MatchSim, dt: float) -> void:
	var s := sim.sides[side]
	# The AI "chooses instantly" (GDD §13.5), independent of its decision interval.
	if s.awaiting_doctrine:
		sim.choose_doctrine(side, _pick_doctrine(sim))
	_timer -= dt
	if _timer > 0.0:
		return
	_timer += difficulty.decision_interval
	_decide(sim)


# ---------------------------------------------------------------------------

func _decide(sim: MatchSim) -> void:
	var s := sim.sides[side]
	var pressure := _under_pressure(sim)
	_try_ability(sim)
	_spend_xp(sim, pressure)
	_manage_stance(sim, pressure)
	_spend_gold(sim, pressure)


func _pick_doctrine(sim: MatchSim) -> DoctrineDef:
	var s := sim.sides[side]
	var options := sim.data.age(s.age + 1).doctrine_options
	for d in options:
		if String(d.id) in forced_doctrines.map(func(x): return String(x)):
			return d
	if not random_doctrines:
		for pref in personality.doctrine_prefs:
			for d in options:
				if d.id == pref:
					return d
		# Nightmare counters the opponent's doctrines (GDD §11.1).
		if difficulty.counter_level >= 3:
			var enemy := sim.sides[sim.enemy_of(side)]
			if enemy.has_doctrine(&"bastion") or enemy.turret_count() >= 3:
				for d in options:
					if d.id == &"siegecraft":
						return d
	return options[rng.randi_range(0, options.size() - 1)]


## Enemy units near our gate, or our base hit recently.
func _under_pressure(sim: MatchSim) -> bool:
	var s := sim.sides[side]
	if sim.time - s.last_base_hit_time < 4.0:
		return true
	var enemy := sim.sides[sim.enemy_of(side)]
	for u in enemy.units:
		if sim.rules.lane_length - u.progress < 700.0:
			return true
	return false


func _spend_xp(sim: MatchSim, pressure: bool) -> void:
	var s := sim.sides[side]
	var ranks_wanted := 0
	match personality.age_plan:
		"fast":
			ranks_wanted = 0
		"strong":
			ranks_wanted = sim.rules.veterancy_fractions.size()
		_:
			ranks_wanted = personality.balanced_vet_ranks
	if s.age >= GameData.AGE_COUNT:
		ranks_wanted = sim.rules.veterancy_fractions.size()
	if s.vet_ranks < ranks_wanted:
		sim.buy_veterancy(side)
		return
	if not sim.can_evolve(side):
		return
	# Evolving under pressure is a gamble (5 s with a paused queue). Smarter AIs wait it out,
	# unless the enemy is already an age ahead.
	var enemy := sim.sides[sim.enemy_of(side)]
	if pressure and difficulty.counter_level >= 2 and personality.age_plan != "fast" \
			and enemy.age <= s.age and s.base_hp / s.base_max_hp > 0.25:
		return
	sim.evolve(side)


func _manage_stance(sim: MatchSim, pressure: bool) -> void:
	var s := sim.sides[side]
	if pressure:
		sim.set_stance(side, &"advance")
		_pushing = false
		return
	# Early massing (Rusher): hold near home until the first wave is big enough.
	if personality.uses_hold and not _released_hold:
		var threshold := sim.income_rate(side) * personality.hold_release_seconds
		if s.army_value() >= threshold:
			_released_hold = true
		else:
			sim.set_stance(side, &"hold", sim.to_world(side, sim.rules.lane_length * 0.35))
			return
	if personality.push_ratio <= 0.0 or s.units.is_empty():
		sim.set_stance(side, &"advance")
		return
	# Staged push (GDD §10 coordinated push): gather outside enemy turret range, then go together,
	# instead of trickling units into the gate one at a time.
	var lane := sim.rules.lane_length
	var enemy := sim.sides[sim.enemy_of(side)]
	var reach := 300.0
	var defence := 0.0
	for t in enemy.turrets:
		if t != null:
			reach = maxf(reach, t.def.range)
			defence += t.def.cost
	for u in enemy.units:
		if lane - u.progress < reach + 300.0 or u.progress < reach + 300.0:
			defence += u.cost_paid
	var staging := lane - reach - 80.0
	var front := 0.0
	for u in s.units:
		front = maxf(front, u.progress)
	var group := 0.0
	for u in s.units:
		if u.progress >= front - 450.0:
			group += u.cost_paid
	# Go for the kill: a weak base needs a smaller margin; and never wait at the staging line forever.
	var needed := defence * personality.push_ratio * lerpf(0.2, 1.0, enemy.base_hp / enemy.base_max_hp)
	if _pushing:
		# Keep pushing until the attacking group is spent.
		if group < needed * 0.3:
			_pushing = false
			_staged_since = sim.time
	elif group >= needed or sim.time - _staged_since > 30.0:
		_pushing = true
	if _pushing:
		sim.set_stance(side, &"advance")
	else:
		sim.set_stance(side, &"hold", sim.to_world(side, staging))


# ---------------------------------------------------------------------------
# Gold

func _spend_gold(sim: MatchSim, pressure: bool) -> void:
	var s := sim.sides[side]
	var income := sim.income_rate(side)
	var want := _structural_want(sim, pressure)
	var reserve := 0.0
	if not want.is_empty():
		if s.gold >= want.cost:
			_do_want(sim, want)
		# Only save for purchases that take a reasonable time to afford.
		elif want.cost - s.gold <= income * 30.0:
			reserve = want.cost
	# Keep a minimum army on the lane even while saving.
	var floor_value := income * 12.0
	var guard := 0
	while guard < sim.rules.queue_slots:
		guard += 1
		var ranked := _ranked_units(sim)
		if ranked.is_empty():
			break
		var def: UnitDef = ranked[0]
		var price := sim.unit_price(side, def)
		var army := s.army_value() + s.queued_value()
		if s.gold < price:
			# Don't hoard for an expensive pick while the lane is thin: take the best affordable one.
			var wait := (price - s.gold) / maxf(income, 0.01)
			if not (army < floor_value or pressure or wait > 8.0):
				break
			def = null
			for d in ranked.slice(1):
				if s.gold >= sim.unit_price(side, d):
					def = d
					break
			if def == null:
				break
			price = sim.unit_price(side, def)
		var saving := reserve > 0.0 and s.gold - price < reserve
		if saving and not pressure and army >= floor_value:
			break
		if s.queue.size() >= 2 and not pressure and s.units.size() + s.queue.size() >= sim.rules.field_cap:
			break
		if not sim.queue_unit(side, def):
			break


## Next non-unit purchase this personality wants: {kind, cost, ...} or {}.
func _structural_want(sim: MatchSim, pressure: bool) -> Dictionary:
	var s := sim.sides[side]
	var hp_frac := s.base_hp / s.base_max_hp
	var turret_time := sim.time >= personality.turret_after or hp_frac < personality.turret_panic_hp
	# Replace outclassed turrets (two or more ages old) first.
	for t in s.turrets:
		if t != null and t.def.age <= s.age - 2:
			var best := _best_turret(sim)
			if best != null:
				return {"kind": "replace", "slot": t.slot, "def": best, "cost": best.cost - roundf(t.def.cost * sim.rules.sell_refund)}
	if turret_time and s.turret_count() < personality.turret_target:
		var slot := sim.first_free_slot(side)
		if slot == -1:
			if s.turret_slots < s.max_turret_slots():
				return {"kind": "slot", "cost": sim.slot_cost(side)}
		else:
			var def := _best_turret(sim)
			if def != null:
				return {"kind": "turret", "slot": slot, "def": def, "cost": float(def.cost)}
	if s.forge_level < personality.forge_target and sim.time >= personality.forge_after + s.forge_level * 90.0 and not pressure:
		return {"kind": "forge", "cost": sim.forge_cost(side)}
	return {}


func _do_want(sim: MatchSim, want: Dictionary) -> void:
	match want.kind:
		"forge":
			sim.buy_forge(side)
		"slot":
			sim.unlock_slot(side)
		"turret":
			sim.build_turret(side, want.slot, want.def)
		"replace":
			sim.sell_turret(side, want.slot)
			sim.build_turret(side, want.slot, want.def)


func _best_turret(sim: MatchSim) -> TurretDef:
	var s := sim.sides[side]
	var roster := sim.turret_roster(side)
	var have_sentry := false
	var have_art := false
	for t in s.turrets:
		if t != null and t.def.age == s.age:
			have_sentry = have_sentry or t.def.kind == "sentry"
			have_art = have_art or t.def.kind == "artillery"
	var order: Array[String] = ["sentry", "artillery", "sentry", "support"]
	if have_sentry and not have_art:
		order = ["artillery", "sentry", "support"]
	for kind in order:
		for t in roster:
			if t.kind == kind:
				return t
	return null


## This side's unit options, best first.
func _ranked_units(sim: MatchSim) -> Array[UnitDef]:
	var s := sim.sides[side]
	var out: Array[UnitDef] = []
	if personality.spam_role != "":
		var d := sim.data.unit_for_role(s.age, personality.spam_role)
		# Siege spam has nothing to queue in Age 1; it falls back to Vanguards until Age 2.
		out.append(d if d != null else sim.data.unit_for_role(s.age, "vanguard"))
		return out
	var enemy := sim.sides[sim.enemy_of(side)]
	var weights := {}
	for role in MatchSim.ROLES:
		if sim.data.unit_for_role(s.age, role) != null:
			weights[role] = float(personality.role_mix.get(role, 0.0))
	# Siege is for structures: more when pushing or facing turrets, none when defending.
	if weights.has("siege"):
		var push := sim.to_progress(side, sim.front_x) > sim.rules.lane_length * 0.5
		var ahead := s.army_value() > enemy.army_value() * 1.5
		weights.siege = (weights.siege + (0.15 if ahead else 0.0)) * (1.0 + enemy.turret_count()) * (2.5 if push else 0.5)
	if difficulty.counter_level >= 1:
		_apply_counters(sim, weights)
	# Keep a screen: ranged and siege need something in front of them.
	var screen := 0.0
	var backline := 0.0
	for u in s.units:
		if u.def.role in ["vanguard", "heavy"]:
			screen += u.cost_paid
		else:
			backline += u.cost_paid
	for q in s.queue:
		if q.role in ["vanguard", "heavy"]:
			screen += q.cost
		else:
			backline += q.cost
	if backline > screen * 1.5 + 30.0:
		weights.vanguard = weights.get("vanguard", 0.0) * 3.0 + 0.5
	# Deficit-weighted choice: pick the role furthest below its target share of army value.
	var total := 0.0
	for r in weights:
		total += weights[r]
	if total <= 0.0:
		out.append(sim.data.unit_for_role(s.age, "vanguard"))
		return out
	var have := {}
	var have_total := 1.0
	for u in s.units:
		have[u.def.role] = have.get(u.def.role, 0.0) + u.cost_paid
		have_total += u.cost_paid
	for q in s.queue:
		have[q.role] = have.get(q.role, 0.0) + q.cost
		have_total += q.cost
	var scored := []
	for r in weights:
		var target: float = weights[r] / total
		var share: float = have.get(r, 0.0) / have_total
		var score := target - share
		# Seeded noise: Easy is erratic; everyone else varies slightly so sim runs aren't identical.
		score += rng.randf_range(-0.15, 0.15) if difficulty.counter_level == 0 else rng.randf_range(-0.03, 0.03)
		scored.append([score, r])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	for pair in scored:
		out.append(sim.data.unit_for_role(s.age, pair[1]))
	return out


func _apply_counters(sim: MatchSim, weights: Dictionary) -> void:
	var enemy := sim.sides[sim.enemy_of(side)]
	var by_role := {}
	var total := 0.0
	for u in enemy.units:
		by_role[u.def.role] = by_role.get(u.def.role, 0.0) + u.cost_paid
		total += u.cost_paid
	if total <= 0.0:
		return
	var table := personality.counter_table
	if difficulty.counter_level == 1:
		# Normal: react to the enemy's majority role.
		var majority := ""
		var mv := 0.0
		for r in by_role:
			if by_role[r] > mv:
				mv = by_role[r]
				majority = r
		var c: String = table.get(majority, "")
		if weights.has(c):
			weights[c] *= 1.8
		return
	# Hard+: shift the mix toward the counter of every enemy role, in proportion to its share.
	var wsum := 0.0
	for r in weights:
		wsum += weights[r]
	for r in by_role:
		var c: String = table.get(r, "")
		if weights.has(c):
			weights[c] += by_role[r] / total * personality.counter_strength * wsum


# ---------------------------------------------------------------------------
# Abilities

func _try_ability(sim: MatchSim) -> void:
	if not sim.can_fire_ability(side):
		return
	var s := sim.sides[side]
	var def := sim.data.age(s.age).ability
	if def.affects == "ally":
		# Shieldwall: cover our most engaged group, only when a fight is on.
		var enemy_front := sim._front_unit(sim.enemy_of(side))
		if enemy_front == null or s.units.is_empty():
			return
		var x := _best_window(sim, side, def.width, false)
		if not is_nan(x):
			sim.fire_ability(side, x)
		return
	var enemy_side := sim.enemy_of(side)
	if sim.sides[enemy_side].units.is_empty():
		return
	var x := NAN
	match difficulty.aim_level:
		0:
			var u := sim.sides[enemy_side].units[rng.randi_range(0, sim.sides[enemy_side].units.size() - 1)]
			x = sim.to_world(enemy_side, u.progress) + rng.randf_range(-def.width * 0.5, def.width * 0.5)
		1:
			x = _best_window(sim, enemy_side, def.width, false)
		_:
			x = _best_window(sim, enemy_side, def.width, true)
			# Timed: hold the ability for a worthwhile target unless under pressure.
			var value := _window_value(sim, enemy_side, x, def.width, true)
			if value < sim.income_rate(side) * 20.0 and not _under_pressure(sim):
				return
	if not is_nan(x):
		sim.fire_ability(side, x)


## Centre of the window of `width` holding the most units (or the most gold of units) of `of_side`.
func _best_window(sim: MatchSim, of_side: int, width: float, by_value: bool) -> float:
	var best := NAN
	var best_v := 0.0
	for u in sim.sides[of_side].units:
		var start := sim.to_world(of_side, u.progress)
		# Try windows that start at this unit, extending in both directions.
		for centre in [start + width * 0.5, start - width * 0.5]:
			var v := _window_value(sim, of_side, centre, width, by_value)
			if v > best_v:
				best_v = v
				best = centre
	return best


func _window_value(sim: MatchSim, of_side: int, centre: float, width: float, by_value: bool) -> float:
	if is_nan(centre):
		return 0.0
	var v := 0.0
	for u in sim.sides[of_side].units:
		if absf(sim.to_world(of_side, u.progress) - centre) <= width * 0.5:
			v += u.cost_paid if by_value else 1.0
	return v
