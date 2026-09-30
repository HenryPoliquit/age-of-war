extends TestCase
## The world layer draws the bases' 3D art (towers, gates) through FkPaint, which composes every part onto the transform it was
## begun with.


func test_the_world_layer_sets_its_transforms_through_fkpaint() -> void:
	# Setting the canvas transform directly leaves FkPaint composing onto the previous one: the towers were then drawn at the
	# base's origin (behind the gate) and their turrets hung in the air.
	var f := FileAccess.open("res://scripts/view/world_layer.gd", FileAccess.READ)
	check(f != null, "world_layer.gd is readable")
	if f == null:
		return
	var n := 0
	for line in f.get_as_text().split("\n"):
		n += 1
		check(not line.strip_edges().begins_with("draw_set_transform_matrix("), "world_layer.gd:%d: use FkPaint.begin(self, xf)" % n)
