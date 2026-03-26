extends Control

const DESIGN_SIZE := Vector2(920, 560)

var _event_markers: Array = []
var _highlight_marker: Dictionary = {}
var _highlight_target := Vector2.ZERO
var _map_id := ""
var _map_visual_profile := "ashen_sanctum"

func set_event_markers(markers: Array) -> void:
	_event_markers = markers.duplicate(true)
	queue_redraw()


func set_map_context(map_def: Dictionary) -> void:
	var next_map_id: String = String(map_def.get("id", ""))
	var next_profile: String = String(map_def.get("visual_profile", "ashen_sanctum"))
	if next_profile.is_empty():
		next_profile = "ashen_sanctum"
	if _map_id == next_map_id and _map_visual_profile == next_profile:
		return
	_map_id = next_map_id
	_map_visual_profile = next_profile
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
	var bg_color := Color(0.66, 0.66, 0.66, 1.0)
	if _map_visual_profile == "ruined_crossing":
		bg_color = Color(0.13, 0.12, 0.16, 1.0)
	elif _map_visual_profile == "ashen_sanctum":
		bg_color = Color(0.66, 0.66, 0.66, 1.0)
	draw_rect(rect, bg_color, true)
	_draw_profile_backdrop()
	_draw_profile_border()
	_draw_contours()
	_draw_city_blocks()
	_draw_roads_and_rivers()
	_draw_control_zones()
	_draw_profile_landmarks()
	_draw_profile_overlay_pattern()
	_draw_story_routes()
	_draw_marker_guides()
	_draw_hover_highlight()

func _scale_point(point: Vector2) -> Vector2:
	var scale := _map_scale()
	var offset := _map_offset(scale)
	return offset + (point * scale)


func _scale_size(value: Vector2) -> Vector2:
	return value * _map_scale()


func _map_scale() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 1.0
	return min(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)


func _map_offset(scale: float) -> Vector2:
	var content := DESIGN_SIZE * scale
	return (size - content) * 0.5

func _draw_contours() -> void:
	var contour_color := Color(0.40, 0.40, 0.40, 0.70)
	var contour_sets := []
	if _map_visual_profile == "ruined_crossing":
		contour_color = Color(0.52, 0.50, 0.57, 0.72)
		contour_sets = [
			[Vector2(44, 102), Vector2(170, 72), Vector2(304, 88), Vector2(402, 130), Vector2(452, 210), Vector2(398, 284), Vector2(272, 318), Vector2(138, 286), Vector2(68, 214)],
			[Vector2(498, 340), Vector2(582, 308), Vector2(690, 308), Vector2(778, 352), Vector2(832, 430), Vector2(786, 494), Vector2(662, 518), Vector2(544, 486), Vector2(486, 422)],
			[Vector2(650, 90), Vector2(742, 64), Vector2(840, 76), Vector2(892, 132), Vector2(870, 194), Vector2(778, 232), Vector2(684, 214), Vector2(632, 160)]
		]
	else:
		contour_sets = [
			[Vector2(78, 84), Vector2(116, 52), Vector2(202, 48), Vector2(286, 92), Vector2(350, 162), Vector2(322, 236), Vector2(226, 262), Vector2(132, 230), Vector2(78, 168)],
			[Vector2(94, 102), Vector2(150, 74), Vector2(226, 74), Vector2(294, 118), Vector2(316, 178), Vector2(270, 220), Vector2(194, 236), Vector2(126, 208), Vector2(94, 160)],
			[Vector2(112, 124), Vector2(164, 104), Vector2(222, 108), Vector2(272, 136), Vector2(280, 180), Vector2(238, 206), Vector2(178, 214), Vector2(128, 190), Vector2(112, 150)],
			[Vector2(128, 146), Vector2(172, 132), Vector2(212, 134), Vector2(244, 154), Vector2(242, 184), Vector2(210, 198), Vector2(170, 198), Vector2(138, 180), Vector2(128, 156)]
		]
	for contour in contour_sets:
		_draw_polyline(contour, contour_color, 2.0)

