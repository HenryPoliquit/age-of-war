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
## Pending ability pulses: {side, def, center, next_t, pulse, age}
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
		s.rally_progress = rules.lane_length * 0.35
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

func unit_price(side: int, def: UnitDef) -> float:
	var s := sides[side]
	var c := float(def.cost)
	for d in s.doctrines:
		c *= d.unit_cost_mult
		if def.role == "siege":
			c *= d.siege_cost_mult
	return roundf(c)


func roster(side: int) -> Array[UnitDef]:
	return data.age(sides[side].age).units


func turret_roster(side: int) -> Array[TurretDef]:
	return data.age(sides[side].age).turrets


func evolve_cost(side: int) -> float:
	var s := sides[side]
	if s.age >= GameData.AGE_COUNT:
		return INF
	return float(data.age(s.age + 1).evolve_cost)


func veterancy_cost(side: int) -> float:
	var s := sides[side]
	if s.vet_ranks >= rules.veterancy_fractions.size():
		return INF
	return roundf(rules.veterancy_fractions[s.vet_ranks] * data.age(s.age).veterancy_base_xp)


func forge_cost(side: int) -> float:
	var s := sides[side]
	if s.forge_level >= rules.forge_costs.size():
		return INF
	return roundf(rules.forge_costs[s.forge_level] * rules.age_cost_mult(s.age))


func slot_cost(side: int) -> float:
	var s := sides[side]
	if s.turret_slots >= s.max_turret_slots():
		return INF
	return roundf(rules.turret_slot_costs[s.turret_slots] * rules.age_cost_mult(s.age))


func income_rate(side: int) -> float:
	var s := sides[side]
	return rules.base_income * rules.tide_multiplier_at(time) \
		* (1.0 + rules.forge_income_bonus * s.forge_level) * (1.0 + s.income_bonus)


func can_queue(side: int, def: UnitDef) -> bool:
	var s := sides[side]
	return not is_over() and def != null and def.age == s.age \
		and s.queue.size() < rules.queue_slots and s.gold >= unit_price(side, def)


func can_evolve(side: int) -> bool:
	var s := sides[side]
	return not is_over() and not s.is_evolving() and s.age < GameData.AGE_COUNT and s.xp >= evolve_cost(side)


func can_buy_veterancy(side: int) -> bool:
	var s := sides[side]
	return not is_over() and not s.is_evolving() and s.xp >= veterancy_cost(side)


func can_fire_ability(side: int) -> bool:
	var s := sides[side]
	return not is_over() and s.momentum >= rules.ability_cost and s.ability_cooldown <= 0.0


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


func buy_veterancy(side: int) -> bool:
	if not can_buy_veterancy(side):
		return false
	var s := sides[side]
	s.xp -= veterancy_cost(side)
	var old_mult := 1.0 + rules.veterancy_bonus * s.vet_ranks
	s.vet_ranks += 1
	var ratio := (1.0 + rules.veterancy_bonus * s.vet_ranks) / old_mult
	for u in s.units:
		if u.age == s.age:
			u.vet_rank = s.vet_ranks
			u.max_hp *= ratio
			u.hp *= ratio
	_emit({"type": "veterancy", "side": side, "rank": s.vet_ranks, "age": s.age})
	return true


func buy_forge(side: int) -> bool:
	var s := sides[side]
	var c := forge_cost(side)
	if is_over() or s.gold < c:
		return false
	s.gold -= c
	s.stat_gold_spent += c
	s.forge_level += 1
	_emit({"type": "forge", "side": side, "level": s.forge_level})
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
	t.max_hp = def.hp
	t.hp = def.hp
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


func choose_doctrine(side: int, doctrine: DoctrineDef) -> bool:
	var s := sides[side]
	if not s.awaiting_doctrine or doctrine == null:
		return false
	if not doctrine in data.age(s.age + 1).doctrine_options:
		return false
	s.doctrines.append(doctrine)
	s.awaiting_doctrine = false
	_emit({"type": "doctrine", "side": side, "doctrine": String(doctrine.id)})
	return true


