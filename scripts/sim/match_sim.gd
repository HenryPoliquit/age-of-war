class_name MatchSim
extends RefCounted
## Deterministic, render-free simulation of one match (GDD §2–§9).
## The view and the balance harness both drive this class; neither adds rules of its own.
## Call `step()` once per `rules.tick_dt`. Commands (queue_unit, evolve, ...) are the only way
## players and AIs change state, and each returns false if the action is not allowed.

signal event_emitted(event: Dictionary)

const LEFT := 0
const RIGHT := 1
const DRAW := 2
const ROLES: Array[String] = ["vanguard", "ranged", "heavy", "siege"]
## Upgrade rows and the stats each offers (GDD §6.1). Unit rows are the four roles.
const UPGRADES := {
	"vanguard": ["attack", "health", "defence"],
	"ranged": ["attack", "health", "defence"],
	"heavy": ["attack", "health", "defence"],
	"siege": ["attack", "health", "defence"],
	"turret": ["attack", "health", "range"],
	"income": ["income"],
}

var data: GameData
var rules: RulesDef
var time: float = 0.0
var sides: Array[SimSide] = []
## -1 while running; LEFT / RIGHT when a base falls; DRAW on the time limit.
var winner: int = -1
var front_x: float
var escalation: int = 0
var rng := RandomNumberGenerator.new()
var match_log: MatchLog
## Pending skill pulses: {side, def, lo, hi, next_t, pulse, kills}
var effects: Array[Dictionary] = []
## Short-lived records for the view (hits, shots, deaths). Cleared by the consumer.
var fx: Array[Dictionary] = []
var record_fx := false

var _next_id := 1
var _log_accum := 0.0


func _init(p_data: GameData = null, p_seed: int = 1) -> void:
	data = p_data if p_data != null else GameData.get_default()
	rules = data.rules
	rng.seed = p_seed
	front_x = rules.lane_length * 0.5
	for i in 2:
		var s := SimSide.new()
		s.index = i
		s.gold = rules.start_gold
		s.turret_slots = rules.start_turret_slots
		s.base_max_hp = data.age(1).base_max_hp
		s.base_hp = s.base_max_hp
		sides.append(s)
	match_log = MatchLog.new()
	match_log.seed = p_seed


## Skirmish option (GDD §12.1): both sides start in `age`, with base HP and starting gold for that age.
## Call before the first step.
func set_start_age(age: int) -> void:
	age = clampi(age, 1, GameData.AGE_COUNT)
	for s in sides:
		s.age = age
		s.base_max_hp = data.age(age).base_max_hp
		s.base_hp = s.base_max_hp
		s.gold = rules.start_gold * rules.age_cost_mult(age)
		for a in range(1, age):
			s.age_times[a] = 0.0


# ---------------------------------------------------------------------------
# Coordinates

## World x of a progress value for a side (left gate = 0, right gate = lane_length).
func to_world(side: int, progress: float) -> float:
	return progress if side == LEFT else rules.lane_length - progress


func to_progress(side: int, world_x: float) -> float:
	return world_x if side == LEFT else rules.lane_length - world_x


func enemy_of(side: int) -> int:
	return 1 - side


func is_over() -> bool:
	return winner != -1


# ---------------------------------------------------------------------------
# Prices and availability (shared by the HUD and the AI)

func unit_price(_side: int, def: UnitDef) -> float:
	return float(def.cost)


func roster(side: int) -> Array[UnitDef]:
	return data.age(sides[side].age).units


func turret_roster(side: int) -> Array[TurretDef]:
	return data.age(sides[side].age).turrets


func evolve_cost(side: int) -> float:
	var s := sides[side]
	if s.age >= GameData.AGE_COUNT:
		return INF
	return float(data.age(s.age + 1).evolve_cost)


func slot_cost(side: int) -> float:
	var s := sides[side]
	if s.turret_slots >= max_turret_slots():
		return INF
	return roundf(rules.turret_slot_costs[s.turret_slots] * rules.age_cost_mult(s.age))



func upgrade_level(side: int, row: String, stat: String) -> int:
	return sides[side].upgrade_level(row, stat)