func _draw_city_blocks() -> void:
	if _map_visual_profile == "ruined_crossing":
		var bridge_fill := Color(0.30, 0.28, 0.30, 0.92)
		var bridge_stroke := Color(0.20, 0.18, 0.20, 0.95)
		var bridge_blocks := [
			Rect2(_scale_point(Vector2(96, 246)), _scale_size(Vector2(248, 72))),
			Rect2(_scale_point(Vector2(392, 236)), _scale_size(Vector2(188, 86))),
			Rect2(_scale_point(Vector2(648, 246)), _scale_size(Vector2(194, 72)))
		]
		for block in bridge_blocks:
			draw_rect(block, bridge_fill, true)
			draw_rect(block, bridge_stroke, false, 3.0)
		_draw_polyline([Vector2(344, 282), Vector2(392, 268)], Color(0.70, 0.30, 0.28, 0.92), 6.0)
		_draw_polyline([Vector2(580, 274), Vector2(648, 284)], Color(0.70, 0.30, 0.28, 0.92), 6.0)
		_draw_polyline([Vector2(132, 202), Vector2(166, 160), Vector2(214, 152)], Color(0.48, 0.46, 0.50, 0.6), 2.0)
		_draw_polyline([Vector2(746, 194), Vector2(786, 156), Vector2(842, 152)], Color(0.48, 0.46, 0.50, 0.6), 2.0)
		return

	var fill := Color(0.26, 0.26, 0.26, 0.88)
	var stroke := Color(0.18, 0.18, 0.18, 0.95)
	var blocks := [
		Rect2(_scale_point(Vector2(534, 68)), _scale_size(Vector2(84, 96))),
		Rect2(_scale_point(Vector2(650, 202)), _scale_size(Vector2(180, 224))),
		Rect2(_scale_point(Vector2(734, 182)), _scale_size(Vector2(120, 106)))
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
	if _map_visual_profile == "ruined_crossing":
		_draw_polyline([Vector2(0, 190), Vector2(172, 210), Vector2(392, 204), Vector2(612, 214), Vector2(920, 192)], Color(0.72, 0.78, 0.88, 0.82), 12.0)
		_draw_polyline([Vector2(0, 376), Vector2(182, 362), Vector2(390, 356), Vector2(618, 366), Vector2(920, 384)], Color(0.72, 0.78, 0.88, 0.82), 10.0)
		_draw_polyline([Vector2(84, 274), Vector2(840, 274)], Color(0.10, 0.10, 0.12, 0.92), 5.0)
		_draw_polyline([Vector2(204, 100), Vector2(284, 168), Vector2(332, 244)], Color(0.16, 0.16, 0.20, 0.88), 4.0)
		_draw_polyline([Vector2(708, 98), Vector2(640, 172), Vector2(586, 244)], Color(0.16, 0.16, 0.20, 0.88), 4.0)
		return

	_draw_polyline([Vector2(514, 14), Vector2(566, 66), Vector2(614, 176), Vector2(700, 260), Vector2(854, 514)], Color(0.12, 0.12, 0.12, 0.92), 5.0)
	_draw_polyline([Vector2(884, 0), Vector2(846, 78), Vector2(846, 202), Vector2(904, 292), Vector2(920, 418)], Color(0.82, 0.82, 0.82, 0.8), 7.0)
	_draw_polyline([Vector2(0, 476), Vector2(86, 560)], Color(0.86, 0.86, 0.86, 0.85), 8.0)

func _draw_control_zones() -> void:
	if _map_visual_profile == "ruined_crossing":
		_draw_dashed_circle(Vector2(216, 274), 94.0, Color(0.84, 0.36, 0.30, 0.82), 3.0)
		_draw_dashed_circle(Vector2(724, 274), 92.0, Color(0.84, 0.36, 0.30, 0.82), 3.0)
		_draw_hatched_blob([Vector2(432, 232), Vector2(516, 210), Vector2(606, 242), Vector2(598, 320), Vector2(456, 336)], Color(0.21, 0.22, 0.44, 0.24), Color(0.24, 0.34, 0.72, 0.78))
		_draw_arrow(Vector2(112, 276), Vector2(56, 276), Color(0.86, 0.20, 0.18, 0.88), 4.0)
		_draw_arrow(Vector2(802, 276), Vector2(864, 276), Color(0.86, 0.20, 0.18, 0.88), 4.0)
		_draw_arrow(Vector2(520, 154), Vector2(520, 206), Color(0.16, 0.28, 0.82, 0.88), 4.0)
		return

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
		if bool(marker.get("is_side_fixed", false)):
			color = Color(0.62, 0.90, 0.94, 0.86)
		if bool(marker.get("is_mainline", false)):
			color = Color(0.98, 0.82, 0.34, 0.96)
		var center := _scale_point(point)
		if bool(marker.get("is_ghost", false)):
			var ghost_radius := 15.0 if bool(marker.get("is_mainline", false)) else 12.0
			draw_arc(center, ghost_radius, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.78), 2.4)
			draw_arc(center, ghost_radius * 0.58, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.42), 1.6)
			continue
		if _map_visual_profile == "ruined_crossing":
			var diamond := PackedVector2Array([
				center + Vector2(0.0, -10.0),
				center + Vector2(10.0, 0.0),
				center + Vector2(0.0, 10.0),
				center + Vector2(-10.0, 0.0)
			])
			draw_colored_polygon(diamond, Color(color.r, color.g, color.b, 0.32))
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), color, 2.2, true)
			draw_circle(center, 2.8, color)
		else:
			draw_arc(center, 11.0, 0.0, TAU, 28, color, 3.0)
			draw_circle(center, 3.5, color)
		var guide_end := center + Vector2(0, 24)
		draw_line(center + Vector2(0, 12), guide_end, color, 2.0)


