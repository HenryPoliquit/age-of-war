class_name UiStyle
extends RefCounted
## Classic PC-strategy UI look: beveled bronze-and-iron frames with rivets (generated 9-slice
## textures, no image assets), Cinzel for titles and Alegreya Sans for body text (OFL, assets/fonts).

const BRONZE := Color("b08a4e")
const BRONZE_DARK := Color("4a3520")
const IRON := Color("1c1d22")
const TEXT := Color("ece3cf")
const ACCENT := Color("e2bf73")

static var _theme: Theme
static var _fonts := {}


static func font(kind := "body") -> Font:
	if not _fonts.has(kind):
		var path: String = {"body": "res://assets/fonts/AlegreyaSans-Regular.woff2", "bold": "res://assets/fonts/AlegreyaSans-Bold.woff2",
			"title": "res://assets/fonts/Cinzel-Bold.woff2", "title_regular": "res://assets/fonts/Cinzel-Regular.woff2"}[kind]
		var f: Font = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
		_fonts[kind] = f
	return _fonts[kind]


## A beveled frame as a 9-slice texture. `bevel` light/dark swap for pressed; `fill` is the interior.
static func frame_texture(fill: Color, rim: Color, pressed := false, rivets := true, size := 48) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hi := rim.lightened(0.35)
	var lo := rim.darkened(0.45)
	if pressed:
		var tmp := hi
		hi = lo
		lo = tmp
	for y in size:
		for x in size:
			var edge := mini(mini(x, y), mini(size - 1 - x, size - 1 - y))
			var c: Color
			if edge == 0:
				c = Color(0.02, 0.02, 0.02, 0.95)
			elif edge <= 4:
				# Bevel: lit from the top-left.
				var top_left := (x < y) if (x + y < size) else false
				var k := 1.0 if (y <= 4 and y <= x) or (x <= 4 and x <= y and x + y < size - 1) else 0.0
				c = hi.lerp(lo, 1.0 - k)
				c = c.lerp(rim, 0.35 if edge == 2 or edge == 3 else 0.0)
				c.a = 1.0
			elif edge == 5:
				c = Color(0.03, 0.03, 0.03, 0.9)
			else:
				var n := rng.randf_range(-0.035, 0.035)
				c = Color(fill.r + n, fill.g + n, fill.b + n, fill.a)
			img.set_pixel(x, y, c)
	if rivets:
		for p in [Vector2i(2, 2), Vector2i(size - 3, 2), Vector2i(2, size - 3), Vector2i(size - 3, size - 3)]:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					img.set_pixel(p.x + dx, p.y + dy, rim.lightened(0.5) if dx + dy < 0 else rim.darkened(0.2))
	return ImageTexture.create_from_image(img)


static func box(fill: Color, rim: Color, pressed := false, margin := 10.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = frame_texture(fill, rim, pressed)
	sb.set_texture_margin_all(8)
	sb.set_content_margin_all(margin)
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = font("body")
	th.default_font_size = 17
	var panel_fill := Color(0.075, 0.07, 0.07, 0.92)
	th.set_stylebox("panel", "PanelContainer", box(panel_fill, BRONZE, false, 12))
	th.set_stylebox("normal", "Button", box(Color(0.16, 0.14, 0.12), BRONZE.darkened(0.15)))
	th.set_stylebox("hover", "Button", box(Color(0.22, 0.19, 0.15), BRONZE.lightened(0.1)))
	th.set_stylebox("pressed", "Button", box(Color(0.3, 0.23, 0.13), BRONZE, true))
	th.set_stylebox("disabled", "Button", box(Color(0.09, 0.09, 0.09), Color("4a4540")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for cls in ["OptionButton", "CheckBox"]:
		for st in ["normal", "hover", "pressed", "disabled"]:
			th.set_stylebox(st, cls, th.get_stylebox(st, "Button"))
		th.set_stylebox("focus", cls, StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", ACCENT)
	th.set_color("font_disabled_color", "Button", Color(TEXT, 0.35))
	th.set_color("font_color", "Label", TEXT)
	th.set_constant("outline_size", "Label", 4)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.75))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.04, 0.04, 0.85)
	bar_bg.border_color = BRONZE.darkened(0.3)
	bar_bg.set_border_width_all(2)
	th.set_stylebox("background", "ProgressBar", bar_bg)
	th.set_stylebox("panel", "PopupMenu", box(panel_fill, BRONZE))
	th.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.055, 0.05, 0.97), BRONZE, false, 10))
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font("font", "TooltipLabel", font("body"))
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = BRONZE
	th.set_stylebox("grabber_area", "HSlider", grabber)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(0.05, 0.05, 0.05)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", slider)
	_theme = th
	return th


## Title-font label helper.
static func title(parent: Control, text: String, size: int, col := ACCENT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l