## Gold for the next level; INF when maxed, unknown, or the row has no unit this age (PLAN D22).
func upgrade_cost(side: int, row: String, stat: String) -> float:
	if not UPGRADES.has(row) or not stat in UPGRADES[row]:
		return INF
	var s := sides[side]
	var level := s.upgrade_level(row, stat)
	if row == "income":
		if level >= rules.income_upgrade_costs.size():
			return INF
		return roundf(rules.income_upgrade_costs[level] * rules.age_cost_mult(s.age))
	if level >= rules.upgrade_cost_factors.size():
		return INF
	var basis := 0.0
	if row == "turret":
		var roster := turret_roster(side)
		for t in roster:
			basis += t.cost
		basis /= maxf(1.0, roster.size())
	else:
		var def := data.unit_for_role(s.age, row)
		if def == null:
			return INF
		basis = unit_price(side, def)
	return roundf(rules.upgrade_cost_factors[level] * basis)


func can_buy_upgrade(side: int, row: String, stat: String) -> bool:
	return not is_over() and sides[side].gold >= upgrade_cost(side, row, stat)


## Multipliers from upgrades; `row` is a role or "turret". Read at damage/HP time so they apply to
## everything already fielded, whatever its age (PLAN D18).
func attack_mult(side: int, row: String) -> float:
	return 1.0 + rules.upgrade_attack_bonus * sides[side].upgrade_level(row, "attack")


func health_mult(side: int, row: String) -> float:
	return 1.0 + rules.upgrade_health_bonus * sides[side].upgrade_level(row, "health")


func defence_mult(side: int, role: String) -> float:
	return maxf(0.0, 1.0 - rules.upgrade_defence_bonus * sides[side].upgrade_level(role, "defence"))


func turret_range_mult(side: int) -> float:
	return 1.0 + rules.upgrade_range_bonus * sides[side].upgrade_level("turret", "range")


func max_turret_slots() -> int:
	return rules.turret_slot_costs.size()


func income_rate(side: int) -> float:
	var s := sides[side]
	return rules.base_income * rules.tide_multiplier_at(time) \
		* (1.0 + rules.income_upgrade_bonus * s.upgrade_level("income", "income")) * (1.0 + s.income_bonus)


func can_queue(side: int, def: UnitDef) -> bool:
	var s := sides[side]
	return not is_over() and def != null and def.age == s.age \
		and s.queue.size() < rules.queue_slots and s.gold >= unit_price(side, def)


func can_evolve(side: int) -> bool:
	var s := sides[side]
	return not is_over() and not s.is_evolving() and s.age < GameData.AGE_COUNT and s.xp >= evolve_cost(side)


func ability_def(side: int) -> AbilityDef:
	return data.age(sides[side].age).ability


func ability_cost(side: int) -> float:
	return float(ability_def(side).xp_cost)


## True when this side's current skill is aimed by the caster (`fire_ability` takes an aim point).
func ability_is_targeted(side: int) -> bool:
	return ability_def(side).is_targeted()


func can_fire_ability(side: int) -> bool:
	var s := sides[side]
	return not is_over() and s.ability_cooldown <= 0.0 and s.xp >= ability_cost(side)


# ---------------------------------------------------------------------------
# Commands

func queue_unit(side: int, def: UnitDef) -> bool:
	if not can_queue(side, def):
		return false
	var s := sides[side]
	var price := unit_price(side, def)
	s.gold -= price
	s.stat_gold_spent += price
	s.queue.append(def)
	s.queue_paid.append(price)
	return true


func queue_role(side: int, role: String) -> bool:
	return queue_unit(side, data.unit_for_role(sides[side].age, role))


func dequeue_last(side: int) -> bool:
	var s := sides[side]
	if s.queue.is_empty():
		return false
	s.queue.pop_back()
	var refund: float = s.queue_paid.pop_back()
	s.gold += refund
	s.stat_gold_spent -= refund
	if s.queue.is_empty():
		s.train_progress = 0.0
	return true


func evolve(side: int) -> bool:
	if not can_evolve(side):
		return false
	var s := sides[side]
	s.xp -= evolve_cost(side)
	s.evolve_left = rules.evolve_time
	_emit({"type": "evolve_start", "side": side, "to_age": s.age + 1})
	return true


