class_name FkGait
extends RefCounted
## The walk cycle every two-legged walker shares (human figures, golems, treants): where a foot is over a stride, how high it
## is lifted, how the ankle is pitched, and how high the hips stand so the legs on the ground stay nearly straight. A gait `g`
## is a Dictionary {stride (px a foot reaches ahead), lift (px), heel (landing toe-up, rad; negative lands on the ball),
## toe (heel up at push-off, rad), clear (toe lift in the swing, rad, default 0.14), arc (0..1, how much the hips swell), twist}.
## A stride's phase `ph` is PI/2 as a heel lands and 3·PI/2 as the toe leaves; the two legs are PI apart.

## How straight the stance leg gets (share of its full length between hip and ankle).
const STANCE_EXT := 0.995
## How far the foot rises (px) before the toe cap has lifted off the ground: the toe bends at the ball until then.
const TOE_LIFT := 3.0

static var _need_cache := {}


## The stride's place in its two halves for a foot at phase `ph`: below 1 is the swing (0 as the toe leaves, 1 as the foot lands),
## 1 to 2 is the stance (1 as it lands, 2 as the toe leaves). One number, so every curve below is a function of it.
static func stride_pos(ph: float) -> float:
	return fposmod(ph + PI * 0.5, TAU) / PI


static func smooth(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## A foot's position ahead of the hips over one stride (−1..1 × the gait's stride). On the ground the foot slides back at a
## steady pace, so it stays put on the ground as the body moves over it (a sine would skate: fast under the hips, nearly still
## at either end). The swing carries it forward on a curve that leaves briskly and arrives at that same pace, reaching a little
## past its landing spot before settling back onto it.
static func foot_x(ph: float) -> float:
	var a := fposmod(ph + PI * 0.5, TAU)
	if a < PI:
		# Hermite from −1 (leaving at a gentle −0.6) to +1 (arriving at the stance's pace, −2 per swing).
		var u := a / PI
		return ((-6.6 * u + 9.2) * u - 0.6) * u - 1.0
	return 1.0 - 2.0 * (a - PI) / PI


## How high the foot is lifted in the swing (0..1 × the gait's lift): it rises briskly as the toe leaves (the heel's height is
## handed over from the ankle to the lift with no dip), peaks about 40% of the way through, and sets down gently, with no
## vertical speed at touchdown.
static func swing_lift(pos: float) -> float:
	return pow(sin(PI * pow(pos, 0.8)), 1.2) if pos < 1.0 else 0.0


## The ankle through a stride (rad; + points the toe down, − lifts it). It lands nearly flat, a mid-foot strike (`heel`: a few
## degrees of toe-up, or negative to land on the ball), settles flat for the first part of the stance, then the heel lifts
## steadily as the body rolls over the ball of the foot, reaching `toe` as the toe leaves. The swing keeps that toe-down for
## a moment and drops it, then lifts the toe (`clear`) to clear the ground before laying it down again for the landing.
static func ankle(pos: float, g: Dictionary) -> float:
	var heel: float = g.heel
	var toe: float = g.toe
	var clear: float = g.get("clear", 0.14)
	if pos < 1.0:
		# Swing: toe-off, level by 0.45 of the swing, toe lifted by 0.8, then the landing angle.
		if pos < 0.45:
			return lerpf(toe, 0.0, smooth(pos / 0.45))
		if pos < 0.8:
			return lerpf(0.0, -clear, smooth((pos - 0.45) / 0.35))
		return lerpf(-clear, -heel, smooth((pos - 0.8) / 0.2))
	var v := pos - 1.0
	if v < 0.15:
		return lerpf(-heel, 0.0, smooth(v / 0.15))
	if v < 0.45:
		return 0.0
	return toe * smooth((v - 0.45) / 0.55)


## How far the toe cap has bent back at the ball (rad) for an ankle pitched `rot` with the foot raised `lift` px: it stays down on
## the ground while the heel lifts, and comes up with the foot.
static func toe_bend(rot: float, lift: float) -> float:
	return clampf(maxf(rot, 0.0) * (1.0 - lift / TOE_LIFT), 0.0, maxf(rot, 0.0))


## The highest the hips can stand while walking (px, up): the lowest of what each leg on the ground allows. A leg's ankle stays
## within STANCE_EXT of the leg's full length from the hip, at the ankle's actual height (heel lifted, foot lifted) and its
## actual distance ahead of the hip root. A leg lifting into its swing allows more height, so it never holds the hips down.
## `leg`: {l: the leg's full length, scale: the walker's size (× the gait's px), flat: a flat foot's ankle height in the gait's
## px, low: Callable(rot, flex) -> px the boot's lowest point hangs below the ankle, root_dx: Callable(walk, i) -> px the hip
## root stands ahead of the hips' centre}.
static func need(g: Dictionary, walk: float, leg: Dictionary) -> float:
	var scale: float = leg.scale
	var best := INF
	for i in 2:
		var ph := walk + PI * i
		var pos := stride_pos(ph)
		var lift: float = g.lift * swing_lift(pos)
		var rot := ankle(pos, g)
		var low: float = leg.low.call(rot, toe_bend(rot, lift))
		var x: float = g.stride * foot_x(ph) * scale - float(leg.root_dx.call(walk, i))
		best = minf(best, low + maxf(0.0, lift - float(leg.flat)) * scale + sqrt(maxf(0.0, pow(float(leg.l) * STANCE_EXT, 2.0) - x * x)))
	return best


## Height of the hips above the ground while walking: one smooth swell per step. Lowest as a heel lands (the foot furthest
## ahead, the leg straight), highest as the body passes over the foot (the leg straight again); between them the knee gives a
## little (the loading response, and again as the heel lifts), which is what a natural walk looks like, and the hips, knees and
## ankles move together with no jerk. `arc` (the gait's) shrinks the swell: 0 keeps the hips at the landing height, at the cost
## of a bent knee mid-stance. Never higher than the legs allow (need(), sampled once per `key`). `make_leg` builds the leg
## description (see need()) when the key is new.
static func hip_height(g: Dictionary, walk: float, key: String, make_leg: Callable) -> float:
	if not _need_cache.has(key):
		var leg: Dictionary = make_leg.call()
		var samples := PackedFloat32Array()
		for i in 48:
			samples.append(need(g, PI * i / 48.0, leg))
		_need_cache[key] = samples
	var samples: PackedFloat32Array = _need_cache[key]
	var low: float = samples[0]
	for v in samples:
		low = minf(low, v)
	var high: float = samples[0]
	var h := low + (high - low) * (0.5 + 0.5 * cos(2.0 * walk)) * float(g.get("arc", 1.0))
	# The legs' own limit at this moment (the samples are one step, PI, long).
	var f := fposmod(walk, PI) / PI * 48.0
	var i0 := int(f) % 48
	return minf(h, lerpf(samples[i0], samples[(i0 + 1) % 48], f - floorf(f)))
