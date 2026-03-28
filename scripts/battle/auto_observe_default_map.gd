extends Control

const DESIGN_SIZE := Vector2(920, 560)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	queue_redraw()


func _on_resized() -> void:
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_draw_base()
	_draw_paper_noise()
	_draw_center_clear_zone()
	_draw_sparse_contours()
	_draw_left_contour_cluster()
	_draw_right_dark_areas()
	_draw_roads()
	_draw_blue_control_zones()
	_draw_red_tactical_marks()
	_draw_border()


func _draw_base() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.61, 0.61, 0.61, 1.0), true)
	_draw_vertical_gradient(
		Rect2(Vector2.ZERO, size),
		Color(0.68, 0.68, 0.68, 0.22),
		Color(0.52, 0.52, 0.52, 0.14),
		22
	)


func _draw_paper_noise() -> void:
	var noise_color := Color(0.08, 0.08, 0.08, 0.035)
	var horizontal_step: float = maxf(6.0, 8.0 * _map_scale())
	var y: float = 0.0
	while y <= size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), noise_color, 1.0)
		y += horizontal_step
	for i in range(140):
		var p: Vector2 = _scale_point(Vector2(
			fmod(float(i * 83), DESIGN_SIZE.x),
			fmod(float(i * 149), DESIGN_SIZE.y)
		))
		draw_circle(p, 0.7, Color(0.06, 0.06, 0.06, 0.05))


func _draw_center_clear_zone() -> void:
	_draw_soft_disc(Vector2(468, 290), 174.0, Color(0.82, 0.82, 0.82, 0.30))
	_draw_soft_disc(Vector2(468, 290), 116.0, Color(0.86, 0.86, 0.86, 0.24))


func _draw_sparse_contours() -> void:
	var contour_color := Color(0.41, 0.41, 0.41, 0.34)
	for i in range(8):
		var y0 := 42.0 + (float(i) * 62.0)
		var points := [
			Vector2(24, y0 + 10),
			Vector2(166, y0 - 6),
			Vector2(344, y0 + 18),
			Vector2(560, y0 - 12),
			Vector2(772, y0 + 16),
			Vector2(898, y0 - 4)
		]
		_draw_polyline(points, contour_color, 1.4)


func _draw_left_contour_cluster() -> void:
	var cluster_color := Color(0.30, 0.30, 0.30, 0.60)
	var cluster := [
		[Vector2(106, 92), Vector2(162, 64), Vector2(234, 74), Vector2(308, 122), Vector2(294, 188), Vector2(216, 222), Vector2(138, 206), Vector2(94, 150)],
		[Vector2(114, 108), Vector2(172, 84), Vector2(228, 92), Vector2(286, 132), Vector2(278, 182), Vector2(220, 210), Vector2(160, 198), Vector2(120, 156)],
		[Vector2(126, 124), Vector2(180, 102), Vector2(224, 110), Vector2(268, 140), Vector2(262, 176), Vector2(224, 198), Vector2(178, 192), Vector2(136, 164)],
		[Vector2(136, 138), Vector2(184, 120), Vector2(220, 126), Vector2(250, 148), Vector2(246, 172), Vector2(216, 186), Vector2(182, 184), Vector2(146, 166)]
	]
	for contour in cluster:
		_draw_polyline(contour, cluster_color, 2.0)
	_draw_dashed_circle(Vector2(308, 174), 32.0, Color(0.74, 0.26, 0.26, 0.78), 2.2)
	_draw_dashed_circle(Vector2(238, 214), 16.0, Color(0.74, 0.26, 0.26, 0.78), 2.0)


func _draw_right_dark_areas() -> void:
	var city_fill := Color(0.28, 0.28, 0.28, 0.72)
	var city_stroke := Color(0.22, 0.22, 0.22, 0.58)
	var main_blocks := [
		Rect2(Vector2(654, 198), Vector2(180, 210)),
		Rect2(Vector2(702, 154), Vector2(134, 108))
	]
	for block in main_blocks:
		var scaled_rect := Rect2(_scale_point(block.position), _scale_size(block.size))
		draw_rect(scaled_rect, city_fill, true)
		draw_rect(scaled_rect, city_stroke, false, 1.4)
	_draw_city_grid(Rect2(Vector2(654, 198), Vector2(180, 210)))
	_draw_city_grid(Rect2(Vector2(702, 154), Vector2(134, 108)))

	var upper_blocks := [
		Rect2(Vector2(548, 66), Vector2(94, 94)),
		Rect2(Vector2(572, 88), Vector2(58, 52))
	]
	for block in upper_blocks:
		var scaled_rect := Rect2(_scale_point(block.position), _scale_size(block.size))
		draw_rect(scaled_rect, Color(0.34, 0.34, 0.34, 0.64), true)
		draw_rect(scaled_rect, Color(0.26, 0.26, 0.26, 0.50), false, 1.2)