func buy_upgrade(side: int, row: String, stat: String) -> bool:
	if not can_buy_upgrade(side, row, stat):
		return false
	var s := sides[side]
	var c := upgrade_cost(side, row, stat)
	var old_hp := health_mult(side, row)
	s.gold -= c
	s.stat_gold_spent += c
	s.set_upgrade_level(row, stat, s.upgrade_level(row, stat) + 1)
	if stat == "health":
		# Max HP rises for everything already fielded; current HP keeps its percentage (PLAN D19).
		var ratio := health_mult(side, row) / old_hp
		if row == "turret":
			for t in s.turrets:
				if t != null:
					t.max_hp *= ratio
					t.hp *= ratio
		else:
			for u in s.units:
				if u.def.role == row:
					u.max_hp *= ratio
					u.hp *= ratio
	_emit({"type": "upgrade", "side": side, "row": row, "stat": stat, "level": s.upgrade_level(row, stat)})
	return true


func unlock_slot(side: int) -> bool:
	var s := sides[side]
	var c := slot_cost(side)
	if is_over() or s.gold < c:
		return false
	s.gold -= c
	s.stat_gold_spent += c
	s.turret_slots += 1
	_emit({"type": "turret_slot", "side": side, "slots": s.turret_slots})
	return true


func build_turret(side: int, slot: int, def: TurretDef) -> bool:
	var s := sides[side]
	if is_over() or def == null or def.age != s.age or slot < 0 or slot >= s.turret_slots \
			or s.turrets[slot] != null or s.gold < def.cost:
		return false
	s.gold -= def.cost
	s.stat_gold_spent += def.cost
	var t := SimTurret.new()
	t.def = def
	t.slot = slot
	t.max_hp = def.hp * health_mult(side, "turret")
	t.hp = t.max_hp
	s.turrets[slot] = t
	_emit({"type": "turret_build", "side": side, "slot": slot, "turret": String(def.id)})
	return true


func sell_turret(side: int, slot: int) -> bool:
	var s := sides[side]
	if is_over() or slot < 0 or slot >= s.turrets.size() or s.turrets[slot] == null:
		return false
	var t: SimTurret = s.turrets[slot]
	var refund := roundf(t.def.cost * rules.sell_refund)
	s.gold += refund
	s.stat_gold_spent -= refund
	s.turrets[slot] = null
	_emit({"type": "turret_sell", "side": side, "slot": slot, "turret": String(t.def.id)})
	return true


func first_free_slot(side: int) -> int:
	var s := sides[side]
	for i in s.turret_slots:
		if s.turrets[i] == null:
			return i
	return -1


## Fires this side's current-era skill (PLAN D20). Auto skills land where their shape says; an aimed
## skill (`ability_is_targeted`) lands centred on `aim_x`, a world x, or on the densest enemy group when
## no aim is given. Fails, costing nothing, when no enemy unit would be inside the zone (D21).
func fire_ability(side: int, aim_x: float = NAN) -> bool:
	if not can_fire_ability(side):
		return false
	var zone := ability_zone(side, aim_x)
	if zone.is_empty() or _units_in_zone(enemy_of(side), zone).is_empty():
		return false
	var s := sides[side]
	var def := ability_def(side)
	s.xp -= def.xp_cost
	s.ability_cooldown = rules.ability_cooldown
	var center: float = (zone[0] + zone[1]) * 0.5
	effects.append({"side": side, "def": def, "lo": zone[0], "hi": zone[1], "next_t": time + def.telegraph, "pulse": 0,
		"kills": 0, "hit_ids": {}, "damage": 0.0})
	_emit({"type": "ability", "side": side, "ability": String(def.id), "x": center, "lo": zone[0], "hi": zone[1], "aimed": def.is_targeted()})
	return true


## [lo, hi] in world x where this side's skill would land now, or [] if no enemy unit is on the lane.
## `aim_x` only matters to aimed skills; without it they use `ability_default_aim`.
func ability_zone(side: int, aim_x: float = NAN) -> Array:
	var def := ability_def(side)
	var enemy := enemy_of(side)
	var front := _front_unit(enemy)
	if front == null:
		return []
	if def.is_targeted():
		var c := ability_default_aim(side) if is_nan(aim_x) else clampf(aim_x, 0.0, rules.lane_length)
		return [c - def.width * 0.5, c + def.width * 0.5]
	if def.shape == "sweep":
		return [0.0, rules.lane_length]
	var c := _densest_window(enemy, def.width)
	return [c - def.width * 0.5, c + def.width * 0.5]


