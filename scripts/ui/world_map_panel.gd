extends Control

const DESIGN_SIZE := Vector2(920, 560)

var _event_markers: Array = []
var _highlight_marker: Dictionary = {}
var _highlight_target := Vector2.ZERO

func set_event_markers(markers: Array) -> void:
	_event_markers = markers.duplicate(true)
	queue_redraw()


func set_highlight_marker(marker: Dictionary, target_position: Vector2 = Vector2.ZERO) -> void:
	_highlight_marker = marker.duplicate(true)
	_highlight_target = target_position
	queue_redraw()


func clear_highlight_marker() -> void:
	_highlight_marker = {}
	_highlight_target = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.66, 0.66, 0.66, 1.0), true)
	_draw_contours()
	_draw_city_blocks()
	_draw_roads_and_rivers()
	_draw_control_zones()
	_draw_marker_guides()
	_draw_hover_highlight()

func _scale_point(point: Vector2) -> Vector2:
	return Vector2(point.x / DESIGN_SIZE.x * size.x, point.y / DESIGN_SIZE.y * size.y)

func _draw_contours() -> void:
	var contour_color := Color(0.40, 0.40, 0.40, 0.70)
	var contour_sets := [
		[Vector2(78, 84), Vector2(116, 52), Vector2(202, 48), Vector2(286, 92), Vector2(350, 162), Vector2(322, 236), Vector2(226, 262), Vector2(132, 230), Vector2(78, 168)],
		[Vector2(94, 102), Vector2(150, 74), Vector2(226, 74), Vector2(294, 118), Vector2(316, 178), Vector2(270, 220), Vector2(194, 236), Vector2(126, 208), Vector2(94, 160)],
		[Vector2(112, 124), Vector2(164, 104), Vector2(222, 108), Vector2(272, 136), Vector2(280, 180), Vector2(238, 206), Vector2(178, 214), Vector2(128, 190), Vector2(112, 150)],
		[Vector2(128, 146), Vector2(172, 132), Vector2(212, 134), Vector2(244, 154), Vector2(242, 184), Vector2(210, 198), Vector2(170, 198), Vector2(138, 180), Vector2(128, 156)]
	]
	for contour in contour_sets:
		_draw_polyline(contour, contour_color, 2.0)

func _draw_city_blocks() -> void:
	var fill := Color(0.26, 0.26, 0.26, 0.88)
	var stroke := Color(0.18, 0.18, 0.18, 0.95)
	var blocks := [
		Rect2(_scale_point(Vector2(534, 68)), _scale_point(Vector2(84, 96))),
		Rect2(_scale_point(Vector2(650, 202)), _scale_point(Vector2(180, 224))),
		Rect2(_scale_point(Vector2(734, 182)), _scale_point(Vector2(120, 106)))
	]
	for block in blocks:
		draw_rect(block, fill, true)
		draw_rect(block, stroke, false, 3.0)
	var inner_streets := [
		[Vector2(676, 210), Vector2(676, 408)],
		[Vector2(718, 206), Vector2(718, 416)],
		[Vector2(760, 206), Vector2(760, 408)],
		[Vector2(646, 252), Vector2(822, 252)],
		[Vector2(646, 300), Vector2(822, 300)],
		[Vector2(734, 184), Vector2(842, 270)]
	]
	for line in inner_streets:
		_draw_polyline(line, Color(0.45, 0.45, 0.45, 0.55), 1.5)

func _draw_roads_and_rivers() -> void:
	_draw_polyline([Vector2(514, 14), Vector2(566, 66), Vector2(614, 176), Vector2(700, 260), Vector2(854, 514)], Color(0.12, 0.12, 0.12, 0.92), 5.0)
	_draw_polyline([Vector2(884, 0), Vector2(846, 78), Vector2(846, 202), Vector2(904, 292), Vector2(920, 418)], Color(0.82, 0.82, 0.82, 0.8), 7.0)
	_draw_polyline([Vector2(0, 476), Vector2(86, 560)], Color(0.86, 0.86, 0.86, 0.85), 8.0)

func _draw_control_zones() -> void:
	_draw_dashed_circle(Vector2(610, 92), 116.0, Color(0.80, 0.18, 0.22, 0.8), 3.0)
	_draw_dashed_arc(Vector2(760, 294), 88.0, Color(0.80, 0.18, 0.22, 0.9), 3.0)
	_draw_hatched_blob([Vector2(700, 318), Vector2(746, 296), Vector2(832, 312), Vector2(822, 522), Vector2(658, 504)], Color(0.13, 0.18, 0.52, 0.22), Color(0.12, 0.25, 0.75, 0.78))
	_draw_hatched_blob([Vector2(300, 378), Vector2(360, 362), Vector2(402, 392), Vector2(372, 452), Vector2(294, 438)], Color(0.13, 0.18, 0.52, 0.22), Color(0.12, 0.25, 0.75, 0.78))
	_draw_arrow(Vector2(54, 460), Vector2(18, 540), Color(0.86, 0.16, 0.16, 0.88), 5.0)
	_draw_arrow(Vector2(332, 432), Vector2(332, 510), Color(0.14, 0.24, 0.78, 0.88), 4.0)
	_draw_arrow(Vector2(756, 360), Vector2(792, 432), Color(0.86, 0.16, 0.16, 0.88), 4.0)