func set_stance(side: int, stance: StringName, rally_world_x: float = NAN) -> void:
	var s := sides[side]
	if stance != s.stance:
		_emit({"type": "stance", "side": side, "stance": String(stance)})
	s.stance = stance
	if not is_nan(rally_world_x):
		s.rally_progress = clampf(to_progress(side, rally_world_x), 0.0, rules.lane_length)


func fire_ability(side: int, world_x: float) -> bool:
	if not can_fire_ability(side):
		return false
	var s := sides[side]
	var def := data.age(s.age).ability
	s.momentum -= rules.ability_cost
	s.ability_cooldown = rules.ability_cooldown
	var center := clampf(world_x, 0.0, rules.lane_length)
	effects.append({"side": side, "def": def, "center": center, "next_t": time + def.telegraph, "pulse": 0})
	_emit({"type": "ability", "side": side, "ability": String(def.id), "x": center})
	return true


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
	_front_and_momentum(dt)
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
	if s.evolve_left <= 0.0 or s.awaiting_doctrine:
		return
	# The doctrine choice opens as the transition starts; its timer pauses until chosen (GDD §13.5).
	if s.evolve_left >= rules.evolve_time - 1e-6 and not data.age(s.age + 1).doctrine_options.is_empty() \
			and _doctrine_pending(s):
		s.awaiting_doctrine = true
		_emit({"type": "doctrine_offer", "side": s.index, "age": s.age + 1})
		return
	s.evolve_left -= dt
	if s.evolve_left <= 1e-6:
		s.evolve_left = 0.0
		var pct := s.base_hp / s.base_max_hp
		s.age += 1
		s.vet_ranks = 0
		s.base_max_hp = data.age(s.age).base_max_hp
		s.base_hp = s.base_max_hp * pct
		s.age_times[s.age - 1] = time
		_emit({"type": "evolve", "side": s.index, "age": s.age})


func _doctrine_pending(s: SimSide) -> bool:
	var options := data.age(s.age + 1).doctrine_options
	for d in s.doctrines:
		if d in options:
			return false
	return true


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
	var hp_mult := 1.0
	var dmg_mult := 1.0
	for d in s.doctrines:
		hp_mult *= d.unit_hp_mult
		dmg_mult *= d.unit_damage_mult
	u.vet_rank = s.vet_ranks if def.age == s.age else 0
	var vet := 1.0 + rules.veterancy_bonus * u.vet_rank
	u.max_hp = def.hp * hp_mult * vet
	u.hp = u.max_hp
	u.base_damage = def.damage * dmg_mult
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
				if rules.lane_length - u.progress <= t.def.aura_radius:
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
					_hit_unit(u, target_unit, u.base_damage * u.damage_mult(rules.veterancy_bonus), def.damage_type)
				else:
					_hit_structures(u, enemy)
		# Melee presses in to contact distance while fighting so the allies behind it come into reach;
		# ranged units hold at their range.
		var melee := def.range <= rules.melee_range_max and not def.is_ranged_siege()
		if not attacking or melee:
			# Movement is code-driven; blocked by the ally ahead, the nearest enemy and a Hold rally line.
			var limit := lane - rules.melee_contact
			if ahead != null:
				limit = minf(limit, ahead.progress - rules.unit_spacing)
			if enemy_front != null and enemy_front.alive():
				limit = minf(limit, lane - enemy_front.progress - rules.melee_contact)
			if s.stance == &"hold" and not attacking:
				limit = minf(limit, s.rally_progress)
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
func _damage_unit(target: SimUnit, raw: float, dtype: String, by_side: int) -> float:
	if not target.alive():
		return 0.0
	var dmg := raw * rules.matrix(dtype, target.def.armour)
	if target.armour_buff_until > time:
		dmg /= 1.0 + target.armour_buff
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
	var bounty := victim.cost_paid * rules.bounty_fraction
	s.gold += bounty
	s.stat_gold_earned += bounty
	s.xp += victim.cost_paid * rules.xp_per_kill_fraction
	s.stat_xp_earned += victim.cost_paid * rules.xp_per_kill_fraction
	s.momentum = minf(rules.momentum_cap, s.momentum + victim.def.momentum_on_kill)
	if record_fx:
		fx.append({"type": "death", "x": to_world(victim.side, victim.progress), "side": victim.side, "role": victim.def.role,
			"def": victim.def, "unit_id": victim.id})