## World x an aimed skill lands on when the caster gives no aim (the densest enemy group); NAN if the
## enemy has no unit on the lane. The AI aims with this, and a player's "let the game aim" press.
func ability_default_aim(side: int) -> float:
	if _front_unit(enemy_of(side)) == null:
		return NAN
	return _densest_window(enemy_of(side), ability_def(side).width)


## Living units of `of_side` inside a [lo, hi] world-x zone.
func _units_in_zone(of_side: int, zone: Array) -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u in sides[of_side].units:
		if not u.alive():
			continue
		var x := to_world(of_side, u.progress)
		if x >= zone[0] and x <= zone[1]:
			out.append(u)
	return out


## What firing at `aim_x` would hit right now: {zone, count, value} (value = gold paid for those units).
## For the aim reticle and the AI; the sim itself only reads the zone when the skill fires.
func ability_preview(side: int, aim_x: float = NAN) -> Dictionary:
	var zone := ability_zone(side, aim_x)
	if zone.is_empty():
		return {"zone": zone, "count": 0, "value": 0.0}
	var hit := _units_in_zone(enemy_of(side), zone)
	var v := 0.0
	for u in hit:
		v += u.cost_paid
	return {"zone": zone, "count": hit.size(), "value": v}


## Gold value of the enemy units inside this side's skill zone right now.
func ability_zone_value(side: int, aim_x: float = NAN) -> float:
	return ability_preview(side, aim_x).value


## Centre of the `width` window holding the most gold of `of_side`'s units. Candidate windows start or
## end at a unit; the first best window in unit order wins ties (deterministic). The result is re-centred
## on the units inside the winning window, so the group sits in the middle of the zone, not on its edge.
func _densest_window(of_side: int, width: float) -> float:
	var best := NAN
	var best_v := -1.0
	var best_lo := 0.0
	var best_hi := 0.0
	for u in sides[of_side].units:
		var start := to_world(of_side, u.progress)
		for c in [start + width * 0.5, start - width * 0.5]:
			var v := 0.0
			var lo := INF
			var hi := -INF
			for w in sides[of_side].units:
				var x := to_world(of_side, w.progress)
				if w.alive() and absf(x - c) <= width * 0.5:
					v += w.cost_paid
					lo = minf(lo, x)
					hi = maxf(hi, x)
			if v > best_v:
				best_v = v
				best = c
				best_lo = lo
				best_hi = hi
	return best if is_nan(best) or is_inf(best_lo) else (best_lo + best_hi) * 0.5


# ---------------------------------------------------------------------------
# Simulation step

func step() -> void:
	if is_over():
		return
	var dt := rules.tick_dt
	time += dt
	escalation = rules.escalation_stacks_at(time)
	for s in sides:
		_economy(s, dt)
		_evolution(s, dt)
		_training(s, dt)
		s.ability_cooldown = maxf(0.0, s.ability_cooldown - dt)
	_apply_auras()
	# Both sides act on the same snapshot of fronts so neither side moves first.
	var fronts := [_front_unit(LEFT), _front_unit(RIGHT)]
	for s in sides:
		_units_act(s, fronts[enemy_of(s.index)], dt)
	for s in sides:
		_turrets_act(s, dt)
	_resolve_effects()
	_remove_dead()
	_update_front()
	_check_end()
	_log_accum += dt
	if _log_accum >= 1.0 - 1e-6:
		_log_accum = 0.0
		match_log.sample(self)


func _economy(s: SimSide, dt: float) -> void:
	var g := income_rate(s.index) * dt
	s.gold += g
	s.stat_gold_earned += g


func _evolution(s: SimSide, dt: float) -> void:
	if s.evolve_left <= 0.0:
		return
	s.evolve_left -= dt
	if s.evolve_left <= 1e-6:
		s.evolve_left = 0.0
		var pct := s.base_hp / s.base_max_hp
		s.age += 1
		s.base_max_hp = data.age(s.age).base_max_hp
		s.base_hp = s.base_max_hp * pct
		s.age_times[s.age - 1] = time
		_emit({"type": "evolve", "side": s.index, "age": s.age})


func _training(s: SimSide, dt: float) -> void:
	if s.queue.is_empty() or s.is_evolving():
		return
	s.train_progress += dt
	var def: UnitDef = s.queue[0]
	if s.train_progress + 1e-6 < def.train_time or s.units.size() >= rules.field_cap:
		return
	# Don't spawn into an ally still standing in the gate.
	if not s.units.is_empty() and s.units[-1].progress < rules.unit_spacing:
		return
	s.train_progress = 0.0
	s.queue.pop_front()
	var paid: float = s.queue_paid.pop_front()
	_spawn(s, def, paid)


