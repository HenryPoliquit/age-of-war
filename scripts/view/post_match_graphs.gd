class_name PostMatchGraphs
extends Control
## Post-match graphs (GDD §12.3) drawn straight from the match log: gold earned, army value,
## front-line position and age over time, with markers for evolutions, abilities and doctrines.

var match_log: MatchLog
var colors: Array = [Color.CORNFLOWER_BLUE, Color.ORANGE]

const SERIES := [
	["Army value", "army"],
	["Gold earned", "gold_earned"],
	["Age", "age"],
]


func _draw() -> void:
	if match_log == null or match_log.timeline.is_empty():
		return
	var font := ThemeDB.fallback_font
	var tl := match_log.timeline
	var t_end: float = tl[-1].t
	var rows := SERIES.size() + 1
	var gap := 14.0
	var h := (size.y - gap * (rows - 1)) / rows
	for r in rows:
		var rect := Rect2(0, r * (h + gap), size.x, h)
		draw_rect(rect, Color(1, 1, 1, 0.05))
		if r < SERIES.size():
			var key: String = SERIES[r][1]
			var vmax := 1.0
			for smp in tl:
				for s in 2:
					vmax = maxf(vmax, float(smp.sides[s].get(key, 0.0)))
			for s in 2:
				var pts := PackedVector2Array()
				for smp in tl:
					pts.append(Vector2(rect.position.x + rect.size.x * smp.t / t_end,
						rect.end.y - rect.size.y * float(smp.sides[s].get(key, 0.0)) / vmax))
				if pts.size() > 1:
					draw_polyline(pts, colors[s], 2.0)
			draw_string(font, rect.position + Vector2(6, 16), "%s (max %d)" % [SERIES[r][0], vmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		else:
			var lane := 2400.0
			var pts := PackedVector2Array()
			for smp in tl:
				pts.append(Vector2(rect.position.x + rect.size.x * smp.t / t_end, rect.end.y - rect.size.y * smp.front / lane))
			draw_line(Vector2(rect.position.x, rect.get_center().y), Vector2(rect.end.x, rect.get_center().y), Color(1, 1, 1, 0.2))
			if pts.size() > 1:
				draw_polyline(pts, Color.WHITE, 2.0)
			draw_string(font, rect.position + Vector2(6, 16), "Front line (top = pushing into the right base)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	for e in match_log.events:
		var mark := {"evolve": "E", "ability": "A", "doctrine": "D"}.get(e.type, "") as String
		if mark == "":
			continue
		var x := size.x * float(e.t) / t_end
		var col: Color = colors[int(e.side)]
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(col, 0.25), 1.0)
		draw_string(font, Vector2(x + 2, size.y - 4 - 14 * int(e.side)), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