func _draw_marker_guides() -> void:
	for marker_value in _event_markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		var point := Vector2(marker.get("x", 0.0), marker.get("y", 0.0))
		var color := Color(0.82, 0.16, 0.18, 0.92)
		if String(marker.get("kind", "battle")) == "narrative":
			color = Color(0.94, 0.90, 0.72, 0.92)
		elif String(marker.get("kind", "battle")) == "random":
			color = Color(0.10, 0.24, 0.82, 0.92)
		var center := _scale_point(point)
		draw_arc(center, 11.0, 0.0, TAU, 28, color, 3.0)
		draw_circle(center, 3.5, color)
		var guide_end := center + Vector2(0, 24)
		draw_line(center + Vector2(0, 12), guide_end, color, 2.0)


func _draw_hover_highlight() -> void:
	if _highlight_marker.is_empty():
		return
	var point := Vector2(float(_highlight_marker.get("x", 0.0)), float(_highlight_marker.get("y", 0.0)))
	var center := _scale_point(point)
	var color := Color(1.0, 0.94, 0.62, 0.92)
	draw_arc(center, 19.0, 0.0, TAU, 42, color, 4.0)
	if _highlight_target != Vector2.ZERO:
		draw_line(center, _highlight_target, color, 3.0)

func _draw_polyline(points: Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var scaled := PackedVector2Array()
	for point_value in points:
		scaled.append(_scale_point(point_value))
	draw_polyline(scaled, color, width, true)

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 24
	for i in range(segments):
		if i % 2 == 1:
			continue
		var start_angle := float(i) / float(segments) * TAU
		var end_angle := float(i + 1) / float(segments) * TAU
		draw_arc(_scale_point(center), radius * min(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y), start_angle, end_angle, 8, color, width)

func _draw_dashed_arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	for i in range(14):
		if i % 2 == 0:
			continue
		var start_angle := PI * 0.20 + float(i) * 0.12
		var end_angle := start_angle + 0.07
		draw_arc(_scale_point(center), radius * min(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y), start_angle, end_angle, 8, color, width)

func _draw_hatched_blob(points: Array, fill_color: Color, line_color: Color) -> void:
	if points.size() < 3:
		return
	var poly := PackedVector2Array()
	var scaled_points: Array[Vector2] = []
	for point_value in points:
		var scaled := _scale_point(point_value)
		scaled_points.append(scaled)
		poly.append(scaled)
	draw_colored_polygon(poly, fill_color)
	_draw_polyline(points + [points[0]], line_color, 2.5)
	var bounds := Rect2(scaled_points[0], Vector2.ZERO)
	for p in scaled_points:
		bounds = bounds.expand(p)
	var x := bounds.position.x - bounds.size.y
	while x < bounds.end.x + bounds.size.y:
		_draw_clipped_line(Vector2(x, bounds.position.y), Vector2(x + bounds.size.y, bounds.end.y), line_color, 1.4)
		x += 12.0

func _draw_arrow(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var from_scaled := _scale_point(from_point)
	var to_scaled := _scale_point(to_point)
	_draw_clipped_line(from_scaled, to_scaled, color, width)
	var dir := (to_scaled - from_scaled).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([to_scaled, to_scaled - dir * 18.0 + side * 9.0, to_scaled - dir * 18.0 - side * 9.0])
	draw_colored_polygon(head, color)


func _draw_clipped_line(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var clipped := _clip_line_to_rect(from_point, to_point, Rect2(Vector2.ZERO, size))
	if clipped.is_empty():
		return
	draw_line(clipped[0], clipped[1], color, width)


func _clip_line_to_rect(from_point: Vector2, to_point: Vector2, rect: Rect2) -> Array:
	var x0 := from_point.x
	var y0 := from_point.y
	var x1 := to_point.x
	var y1 := to_point.y
	var dx := x1 - x0
	var dy := y1 - y0
	var p := [-dx, dx, -dy, dy]
	var q := [x0 - rect.position.x, rect.end.x - x0, y0 - rect.position.y, rect.end.y - y0]
	var u1 := 0.0
	var u2 := 1.0
	for i in range(4):
		var pi: float = float(p[i])
		var qi: float = float(q[i])
		if is_zero_approx(pi):
			if qi < 0.0:
				return []
			continue
		var t: float = qi / pi
		if pi < 0.0:
			u1 = max(u1, t)
		else:
			u2 = min(u2, t)
		if u1 > u2:
			return []
	return [
		Vector2(x0 + (u1 * dx), y0 + (u1 * dy)),
		Vector2(x0 + (u2 * dx), y0 + (u2 * dy))
	]