func _spawn(s: SimSide, def: UnitDef, paid: float) -> SimUnit:
	var u := SimUnit.new()
	u.id = _next_id
	_next_id += 1
	u.side = s.index
	u.def = def
	u.age = def.age
	u.cost_paid = paid
	u.max_hp = def.hp * health_mult(s.index, def.role)
	u.hp = u.max_hp
	u.base_damage = def.damage
	s.units.append(u)
	match_log.count_spawn(s.index, def, paid)
	return u


func _front_unit(side: int) -> SimUnit:
	var best: SimUnit = null
	for u in sides[side].units:
		if u.alive() and (best == null or u.progress > best.progress + 1e-6):
			best = u
	return best


func _apply_auras() -> void:
	for s in sides:
		for u in s.units:
			u.slow = 0.0
	for s in sides:
		for t in s.turrets:
			if t == null or t.def.kind != "support":
				continue
			for u in sides[enemy_of(s.index)].units:
				if rules.lane_length - u.progress <= t.def.aura_radius * turret_range_mult(s.index):
					u.slow = maxf(u.slow, t.def.aura_slow)


func _units_act(s: SimSide, enemy_front: SimUnit, dt: float) -> void:
	var lane := rules.lane_length
	var enemy := sides[enemy_of(s.index)]
	var ahead: SimUnit = null
	for u in s.units:
		if not u.alive():
			continue
		u.cooldown = maxf(0.0, u.cooldown - dt)
		var dist_unit := INF
		if enemy_front != null and enemy_front.alive():
			dist_unit = lane - u.progress - enemy_front.progress
		var dist_struct := lane - u.progress
		var def := u.def
		var target_unit: SimUnit = null
		var target_struct := false
		if def.is_ranged_siege():
			if dist_struct <= def.range:
				target_struct = true
			elif dist_unit <= def.range and dist_unit >= def.min_range:
				target_unit = enemy_front
		elif dist_unit <= def.range:
			target_unit = enemy_front
		elif dist_struct <= def.range:
			target_struct = true
		var attacking := target_unit != null or target_struct
		if attacking:
			u.state = &"attack"
			if u.cooldown <= 0.0:
				u.cooldown = def.attack_interval
				u.last_attack_time = time
				if record_fx:
					var to_x := to_world(enemy.index, target_unit.progress) if target_unit != null else to_world(enemy.index, 0.0)
					fx.append({"type": "shot", "side": u.side, "unit": u, "def": def, "from_x": to_world(u.side, u.progress),
						"to_x": to_x, "structure": target_unit == null, "target": target_unit})
				if target_unit != null:
					_hit_unit(u, target_unit, u.base_damage * attack_mult(u.side, def.role), def.damage_type)
				else:
					_hit_structures(u, enemy)
		# Melee presses in to contact distance while fighting so the allies behind it come into reach;
		# ranged units hold at their range.
		var melee := def.range <= rules.melee_range_max and not def.is_ranged_siege()
		if not attacking or melee:
			# Movement is code-driven; blocked by the ally ahead and the nearest enemy.
			var limit := lane - rules.melee_contact
			if ahead != null:
				limit = minf(limit, ahead.progress - rules.unit_spacing)
			if enemy_front != null and enemy_front.alive():
				limit = minf(limit, lane - enemy_front.progress - rules.melee_contact)
			var target_p := u.progress + def.speed * (1.0 - u.slow) * dt
			var new_p := maxf(u.progress, minf(target_p, limit))
			if not attacking:
				u.state = &"walk" if new_p > u.progress + 1e-4 else &"idle"
			u.progress = new_p
		ahead = u


func _hit_unit(attacker: SimUnit, target: SimUnit, raw: float, dtype: String) -> void:
	var dealt := _damage_unit(target, raw, dtype, attacker.side)
	attacker.stat_damage_dealt += dealt
	match_log.count_damage(attacker.side, attacker.def, dealt)