func _draw_city_grid(design_rect: Rect2) -> void:
	var step_x := 18.0
	var step_y := 20.0
	var line_color := Color(0.56, 0.56, 0.56, 0.32)
	var x := design_rect.position.x + 8.0
	while x < design_rect.end.x:
		_draw_polyline([Vector2(x, design_rect.position.y), Vector2(x, design_rect.end.y)], line_color, 1.0)
		x += step_x
	var y := design_rect.position.y + 8.0
	while y < design_rect.end.y:
		_draw_polyline([Vector2(design_rect.position.x, y), Vector2(design_rect.end.x, y)], line_color, 1.0)
		y += step_y


func _draw_roads() -> void:
	_draw_polyline(
		[Vector2(540, 14), Vector2(564, 86), Vector2(618, 178), Vector2(696, 258), Vector2(858, 520)],
		Color(0.16, 0.16, 0.16, 0.84),
		5.0
	)
	_draw_polyline(
		[Vector2(18, 472), Vector2(108, 520), Vector2(210, 538)],
		Color(0.16, 0.16, 0.16, 0.74),
		4.0
	)
	_draw_polyline(
		[Vector2(0, 206), Vector2(180, 226), Vector2(374, 226), Vector2(610, 226), Vector2(920, 212)],
		Color(0.82, 0.82, 0.82, 0.74),
		7.0
	)
	_draw_polyline(
		[Vector2(0, 374), Vector2(182, 356), Vector2(392, 352), Vector2(610, 362), Vector2(920, 378)],
		Color(0.80, 0.80, 0.80, 0.68),
		6.0
	)


func _draw_blue_control_zones() -> void:
	_draw_hatched_blob(
		[Vector2(706, 96), Vector2(762, 70), Vector2(812, 102), Vector2(784, 194), Vector2(730, 212), Vector2(688, 162)],
		Color(0.12, 0.22, 0.52, 0.20),
		Color(0.16, 0.30, 0.78, 0.74)
	)
	_draw_hatched_blob(
		[Vector2(300, 380), Vector2(356, 366), Vector2(404, 392), Vector2(372, 448), Vector2(296, 434)],
		Color(0.12, 0.22, 0.52, 0.20),
		Color(0.16, 0.30, 0.78, 0.74)
	)
	_draw_polyline([Vector2(430, 296), Vector2(548, 292), Vector2(646, 298)], Color(0.20, 0.34, 0.72, 0.56), 2.2)


func _draw_red_tactical_marks() -> void:
	_draw_dashed_circle(Vector2(604, 116), 66.0, Color(0.78, 0.22, 0.24, 0.78), 2.4)
	_draw_dashed_arc(Vector2(760, 288), 84.0, Color(0.78, 0.22, 0.24, 0.84), 2.8)
	_draw_arrow(Vector2(66, 454), Vector2(28, 520), Color(0.82, 0.18, 0.18, 0.86), 4.6)
	_draw_arrow(Vector2(324, 430), Vector2(324, 500), Color(0.16, 0.28, 0.78, 0.84), 3.8)
	_draw_arrow(Vector2(742, 350), Vector2(792, 402), Color(0.82, 0.20, 0.20, 0.86), 3.8)
	_draw_polyline([Vector2(728, 272), Vector2(820, 266)], Color(0.80, 0.18, 0.18, 0.82), 3.0)
	_draw_polyline([Vector2(700, 286), Vector2(690, 282)], Color(0.78, 0.22, 0.22, 0.74), 3.0)
	_draw_polyline([Vector2(706, 298), Vector2(696, 294)], Color(0.78, 0.22, 0.22, 0.74), 3.0)
	_draw_polyline([Vector2(714, 310), Vector2(704, 306)], Color(0.78, 0.22, 0.22, 0.74), 3.0)
	_draw_dashed_circle(Vector2(704, 258), 18.0, Color(0.80, 0.20, 0.22, 0.74), 1.8)
	_draw_dashed_circle(Vector2(662, 98), 9.0, Color(0.80, 0.20, 0.22, 0.74), 1.8)


