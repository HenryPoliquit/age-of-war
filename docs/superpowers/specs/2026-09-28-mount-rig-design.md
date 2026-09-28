# Mount rig and chariot: design

Follows `docs/superpowers/handoffs/2026-09-27-unit-body-rig.md` item 5 and the humanoid rig (`2026-09-27-humanoid-body-rig-design.md`), whose patterns it reuses.

## Why

Owner, 2026-09-28: "Let's also add the joints for the mounts. They look clunky at the moment. If on chariots, note the bottom of the wheel, center and top. Make so that our rider is inside the chariot not on the wheel. Usually for 2 wheeled chariots, the unit is standing inside the chariot."

Today (`FkMounts.quadruped`):
- **Legs:** each leg is two or three angle-rotated sticks. Nothing folds at the knee or hock, and hooves slide instead of planting.
- **Body and neck:** fixed polygons around a bobbing centre.
- **Rider:** sits on a returned point `c + (−2, −10)`.

Today (`FkMounts.chariot`):
- **Driver:** a seated rider (`legs = false`) at `(−16, 4)`, low on the wheel with a leg over it.
- **Wheel:** spins by `walk × 1.3`, which isn't tied to the ground it covers.

## Decisions (owner-approved design, 2026-09-28)

| Question | Decision |
|---|---|
| Rig | One shared quadruped skeleton for every beast; the proportions come from `BEASTS` (L, H, plus new per-kind bone fractions). |
| Solving | Hybrid, like the humanoid. The spine and neck are driven by the gait. Hooves get targets from the gait; each leg reaches its target by two-bone IK with a fixed bend side. |
| Gait | A four-beat walk now. The charge keeps today's lunge and dust. Trot and gallop come later. |
| Depth | Joints carry z. Near legs draw over the body, far legs under it. A mirrored figure flips z (turned around, as for the humanoids). |
| Rider | Sits on a `saddle` joint on the back. |
| Chariot | Wheel joints `center`/`top`/`bottom`. The wheel rolls without slipping. The car floor is at axle height. The driver stands on it, drawn behind the car's near panel. |

## 1. Quadruped skeleton (`addons/figure_kit/quadruped.gd`, `FkQuadruped`)

`FkQuadruped.solve(bp: Dictionary, pose: Dictionary, seed := 0) -> Dictionary`. The inputs:
- `bp` is a `BEASTS` entry.
- `pose` is the unit pose: `walk`, `move`, `atk`, `t`, `mirrored`, and an optional `pace`.
- `pace` is the ground covered per radian of walk phase, in px. The default is `1 / 0.11` ≈ 9.09, which matches the view's mounted stride (`WorldLayer.STRIDE.mounted`).

Local space is feet at y = 0, facing +x, as everywhere in the kit.

**Spine (FK):**
- `c` is the barrel centre: `(lunge, −H − 10 + bob)`, as today, where the bob is the walk's rise and fall of 2 px at double stride frequency.
- `withers = c + (0.55 L, −11)`, `croup = c + (−0.6 L, −9)` and `back = withers.lerp(croup, 0.5)`. The back pitches slightly with the gait: the withers lead and the croup lags by a quarter stride, ±1 px.
- `neck` runs from the withers up to `poll`. The neck angle nods with the walk, at ±0.08 rad on the front legs' beat. The head kind decides the rest pose: horse and deer high, boar low, ram mid, bear low and forward. The head is drawn at `poll`, turned by `head_angle`.
- `dock` is the tail root at `croup + (−5, −2)`.
- `saddle = c + (−2, −10 − (5 if bear))`. At rest this equals today's returned point, so the rider's seat height and the rider tests hold. It rides the back's bob and pitch.

**Legs.** There are four legs: `fn`, `ff`, `hn` and `hf` (front or hind, near or far).
- **Front leg chain:** `root` (shoulder) → `elbow` → `knee` (carpus) → `fetlock` → `hoof`.
  - `root` is at `c + (0.62 L, 5)`.
  - `elbow` sits a fixed body-carried offset below it (a `0.22 H` shoulder blade).
  - `elbow → knee` (forearm) and `knee → fetlock` (cannon) are an IK pair. The knee bends forward, the humanoid `KNEE` side.
- **Hind leg chain:** `root` (hip) → `stifle` → `hock` → `fetlock` → `hoof`.
  - `root` is at `c + (−0.62 L, 5)`.
  - `stifle` is a fixed body-carried offset forward and down (the thigh).
  - `stifle → hock` (gaskin) and `hock → fetlock` (cannon) are an IK pair. The hock bends backward, the opposite side.
- **Bone lengths** are fractions of `H`, chosen so that a standing leg is nearly straight: the IK pair's length is about 1.03× the distance from the upper joint to the fetlock at rest. The pastern (`fetlock → hoof`) is `0.14 H`. The fractions are constants in `FkQuadruped`, per front and hind.
- **Hoof targets (four-beat lateral walk):**
  - Each leg has a phase `ph = walk + offset`. The offsets are LH 0, LF 0.25, RH 0.5, RF 0.75 of a stride (×TAU). "Near" is the right side while unmirrored.
  - A stride is TAU of walk phase. A hoof is **planted** for the first 65% of the stride and **swings** for the rest.
  - While planted, the hoof stays at y = 0 and slides back in the body's frame at exactly `pace` px per radian, so it doesn't move on the ground.
  - While swinging, it returns forward along an arc lifting up to `0.18 H` (front) or `0.14 H` (hind). Its speed is set so it lands where the next stance starts. The cycle is continuous.
  - At rest (`move` 0) all hooves stand square under their roots. The walk blends in by `move`.