func _draw_story_routes() -> void:
	var mainline_markers := _sorted_story_markers(true)
	if mainline_markers.size() >= 1:
		_draw_story_route(
			mainline_markers,
			Color(0.98, 0.82, 0.34, 0.92),
			Color(0.98, 0.88, 0.58, 0.18),
			4.0,
			10.0,
			_story_route_origin(true, "mainline")
		)
	var side_routes: Dictionary = {}
	for marker_value in _event_markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		if not bool(marker.get("is_side_fixed", false)):
			continue
		var line_id: String = String(marker.get("line_id", ""))
		if line_id.is_empty():
			line_id = "side_fixed_misc"
		if not side_routes.has(line_id):
			side_routes[line_id] = []
		side_routes[line_id].append(marker)
	for line_id in side_routes.keys():
		var line_markers: Array = _sort_markers_by_progress(side_routes[line_id])
		if line_markers.size() < 1:
			continue
		_draw_story_route(
			line_markers,
			Color(0.62, 0.90, 0.94, 0.78),
			Color(0.60, 0.88, 0.92, 0.12),
			2.6,
			6.0,
			_story_route_origin(false, String(line_id))
		)


func _sorted_story_markers(mainline: bool) -> Array:
	var selected: Array = []
	for marker_value in _event_markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		if bool(marker.get("is_mainline", false)) != mainline:
			continue
		selected.append(marker)
	return _sort_markers_by_progress(selected)


func _sort_markers_by_progress(markers: Array) -> Array:
	var sorted: Array = markers.duplicate(true)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao: int = int(a.get("story_order", 999))
		var bo: int = int(b.get("story_order", 999))
		if ao != bo:
			return ao < bo
		var ax: float = float(a.get("x", 0.0))
		var bx: float = float(b.get("x", 0.0))
		if not is_equal_approx(ax, bx):
			return ax < bx
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	return sorted


func _draw_story_route(markers: Array, line_color: Color, glow_color: Color, width: float, halo_radius: float, origin: Vector2 = Vector2.ZERO) -> void:
	var scaled_points := PackedVector2Array()
	if origin != Vector2.ZERO:
		scaled_points.append(_scale_point(origin))
	for marker_value in markers:
		if typeof(marker_value) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = marker_value
		var center := _scale_point(Vector2(float(marker.get("x", 0.0)), float(marker.get("y", 0.0))))
		scaled_points.append(center)
	if scaled_points.size() < 2:
		return
	for point in scaled_points:
		draw_circle(point, halo_radius * _map_scale(), glow_color)
	draw_polyline(scaled_points, Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.24), width + 4.0, true)
	draw_polyline(scaled_points, line_color, width, true)
	for i in range(1, scaled_points.size()):
		var from_point: Vector2 = scaled_points[i - 1]
		var to_point: Vector2 = scaled_points[i]
		var dir := (to_point - from_point).normalized()
		if dir == Vector2.ZERO:
			continue
		var arrow_tip := to_point.lerp(from_point, 0.16)
		var side := Vector2(-dir.y, dir.x)
		var head := PackedVector2Array([
			arrow_tip,
			arrow_tip - dir * 14.0 + side * 7.0,
			arrow_tip - dir * 14.0 - side * 7.0
		])
		draw_colored_polygon(head, line_color)