## Applies matrix + buffs; returns damage actually dealt. Kill rewards go to `by_side`.
## `true_damage` skips the armour matrix and the Defence upgrades (true and percent skills).
func _damage_unit(target: SimUnit, raw: float, dtype: String, by_side: int, true_damage := false) -> float:
	if not target.alive():
		return 0.0
	var dmg := raw if true_damage else raw * rules.matrix(dtype, target.def.armour) * defence_mult(target.side, target.def.role)
	dmg = minf(dmg, target.hp)
	target.hp -= dmg
	target.stat_damage_taken += dmg
	target.last_hit_time = time
	match_log.count_absorbed(target.side, target.def, dmg)
	if record_fx:
		fx.append({"type": "hit", "x": to_world(target.side, target.progress), "dtype": dtype, "side": target.side})
	if target.hp <= 0.0:
		_on_kill(target, by_side)
	return dmg


func _on_kill(victim: SimUnit, by_side: int) -> void:
	var s := sides[by_side]
	match_log.count_death(victim.progress, rules.lane_length, victim.cost_paid)
	var bounty := victim.cost_paid * rules.bounty_fraction
	s.gold += bounty
	s.stat_gold_earned += bounty
	s.xp += victim.cost_paid * rules.xp_per_kill_fraction
	s.stat_xp_earned += victim.cost_paid * rules.xp_per_kill_fraction
	if record_fx:
		fx.append({"type": "death", "x": to_world(victim.side, victim.progress), "side": victim.side, "role": victim.def.role,
			"def": victim.def, "unit_id": victim.id})


func _hit_structures(u: SimUnit, enemy: SimSide) -> void:
	var raw := u.base_damage * attack_mult(u.side, u.def.role) * rules.matrix(u.def.damage_type, "structure")
	raw *= 1.0 + rules.escalation_structure_bonus * escalation
	# Any unit at the gate knocks out turrets (lowest slot first) before the base; the matrix makes
	# Siege the structure-breaker (spec §2.3, superseding PLAN D3).
	for t in enemy.turrets:
		if t != null and t.alive():
			var dmg := minf(raw, t.hp)
			t.hp -= dmg
			u.stat_damage_dealt += dmg
			match_log.count_damage(u.side, u.def, dmg)
			if t.hp <= 0.0:
				enemy.turrets[t.slot] = null
				_emit({"type": "turret_destroyed", "side": enemy.index, "slot": t.slot, "turret": String(t.def.id)})
			if record_fx:
				fx.append({"type": "hit", "x": to_world(enemy.index, 0.0), "dtype": u.def.damage_type, "side": enemy.index, "structure": true})
			return
	u.stat_damage_dealt += minf(raw, enemy.base_hp)
	match_log.count_damage(u.side, u.def, minf(raw, enemy.base_hp))
	damage_base(enemy, raw, u.side)


func damage_base(s: SimSide, raw: float, by_side: int) -> void:
	var dmg := minf(raw, s.base_hp)
	if dmg <= 0.0:
		return
	s.base_hp -= dmg
	s.last_base_hit_time = time
	var attacker := sides[by_side]
	attacker.xp += dmg * rules.xp_per_base_damage
	attacker.stat_xp_earned += dmg * rules.xp_per_base_damage
	match_log.count_base_damage(by_side, dmg)
	if record_fx:
		fx.append({"type": "hit", "x": to_world(s.index, 0.0), "dtype": "siege", "side": s.index, "structure": true})


func _turrets_act(s: SimSide, dt: float) -> void:
	var enemy := sides[enemy_of(s.index)]
	var lane := rules.lane_length
	for t in s.turrets:
		if t == null or t.def.kind == "support":
			continue
		t.cooldown = maxf(0.0, t.cooldown - dt)
		if t.cooldown > 0.0:
			continue
		var mult := 1.0 - rules.escalation_turret_penalty * escalation
		var raw: float = t.def.damage * mult * attack_mult(s.index, "turret")
		var reach: float = t.def.range * turret_range_mult(s.index)
		if t.def.kind == "sentry":
			# Enemy unit closest to our base = the most advanced enemy.
			var target := _front_unit(enemy.index)
			if target != null and lane - target.progress <= reach:
				t.cooldown = t.def.attack_interval
				t.last_fire_time = time
				t.last_target_x = to_world(enemy.index, target.progress)
				if record_fx:
					fx.append({"type": "turret_shot", "side": s.index, "slot": t.slot, "def": t.def, "to_x": t.last_target_x, "target": target if t.def.kind == "sentry" else null})
				t.stat_damage_dealt += _damage_unit(target, raw, t.def.damage_type, s.index)
		elif t.def.kind == "artillery":
			var best: SimUnit = null
			var best_count := 0
			for u in enemy.units:
				var d := lane - u.progress
				if not u.alive() or d < t.def.min_range or d > reach:
					continue
				var count := 0
				for v in enemy.units:
					if v.alive() and absf(v.progress - u.progress) <= t.def.splash:
						count += 1
				if count > best_count or (count == best_count and best != null and u.id < best.id):
					best = u
					best_count = count
			if best != null:
				t.cooldown = t.def.attack_interval
				t.last_fire_time = time
				t.last_target_x = to_world(enemy.index, best.progress)
				if record_fx:
					fx.append({"type": "turret_shot", "side": s.index, "slot": t.slot, "def": t.def, "to_x": t.last_target_x, "target": null})
				var center := best.progress
				for v in enemy.units:
					if v.alive() and absf(v.progress - center) <= t.def.splash:
						t.stat_damage_dealt += _damage_unit(v, raw, t.def.damage_type, s.index)