- **Fetlock and hoof angle.** The pastern points up and forward from the hoof at 0.6 rad while planted, and folds back, tucked up to 1.4 rad, during the swing. That puts the fetlock at `hoof + pastern`, and the IK solves to the fetlock.
- **Depth:** `z = ±w` per leg side (near +, far −), with `w = 0.3 L`. The spine is at 0. A mirrored figure negates z.
- **Output:** a Dictionary of the joints above, plus `z`, `head_angle`, `saddle`, `c`, `lunge` and `stride_phase` (per leg: planted or swinging).
- The charge (`atk`) keeps today's lunge (`swing(atk) × 5`) and dust.

## 2. Beast drawing (`FkMounts.quadruped`, rewritten on the skeleton)

- **Draw order** is by depth, then rank: far legs, tail, body (barrel through the withers, back, croup and belly), neck and head, cover, near legs, then dust. This keeps today's approved layering: the cover is over the body, and near legs draw over the cover's lower edge the way they do now.
- **Legs** are drawn as tapered segments per bone, using today's widths, `w0`/`w1` per kind. There's a joint knob at the knee or hock, a hoof block at the hoof, or a paw ellipse for `paws` (the bear).
- **Heads, antlers, horns, manes, tails and covers** keep their current drawings, re-anchored:
  - heads, antlers and horns at `poll`, rotated by `head_angle`;
  - the mane along the neck;
  - the tail at `dock`, swaying as now;
  - covers (blanket, caparison, scale, plates) around `back`/`c`.
- **Shading:** far legs are darkened, as now. When mirrored, the lit side swaps.
- The function returns `j.saddle`. `mounted()` passes it to `_rider` exactly as it passes the returned point today.

## 3. Chariot (`FkMounts.chariot`)

- **Wheel joints** come from `FkMounts.chariot_joints(pose) -> {center, top, bottom, angle, floor}`:
  - `r = 13`, `center = (−18, −13)`, `bottom = (−18, 0)` (on the ground) and `top = (−18, −26)`;
  - `angle = walk × pace_c / r`, where `pace_c = 1 / 0.12` px per radian (the view's chariot stride), so a point on the rim covers exactly the ground travelled;
  - `floor` is the car floor, `y = −14`, just above the axle.
- **Beast:** drawn as today (scaled 0.78 at `(26, 0)`), with `pace = pace_c / 0.78`, so its hooves also stay put.
- **Driver:** a standing humanoid (`legs = true`), feet on `floor`, at `x = −17`.
  - They don't walk (`move = 0`).
  - They sway with the car: `ride_bob` = a small bump from the wheel (`sin(angle × 6) × 0.6`), and the hips follow the beast's walk. Stances and attacks are unchanged.
  - A mirrored chariot passes `mirrored` through to the driver.
- **Draw order** (`FkMounts.CHARIOT_ORDER`), back to front: `pole`, `far wheel`, `car back` (back wall and floor, darker), `driver`, `car front` (the near panel, rails and team field), `near wheel`, `yoke`. The near panel covers the driver below mid-thigh, so the driver reads as standing inside the car.
  - The far wheel is a darker copy at `center + (3, −1)`, mostly hidden.
  - Each car kind (`bronze`, `wood`, `iron`) is split into a back part and a front part. The shapes stay the same, and the floor line is at `floor`.

## 4. Testing

**`tests/test_fk_quadruped.gd`** (new):
- Every leg bone keeps its length in every frame of a walk cycle. That's 32 phases for horse, boar and bear, plus rest and charge frames.
- A planted hoof is on the ground (|y| < 0.3), and it doesn't slide on the ground: its world x plus the ground covered (`pace × Δwalk`) is constant within 0.3 px across its stance.
- A swinging hoof lifts at least `0.08 H` at mid-swing.
- The feet lift off in four-beat order: LH, LF, RH, RF, each a quarter stride apart.
- The front knee is always forward of the elbow–fetlock line. The hock is always behind the stifle–fetlock line.
- Nothing snaps: between walk phases TAU/100 apart, no joint moves more than 3 px.
- At rest the saddle equals today's saddle point for every beast. While walking the saddle bobs.
- Mirrored figures flip every z.

**`tests/test_fk_units.gd`:**
- The chariot wheel's bottom is at y = 0. `angle` advances by `pace_c / r` per radian of walk.
- The driver's feet are on `floor` (the humanoid solve's feet, offset, within 0.5 px of `floor`).
- `CHARIOT_ORDER` has the `driver` before `car front`, and `car front` before `near wheel`.

**Existing tests:** all mounted-rider tests (seat height, reins over the withers, sabre half-seat, couched lance, rider bob) keep passing.

## 5. Review

Three stages, each ending with the animation page republished (same URL, three columns per unit):
1. Skeleton and tests. Nothing visual changes.
2. Beasts redrawn on the skeleton.
3. Chariot.

The owner reviews locally. Sim and balance are untouched: this is a view-only change, in the kit and its tests.

**Out of scope:** trot and gallop gaits, siege machines and their crews, and golem and treant (done separately).