func _story_route_origin(is_mainline: bool, line_id: String) -> Vector2:
	if _map_visual_profile == "ruined_crossing":
		if is_mainline:
			return Vector2(64, 44)
		return Vector2(812, 112) if line_id.contains("side") else Vector2(742, 120)
	if is_mainline:
		return Vector2(860, 78)
	return Vector2(164, 458) if line_id.contains("side") else Vector2(214, 438)


func _draw_hover_highlight() -> void:
	if _highlight_marker.is_empty():
		return
	var point := Vector2(float(_highlight_marker.get("x", 0.0)), float(_highlight_marker.get("y", 0.0)))
	var center := _scale_point(point)
	var color := Color(1.0, 0.94, 0.62, 0.92)
	if _map_visual_profile == "ruined_crossing":
		color = Color(0.76, 0.88, 1.0, 0.92)
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
		var start_angle := PI * 0.20 + float(i) * 0.12
		var end_angle := start_angle + 0.07
		draw_arc(_scale_point(center), radius * radius_scale, start_angle, end_angle, 8, color, width)

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


func _draw_profile_backdrop() -> void:
	if _map_visual_profile == "ruined_crossing":
		_draw_vertical_gradient(
			Rect2(Vector2.ZERO, size),
			Color(0.11, 0.10, 0.14, 0.55),
			Color(0.18, 0.19, 0.24, 0.35),
			20
		)
		_draw_soft_disc(Vector2(250, 112), 180.0, Color(0.50, 0.54, 0.66, 0.12))
		_draw_soft_disc(Vector2(742, 452), 210.0, Color(0.44, 0.48, 0.62, 0.10))
		_draw_soft_disc(Vector2(460, 286), 140.0, Color(0.34, 0.36, 0.48, 0.10))
		return
	_draw_vertical_gradient(
		Rect2(Vector2.ZERO, size),
		Color(0.74, 0.72, 0.68, 0.30),
		Color(0.58, 0.56, 0.54, 0.12),
		16
	)
	_draw_soft_disc(Vector2(610, 102), 170.0, Color(0.94, 0.86, 0.58, 0.16))
	_draw_soft_disc(Vector2(792, 312), 150.0, Color(0.96, 0.78, 0.54, 0.10))
	_draw_soft_disc(Vector2(256, 438), 140.0, Color(0.80, 0.88, 1.0, 0.08))


func _draw_profile_landmarks() -> void:
	if _map_visual_profile == "ruined_crossing":
		_draw_ruined_crossing_signature()
		return
	_draw_ashen_sanctum_signature()


func _draw_profile_border() -> void:
	if _map_visual_profile == "ruined_crossing":
		var steel := Color(0.62, 0.66, 0.78, 0.56)
		var warning := Color(0.84, 0.34, 0.30, 0.72)
		var frame := Rect2(_scale_point(Vector2(10, 10)), _scale_size(Vector2(900, 540)))
		draw_rect(frame, Color(0, 0, 0, 0), false, 2.4)
		_draw_polyline([Vector2(18, 42), Vector2(120, 42), Vector2(168, 20), Vector2(266, 20)], steel, 2.4)
		_draw_polyline([Vector2(654, 20), Vector2(754, 20), Vector2(804, 42), Vector2(902, 42)], steel, 2.4)
		_draw_polyline([Vector2(18, 520), Vector2(120, 520), Vector2(164, 538), Vector2(266, 538)], warning, 2.4)
		_draw_polyline([Vector2(654, 538), Vector2(754, 538), Vector2(804, 520), Vector2(902, 520)], warning, 2.4)
		return

	var holy := Color(0.82, 0.24, 0.22, 0.68)
	var frame_rect := Rect2(_scale_point(Vector2(14, 14)), _scale_size(Vector2(892, 532)))
	draw_rect(frame_rect, Color(0, 0, 0, 0), false, 2.2)
	_draw_polyline([Vector2(30, 24), Vector2(200, 24), Vector2(258, 10), Vector2(326, 24)], holy, 2.2)
	_draw_polyline([Vector2(594, 24), Vector2(662, 10), Vector2(720, 24), Vector2(890, 24)], holy, 2.2)
	_draw_polyline([Vector2(24, 532), Vector2(214, 532), Vector2(272, 548), Vector2(332, 532)], Color(0.92, 0.74, 0.46, 0.54), 2.2)
	_draw_polyline([Vector2(588, 532), Vector2(648, 548), Vector2(706, 532), Vector2(896, 532)], Color(0.92, 0.74, 0.46, 0.54), 2.2)


