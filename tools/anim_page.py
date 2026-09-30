"""Slices tools/unit_anim.gd frames into one looping GIF per unit (walk | attack | the attack mirrored, as the enemy army) and writes
<out>/index.html from tools/anim_page.html, grouped by role with the three races of each age together.

    python tools/anim_page.py reports/anim/frames reports/anim "build label"
Needs Pillow.
"""
import html
import os
import sys

from PIL import Image

CELL_W, CELL_H, COLS = 600, 260, 6
FPS = 12
ROLES = [("vanguard", "Vanguard"), ("ranged", "Ranged"), ("heavy", "Heavy"), ("siege", "Siege")]
RACES = ["human", "elf", "dwarf"]
AGES = ["", "Stone", "Bronze", "Iron", "Medieval", "Gunpowder", "Arcane"]


def main(frames_dir: str, out_dir: str, build: str) -> None:
    rows = [l.split("\t") for l in open(os.path.join(frames_dir, "units.tsv"), encoding="utf-8").read().splitlines()]
    names = sorted(f for f in os.listdir(frames_dir) if f.startswith("f") and f.endswith(".png"))
    frames = [Image.open(os.path.join(frames_dir, f)).convert("RGB") for f in names]
    gif_dir = os.path.join(out_dir, "gif")
    os.makedirs(gif_dir, exist_ok=True)
    cards = {}
    for i, race, uid, role, age, name in rows:
        i = int(i)
        x, y = (i % COLS) * CELL_W, (i // COLS) * CELL_H
        seq = [f.crop((x, y, x + CELL_W, y + CELL_H)) for f in frames]
        seq[0].save(os.path.join(gif_dir, f"{race}_{uid}.gif"), save_all=True, append_images=seq[1:],
                    duration=int(1000 / FPS), loop=0, optimize=True)
        cards.setdefault(role, []).append((int(age), RACES.index(race), race, uid, name))
    parts = []
    for role, title in ROLES:
        items = sorted(cards.get(role, []))
        parts.append(f"  <section id='{role}'>\n    <h2>{title} <small>{len(items)} units</small></h2>\n    <div class='grid'>")
        for age, _, race, uid, name in items:
            parts.append(
                f"      <figure data-race='{race}'><div class='well'><div class='legs'><span>walk</span><span>attack</span><span>enemy side</span></div>"
                f"<img src='gif/{race}_{uid}.gif' width='600' height='260' alt='{html.escape(name)} walking and attacking' loading='lazy'></div>"
                f"<figcaption><b>{html.escape(name)}</b><em>{race.title()} · {AGES[age]}</em></figcaption></figure>")
        parts.append("    </div>\n  </section>")
    page = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "anim_page.html"), encoding="utf-8").read()
    page = page.replace("<!--UNITS-->", "\n".join(parts)).replace("<!--BUILD-->", html.escape(build))
    open(os.path.join(out_dir, "index.html"), "w", encoding="utf-8").write(page)
    print(f"{len(rows)} gifs -> {gif_dir}; page -> {os.path.join(out_dir, 'index.html')}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