func _draw_border() -> void:
	var frame := Rect2(_scale_point(Vector2(10, 10)), _scale_size(Vector2(900, 540)))
	draw_rect(frame, Color(0.20, 0.20, 0.20, 0.68), false, 2.0)


func _map_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return min(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)


func _map_offset(scale: float) -> Vector2:
	var content := DESIGN_SIZE * scale
	return (size - content) * 0.5


func _scale_point(point: Vector2) -> Vector2:
	var scale := _map_scale()
	return _map_offset(scale) + (point * scale)


func _scale_size(value: Vector2) -> Vector2:
	return value * _map_scale()


func _draw_polyline(points: Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(_scale_point(point))
	draw_polyline(scaled, color, width, true)


func _draw_vertical_gradient(rect: Rect2, top_color: Color, bottom_color: Color, steps: int = 12) -> void:
	if steps <= 0:
		draw_rect(rect, top_color, true)
		return
	var step_height := rect.size.y / float(steps)
	for i in range(steps):
		var t := float(i) / float(max(1, steps - 1))
		var color := top_color.lerp(bottom_color, t)
		var band := Rect2(
			Vector2(rect.position.x, rect.position.y + (float(i) * step_height)),
			Vector2(rect.size.x, step_height + 1.0)
		)
		draw_rect(band, color, true)


func _draw_soft_disc(center: Vector2, radius: float, color: Color) -> void:
	var scaled_center := _scale_point(center)
	var scaled_radius := radius * _map_scale()
	draw_circle(scaled_center, scaled_radius, color)
	draw_circle(scaled_center, scaled_radius * 0.64, Color(color.r, color.g, color.b, color.a * 0.72))


func _draw_dashed_circle(center: Vector2, radius: float, color: Color, width: float) -> void:
	var segments := 24
	var radius_scale := _map_scale()
	for i in range(segments):
		if i % 2 == 1:
			continue
		var start_angle := float(i) / float(segments) * TAU
		var end_angle := float(i + 1) / float(segments) * TAU
		draw_arc(_scale_point(center), radius * radius_scale, start_angle, end_angle, 8, color, width)


func _draw_dashed_arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	var radius_scale := _map_scale()
	for i in range(14):
		if i % 2 == 0:
			continue
		var start_angle := PI * 0.16 + (float(i) * 0.12)
		var end_angle := start_angle + 0.08
		draw_arc(_scale_point(center), radius * radius_scale, start_angle, end_angle, 8, color, width)


func _draw_hatched_blob(points: Array, fill_color: Color, line_color: Color) -> void:
	if points.size() < 3:
		return
	var poly := PackedVector2Array()
	var scaled_points: Array[Vector2] = []
	for point in points:
		var scaled := _scale_point(point)
		scaled_points.append(scaled)
		poly.append(scaled)
	draw_colored_polygon(poly, fill_color)
	_draw_polyline(points + [points[0]], line_color, 2.4)
	var bounds := Rect2(scaled_points[0], Vector2.ZERO)
	for p in scaled_points:
		bounds = bounds.expand(p)
	var x := bounds.position.x - bounds.size.y
	while x < bounds.end.x + bounds.size.y:
		_draw_clipped_line(Vector2(x, bounds.position.y), Vector2(x + bounds.size.y, bounds.end.y), line_color, 1.3)
		x += 12.0


func _draw_arrow(from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var from_scaled := _scale_point(from_point)
	var to_scaled := _scale_point(to_point)
	_draw_clipped_line(from_scaled, to_scaled, color, width)
	var dir := (to_scaled - from_scaled).normalized()
	if dir == Vector2.ZERO:
		return
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([
		to_scaled,
		to_scaled - (dir * 16.0) + (side * 8.0),
		to_scaled - (dir * 16.0) - (side * 8.0)
	])
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