func _hit_structures(u: SimUnit, enemy: SimSide) -> void:
	var own := sides[u.side]
	var raw := u.base_damage * u.damage_mult(rules.veterancy_bonus) * rules.matrix(u.def.damage_type, "structure")
	raw *= 1.0 + rules.escalation_structure_bonus * escalation
	if u.def.role == "siege":
		for d in own.doctrines:
			raw *= d.siege_structure_mult
		# Only Siege reaches turrets; it knocks them out before the base (PLAN D3).
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
	s.momentum = minf(rules.momentum_cap, s.momentum + dmg / s.base_max_hp * 100.0 * rules.momentum_per_base_pct)
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
		for d in s.doctrines:
			mult *= d.turret_damage_mult
		var raw: float = t.def.damage * mult
		if t.def.kind == "sentry":
			# Enemy unit closest to our base = the most advanced enemy.
			var target := _front_unit(enemy.index)
			if target != null and lane - target.progress <= t.def.range:
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
				if not u.alive() or d < t.def.min_range or d > t.def.range:
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
	effects = keep


func _ability_pulse(e: Dictionary) -> void:
	var def: AbilityDef = e.def
	var lo: float = e.center - def.width * 0.5
	var hi: float = e.center + def.width * 0.5
	if def.sweep and def.pulses > 1:
		var slice := def.width / def.pulses
		# Sweeps travel away from the caster, toward the enemy base.
		var i: int = e.pulse if e.side == LEFT else def.pulses - 1 - e.pulse
		lo = e.center - def.width * 0.5 + slice * i
		hi = lo + slice
	var target_side: int = e.side if def.affects == "ally" else enemy_of(e.side)
	if record_fx:
		fx.append({"type": "ability_pulse", "lo": lo, "hi": hi, "side": e.side, "ability": String(def.id)})
	for u in sides[target_side].units:
		if not u.alive():
			continue
		var x := to_world(u.side, u.progress)
		if x < lo or x > hi:
			continue
		if def.affects == "ally":
			u.armour_buff = def.armour_buff
			u.armour_buff_until = time + def.buff_duration
		else:
			_damage_unit(u, def.damage, def.damage_type, e.side)
			if def.knockback > 0.0 and u.alive():
				u.progress = maxf(0.0, u.progress - def.knockback)
	match_log.count_ability_damage(e.side)


func _remove_dead() -> void:
	for s in sides:
		var alive: Array[SimUnit] = []
		for u in s.units:
			if u.alive():
				alive.append(u)
		s.units = alive


func _front_and_momentum(dt: float) -> void:
	var lf := _front_unit(LEFT)
	var rf := _front_unit(RIGHT)
	var lane := rules.lane_length
	if lf != null or rf != null:
		var lx := lf.progress if lf != null else 0.0
		var rx := lane - rf.progress if rf != null else lane
		if lf == null:
			front_x = 0.0
		elif rf == null:
			front_x = lane
		else:
			front_x = (lx + rx) * 0.5
	var half := lane * 0.5
	if front_x > half + 1e-6:
		sides[LEFT].momentum = minf(rules.momentum_cap, sides[LEFT].momentum + rules.momentum_push_rate * dt)
	elif front_x < half - 1e-6:
		sides[RIGHT].momentum = minf(rules.momentum_cap, sides[RIGHT].momentum + rules.momentum_push_rate * dt)


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