func _draw_profile_overlay_pattern() -> void:
	if _map_visual_profile == "ruined_crossing":
		var fog := Color(0.72, 0.76, 0.88, 0.16)
		for i in range(8):
			var x0 := 42.0 + (float(i) * 112.0)
			_draw_polyline(
				[Vector2(x0, 74), Vector2(x0 - 52.0, 132), Vector2(x0 - 86.0, 188)],
				fog,
				1.4
			)
		for j in range(7):
			var x1 := 106.0 + (float(j) * 118.0)
			_draw_polyline(
				[Vector2(x1, 370), Vector2(x1 + 58.0, 424), Vector2(x1 + 92.0, 486)],
				Color(0.64, 0.68, 0.80, 0.14),
				1.4
			)
		return

	var sanctum_center := Vector2(610, 92)
	for angle_step in range(10):
		var theta := deg_to_rad(-54.0 + (float(angle_step) * 12.0))
		var inner := sanctum_center + Vector2(cos(theta), sin(theta)) * 60.0
		var outer := sanctum_center + Vector2(cos(theta), sin(theta)) * 124.0
		_draw_polyline([inner, outer], Color(0.92, 0.48, 0.34, 0.32), 1.3)
	for ring_step in range(3):
		var radius := 136.0 + (float(ring_step) * 22.0)
		draw_arc(
			_scale_point(sanctum_center),
			radius * _map_scale(),
			deg_to_rad(-62.0),
			deg_to_rad(44.0),
			26,
			Color(0.92, 0.74, 0.46, 0.28),
			1.2
		)


func _draw_ruined_crossing_signature() -> void:
	var banner := Rect2(_scale_point(Vector2(22, 18)), _scale_size(Vector2(240, 54)))
	draw_rect(banner, Color(0.16, 0.15, 0.20, 0.86), true)
	draw_rect(banner, Color(0.58, 0.56, 0.64, 0.88), false, 2.0)
	_draw_polyline(
		[
			Vector2(36, 58), Vector2(72, 38), Vector2(108, 56), Vector2(146, 34),
			Vector2(182, 56), Vector2(218, 40), Vector2(246, 56)
		],
		Color(0.78, 0.78, 0.86, 0.82),
		2.0
	)
	_draw_polyline(
		[Vector2(126, 258), Vector2(170, 274), Vector2(216, 258), Vector2(262, 274), Vector2(308, 258)],
		Color(0.70, 0.34, 0.32, 0.86),
		3.0
	)
	_draw_polyline(
		[Vector2(640, 292), Vector2(686, 274), Vector2(732, 294), Vector2(776, 278), Vector2(820, 298)],
		Color(0.70, 0.34, 0.32, 0.86),
		3.0
	)


func _draw_ashen_sanctum_signature() -> void:
	var ring_center := _scale_point(Vector2(860, 78))
	var ring_radius := 34.0 * _map_scale()
	draw_circle(ring_center, ring_radius, Color(0.96, 0.90, 0.72, 0.16))
	draw_arc(ring_center, ring_radius, 0.0, TAU, 40, Color(0.82, 0.22, 0.24, 0.90), 2.4)
	draw_arc(ring_center, ring_radius * 0.62, 0.0, TAU, 32, Color(0.86, 0.36, 0.22, 0.86), 2.0)
	draw_line(ring_center + Vector2(-ring_radius, 0.0), ring_center + Vector2(ring_radius, 0.0), Color(0.82, 0.22, 0.24, 0.82), 1.6)
	draw_line(ring_center + Vector2(0.0, -ring_radius), ring_center + Vector2(0.0, ring_radius), Color(0.82, 0.22, 0.24, 0.82), 1.6)
	_draw_vertical_gradient(
		Rect2(_scale_point(Vector2(534, 18)), _scale_size(Vector2(218, 36))),
		Color(0.28, 0.24, 0.24, 0.42),
		Color(0.20, 0.18, 0.18, 0.16),
		8
	)


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
	draw_circle(scaled_center, scaled_radius * 0.62, Color(color.r, color.g, color.b, color.a * 0.75))


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
