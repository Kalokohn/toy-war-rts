extends Control
## Minikaart: de kamer van bovenaf met stipjes voor alles op de kaart en
## het camerabeeld als kader. Links klikken/slepen = camera verplaatsen,
## rechts klikken = geselecteerde units erheen sturen.

var game: Node3D
var controller: Node

var _t := 0.0
var _drag := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.1:
		_t = 0.0
		queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var h := GameData.MAP_HALF
	return Vector2((p.x + h) / (2.0 * h), (p.z + h) / (2.0 * h)) * size


func _to_world(m: Vector2) -> Vector3:
	var h := GameData.MAP_HALF
	var n := m / size
	return Vector3(n.x * 2.0 * h - h, 0, n.y * 2.0 * h - h)


func _draw() -> void:
	if game == null:
		return
	# Vloer en kleed
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.31, 0.16))
	var plank := size.x / (GameData.MAP_HALF * 2.0) * 4.0
	var x := 0.0
	var i := 0
	while x < size.x:
		if i % 2 == 0:
			draw_rect(Rect2(x, 0, plank, size.y), Color(0.56, 0.36, 0.19))
		x += plank
		i += 1
	var c := _to_map(Vector3.ZERO)
	var rr := 38.0 / (GameData.MAP_HALF * 2.0) * size.x
	draw_circle(c, rr, Color(0.36, 0.45, 0.62))
	draw_circle(c, rr * 0.92, Color(0.72, 0.5, 0.4))
	draw_circle(c, rr * 0.6, Color(0.82, 0.7, 0.45))
	draw_circle(c, rr * 0.3, Color(0.7, 0.42, 0.33))
	# Entities
	var ms := size.x / 220.0
	for e in game.entities.values():
		if e.dead:
			continue
		var p := _to_map(e.position)
		match e.kind:
			"resource":
				var col: Color = GameData.RESOURCE_COLORS[e.type]
				draw_rect(Rect2(p - Vector2(2.5, 2.5) * ms, Vector2(5, 5) * ms), col.darkened(0.1))
			"building":
				var s: float = e.half * 2.0 / (GameData.MAP_HALF * 2.0) * size.x
				s = maxf(s, 6.0 * ms)
				var pc := GameData.player_color(e.owner_slot)
				draw_rect(Rect2(p - Vector2(s, s) * 0.5 - Vector2(1, 1), Vector2(s, s) + Vector2(2, 2)), Color(0, 0, 0, 0.7))
				draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), pc.lightened(0.15))
			"unit":
				var pc := GameData.player_color(e.owner_slot)
				var rad := 2.6 * ms * (1.4 if e.radius > 0.8 else 1.0)
				draw_circle(p, rad + 1.0, Color(0, 0, 0, 0.7))
				draw_circle(p, rad, pc.lightened(0.35) if e.id in controller.selected else pc.lightened(0.1))
	# Camerakader: de vier schermhoeken op de vloer geprojecteerd.
	var cam: Camera3D = game.camera
	var vp := get_viewport().get_visible_rect().size
	var pts := PackedVector2Array()
	for sp in [Vector2(0, 0), Vector2(vp.x, 0), vp, Vector2(0, vp.y)]:
		pts.append(_to_map(controller.ground_point(sp)))
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.5), 3.0, true)
	draw_polyline(pts, Color(1.0, 0.95, 0.75), 1.5, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag = true
			game.cam_rig.focus(_to_world(event.position))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var units: Array = controller.own_units()
			if units.size() > 0:
				game.cmd_move.rpc_id(1, units.map(func(u): return u.id), _to_world(event.position))
			accept_event()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = false
	elif event is InputEventMouseMotion and _drag:
		game.cam_rig.focus(_to_world(event.position))
		accept_event()
