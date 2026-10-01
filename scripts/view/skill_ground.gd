class_name SkillGround
extends Node2D
## The skills' marks on the ground (circles and fields of land, GDD §7). It sits between the backdrop and the
## units, so units stand *on* a mark instead of under it: the mark is part of the ground, not an overlay.
## Two passes, like FxLayer: a normal one (the shade a mark casts) and an additive one (its light).

var skills: SkillFx
var glow: Node2D


func _ready() -> void:
	glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(func():
		if skills != null:
			skills.draw_ground_glow(glow, skills.fxl.now()))
	add_child(glow)


func _draw() -> void:
	if skills != null:
		skills.draw_ground(self, skills.fxl.now())


## Once a frame.
func refresh() -> void:
	queue_redraw()
	if glow != null:
		glow.queue_redraw()