func _update_front() -> void:
	var lf := _front_unit(LEFT)
	var rf := _front_unit(RIGHT)
	var lane := rules.lane_length
	if lf == null and rf == null:
		return
	if lf == null:
		front_x = 0.0
	elif rf == null:
		front_x = lane
	else:
		front_x = (lf.progress + lane - rf.progress) * 0.5


func _resolve_effects() -> void:
	var keep: Array[Dictionary] = []
	for e in effects:
		var def: AbilityDef = e.def
		while e.next_t <= time + 1e-6 and e.pulse < def.pulses:
			_ability_pulse(e)
			e.pulse += 1
			e.next_t += def.pulse_interval
		if e.pulse < def.pulses:
			keep.append(e)
		else:
			_emit({"type": "ability_end", "side": e.side, "ability": String(def.id), "kills": e.kills, "hits": e.hit_ids.size(),
				"damage": snappedf(e.damage, 0.1)})
	effects = keep


func _ability_pulse(e: Dictionary) -> void:
	var def: AbilityDef = e.def
	var lo: float = e.lo
	var hi: float = e.hi
	if def.shape == "sweep" and def.pulses > 1:
		# Sweeps travel away from the caster, one slice per pulse.
		var slice := (hi - lo) / def.pulses
		var i: int = e.pulse if e.side == LEFT else def.pulses - 1 - e.pulse
		lo = e.lo + slice * i
		hi = lo + slice
	var target_side := enemy_of(e.side)
	if record_fx:
		fx.append({"type": "ability_pulse", "lo": lo, "hi": hi, "side": e.side, "ability": String(def.id), "pulse": e.pulse, "pulses": def.pulses})
	for u in _units_in_zone(target_side, [lo, hi]):
		var raw := def.damage
		if def.damage_mode == "percent":
			raw = def.damage_pct * u.max_hp
		var x := to_world(u.side, u.progress)
		var dealt := _damage_unit(u, raw, def.damage_type, e.side, def.ignores_armour())
		e.hit_ids[u.id] = true
		e.damage += dealt
		var killed := not u.alive()
		if killed:
			e.kills += 1
		else:
			if def.knockback > 0.0:
				u.progress = maxf(0.0, u.progress - def.knockback)
		if record_fx:
			fx.append({"type": "skill_hit", "x": x, "side": target_side, "dealt": dealt, "killed": killed, "mode": def.damage_mode,
				"pct": def.damage_pct, "ability": String(def.id), "unit_id": u.id, "def": u.def})
	match_log.count_ability_damage(e.side)


func _remove_dead() -> void:
	for s in sides:
		var alive: Array[SimUnit] = []
		for u in s.units:
			if u.alive():
				alive.append(u)
		s.units = alive


func _check_end() -> void:
	var l_dead := sides[LEFT].base_hp <= 0.0
	var r_dead := sides[RIGHT].base_hp <= 0.0
	if l_dead or r_dead:
		winner = DRAW if l_dead and r_dead else (RIGHT if l_dead else LEFT)
	elif time >= rules.match_time_limit - 1e-6:
		winner = DRAW
	if winner != -1:
		match_log.sample(self)
		_emit({"type": "match_end", "winner": winner})


func _emit(ev: Dictionary) -> void:
	ev["t"] = snappedf(time, 0.01)
	match_log.events.append(ev)
	event_emitted.emit(ev)
