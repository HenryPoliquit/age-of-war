class_name SkillAim
extends RefCounted
## The player's aim mode for an aimed skill (GDD §7, §10). Auto skills fire on one press; an aimed skill
## opens aim mode, the cursor shows where it would land, and a click on the lane fires it. Everything
## goes through MatchSim commands, exactly like the AI's, so this holds no rules of its own.

var sim: MatchSim
var side := 0
var active := false
## World x under the cursor while aiming; NAN when the cursor is not over the battlefield or lane map.
var cursor_x := NAN


func _init(p_sim: MatchSim, p_side := 0) -> void:
	sim = p_sim
	side = p_side


## The Skill button. An auto skill fires; an aimed one enters aim mode, and pressing again cancels it.
## False means "not now" (no XP, cooldown, nothing to hit): the caller plays the error cue.
func press() -> bool:
	if active:
		cancel()
		return true
	if not can_start():
		return false
	if sim.ability_is_targeted(side):
		active = true
		cursor_x = NAN  # the view reports the cursor on its next frame
		return true
	return sim.fire_ability(side)


## Space: like the button, but a second press while aiming fires at the spot the game would pick.
func hotkey() -> bool:
	return auto_aim() if active else press()


func can_start() -> bool:
	return sim.can_fire_ability(side) and not sim.ability_zone(side).is_empty()


## Fires the aimed skill at world x (a click on the lane or the lane map). A click that would hit nothing
## fails and keeps aiming, so a stray click costs nothing; if the skill became unavailable, aiming ends.
func confirm(x: float) -> bool:
	if not active:
		return false
	if sim.fire_ability(side, x):
		cancel()
		return true
	tick()
	return false


## Fires at the densest enemy group instead of an aimed spot.
func auto_aim() -> bool:
	if not active:
		return false
	cancel()
	return sim.fire_ability(side)


func cancel() -> void:
	active = false
	cursor_x = NAN


## Once a frame: leave aim mode when the skill can no longer be aimed (XP spent elsewhere, era changed,
## enemy wiped out).
func tick() -> void:
	if active and not (sim.ability_is_targeted(side) and can_start()):
		cancel()


## What a click at the cursor would hit ({zone, count, value}), or {} when not aiming or off the field.
func preview() -> Dictionary:
	if not active or is_nan(cursor_x):
		return {}
	return sim.ability_preview(side, cursor_x)
