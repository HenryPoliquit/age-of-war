class_name DayNight
extends RefCounted
## Purely visual day/night cycle driven by match time. Nothing in the sim reads it.
## Each age keeps its signature lighting (GDD §4.1): the cycle modulates around it, strongest in
## the daylit ages and gentle in ages that are already stormy or nocturnal.

const PERIOD := 240.0
## Start mid-morning so a match opens in daylight.
const START_PHASE := 0.12
const STRENGTH := [0.9, 1.0, 0.85, 0.55, 0.7, 0.4]
const NIGHT := Color(0.42, 0.48, 0.74)
const DUSK := Color(1.0, 0.72, 0.52)

## phase 0..1: 0–0.5 the sun is up (rises at 0, sets at 0.5), 0.5–1 the moon is up.
var phase := START_PHASE
## 1 at noon, 0 at deep night.
var daylight := 1.0
## Near 1 around sunrise and sunset.
var twilight := 0.0


static func at(time: float, enabled := true) -> DayNight:
	var d := DayNight.new()
	if not enabled:
		d.phase = 0.25
		return d
	d.phase = fposmod(time / PERIOD + START_PHASE, 1.0)
	var s := sin(TAU * d.phase)
	d.daylight = smoothstep(-0.3, 0.35, s)
	d.twilight = exp(-pow(s / 0.28, 2.0))
	return d


## Multiplier for the canvas ambient for an age.
func tint(age: int) -> Color:
	var k: float = STRENGTH[age - 1]
	var c := NIGHT.lerp(Color.WHITE, daylight)
	c = c.lerp(DUSK, twilight * 0.45)
	return Color.WHITE.lerp(c, k)


## Where the sun (day) or moon (night) sits, as (x fraction across the view, height in px).
func body_pos() -> Vector2:
	var u := fposmod(phase, 0.5) / 0.5
	return Vector2(0.08 + 0.84 * u, 640.0 - sin(PI * u) * 520.0)


func is_night() -> bool:
	return phase >= 0.5


## How visible stars are, 0..1.
func stars() -> float:
	return clampf(1.0 - daylight * 1.6, 0.0, 1.0)
