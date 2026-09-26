#!/usr/bin/env python3
"""Coordinate-descent balance tuner over the harness (tools/sim/run_sim.gd).

Scores each run by how far every PRD §6 metric sits outside its target band, and searches a set of
data/AI knobs expressed as SimJobs overrides (--scale / --set). Nothing is written to data/: the
result is a list of overrides to review and apply by hand (and record in docs/balance_log.md).

  python3 tools/sim/tune.py --matches=12 --passes=2 --log=/tmp/tune.jsonl
"""
import argparse, json, os, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.path.join(ROOT, "tools", "godot")
PERSONALITIES = ["tactician", "rusher", "turtle", "economist", "fast_age", "strong_age",
                 "spam_vanguard", "spam_ranged", "spam_heavy", "spam_siege"]

# name, kind, target, start value, step multipliers (for scale) or candidate values (for set)
PARAMS = [
    ("base_hp", "scale", ["ages:index=*.base_max_hp"], 1.0, [0.8, 1.4, 2.0]),
    ("evolve_cost", "scale", ["ages:index=*.evolve_cost", "ages:index=*.veterancy_base_xp"], 1.0, [0.6, 0.8, 1.15]),
    ("turret_dmg", "scale", ["turrets:kind=*.damage"], 1.0, [0.8, 1.25]),
    ("turret_cost", "scale", ["turrets:kind=*.cost"], 1.0, [0.8, 1.25]),
    ("heavy_cost", "scale", ["units:role=heavy.cost"], 1.0, [0.88, 1.14]),
    ("heavy_hp", "scale", ["units:role=heavy.hp"], 1.0, [0.88, 1.14]),
    ("ranged_dmg", "scale", ["units:role=ranged.damage"], 1.0, [0.88, 1.14]),
    ("vanguard_hp", "scale", ["units:role=vanguard.hp"], 1.0, [0.88, 1.14]),
    ("siege_dmg", "scale", ["units:role=siege.damage"], 1.0, [0.85, 1.2]),
    ("elite_cost", "set", ["doctrines/elite.unit_cost_mult"], 1.2, "rel:0.96,1.04"),
    ("horde_cost", "set", ["doctrines/horde.unit_cost_mult"], 0.73, "rel:0.96,1.04"),
    ("bastion", "set", ["doctrines/bastion.turret_damage_mult"], 1.25, "rel:0.9,1.1"),
    ("siegecraft", "set", ["doctrines/siegecraft.siege_structure_mult"], 1.5, "rel:0.88,1.12"),
    ("vet_bonus", "set", ["rules.veterancy_bonus"], 0.1, "rel:0.8,1.25"),
    ("forge_bonus", "set", ["rules.forge_income_bonus"], 0.2, "rel:0.8,1.25"),
    ("push_ratio", "set_all", ["push_ratio"], 1.3, "rel:0.75,1.35"),
    ("counter", "set_all", ["counter_strength"], 1.5, "rel:0.67,1.5"),
    ("turtle_turrets", "set", ["ai/personalities/turtle.turret_target"], 4, [3, 2]),
    ("rusher_hold", "set", ["ai/personalities/rusher.hold_release_seconds"], 45.0, "rel:0.7,1.4"),
]


def band(x, lo, hi, scale):
    return max(0.0, lo - x, x - hi) / scale


def loss(m):
    l = 0.0
    l += band(m["escalation"], 0, 0.10, 0.05)
    l += band(m["median_length"], 600, 840, 60)
    l += band(min(m["median_age6"], 1200), 600, 720, 60) + band(m["age6_reached"], 0.5, 1.0, 0.1)
    l += sum(band(v, 0.4, 0.6, 0.05) for v in m["personality"].values())
    l += 0.5 * sum(band(v, 0.3, 0.7, 0.05) for v in m["pairs"].values())
    l += sum(band(v, 0.4, 0.6, 0.05) for v in m.get("doctrines", {}).values())
    l += band(m["fast_vs_strong"], 0.4, 0.6, 0.05)
    l += sum(band(v, 0.0, 0.29, 0.05) for v in m["spam"].values())
    l += band(m["turtle_escalation"], 0, 0.25, 0.05) + band(m["turtle_longest"], 0, 1080, 60)
    return l


def args_for(state):
    out = []
    for name, kind, targets, start, _ in PARAMS:
        v = state[name]
        if kind == "scale":
            if abs(v - 1.0) > 1e-9:
                out += [f"--scale={t}={v:.4f}" for t in targets]
        elif kind == "set":
            if v != start:
                out += [f"--set={t}={v}" for t in targets]
        elif kind == "set_all":
            if v != start:
                out += [f"--set=ai/personalities/{p}.{targets[0]}={v}" for p in PERSONALITIES]
    return out


_cache = {}


def evaluate(state, matches, seed):
    extra = args_for(state)
    key = (tuple(extra), matches, seed)
    if key in _cache:
        return _cache[key]
    out = tempfile.mkdtemp(prefix="tune_")
    cmd = ["timeout", "1200", GODOT, "--headless", "--path", ROOT, "-s", "tools/sim/run_sim.gd", "--",
           f"--matches={matches}", f"--seed={seed}", f"--out={out}"] + extra
    subprocess.run(cmd, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with open(os.path.join(out, "sim_report.json")) as f:
        rep = json.load(f)
    res = (loss(rep["metrics"]), rep["metrics"], sum(1 for c in rep["checks"] if c["pass"]))
    _cache[key] = res
    return res


def candidates(param, cur):
    name, kind, targets, start, steps = param
    if isinstance(steps, str) and steps.startswith("rel:"):
        vals = [round(cur * float(x), 4) for x in steps[4:].split(",")]
    elif kind == "scale":
        vals = [round(cur * s, 4) for s in steps]
    else:
        vals = [v for v in steps if v != cur]
    if isinstance(start, int) and not isinstance(start, bool):
        vals = [int(round(v)) for v in vals]
    return [v for v in vals if v != cur]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--matches", type=int, default=12)
    ap.add_argument("--seed", type=int, default=3)
    ap.add_argument("--passes", type=int, default=2)
    ap.add_argument("--log", default="/tmp/tune.jsonl")
    ap.add_argument("--only", default="", help="comma-separated param names to search")
    a = ap.parse_args()
    state = {p[0]: p[3] for p in PARAMS}
    only = set(a.only.split(",")) if a.only else None
    best, metrics, passed = evaluate(state, a.matches, a.seed)
    logf = open(a.log, "a")

    def log(msg, **kw):
        line = json.dumps({"t": time.strftime("%H:%M:%S"), "msg": msg, **kw})
        print(line, flush=True)
        logf.write(line + "\n")
        logf.flush()

    log("start", loss=round(best, 3), passed=passed, metrics=metrics)
    for p in range(a.passes):
        improved = False
        for param in PARAMS:
            name = param[0]
            if only and name not in only:
                continue
            for v in candidates(param, state[name]):
                trial = dict(state)
                trial[name] = v
                l, m, ok = evaluate(trial, a.matches, a.seed)
                log("try", param=name, value=v, loss=round(l, 3), passed=ok)
                if l < best - 0.05:
                    best, state, metrics, passed = l, trial, m, ok
                    improved = True
                    log("accept", param=name, value=v, loss=round(best, 3), passed=passed)
        log("pass_done", n=p + 1, loss=round(best, 3), passed=passed, state=state, args=args_for(state))
        if not improved:
            break
    log("final", loss=round(best, 3), passed=passed, state=state, args=args_for(state), metrics=metrics)


if __name__ == "__main__":
    main()
