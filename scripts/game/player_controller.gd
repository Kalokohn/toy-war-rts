extends Node
## Input van de lokale speler: selecteren, commando's geven, gebouwen plaatsen.
## Stuurt alles als commando naar de server; past zelf niks aan de wereld aan.

signal selection_changed

const DRAG_THRESHOLD := 6.0
const ToyModels := preload("res://scripts/visual/toy_models.gd")
const ToyMat := preload("res://scripts/visual/toy_mat.gd")

var game: Node3D
var hud: CanvasLayer
var selected: Array = []    # entity ids
var place_type := ""

var _dragging := false
var _drag_start := Vector2.ZERO
var _ghost: Node3D
var _ghost_ok := -1
var _marker: MeshInstance3D
var _marker_t := 0.0


func _ready() -> void:
	game.entity_removed.connect(_on_entity_removed)
	_ghost = Node3D.new()
	_ghost.visible = false
	game.add_child(_ghost)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	_marker = MeshInstance3D.new()
	_marker.mesh = torus
	_marker.material_override = GameData.make_mat(Color(0.3, 1.0, 0.3), true)
	_marker.visible = false
	game.add_child(_marker)


func _process(delta: float) -> void:
	if place_type != "":
		var p: Vector3 = game.snap_build_pos(ground_point(get_viewport().get_mouse_position()))
		_ghost.position = p
		var ok: bool = game.can_place(place_type, p)
		if int(ok) != _ghost_ok:
			_ghost_ok = int(ok)
			_tint_ghost(_ghost, ToyMat.ghost(Color(0.45, 1.0, 0.45, 0.5) if ok else Color(1.0, 0.3, 0.25, 0.5)))
	if _marker.visible:
		_marker_t += delta
		var s := maxf(1.0 - _marker_t * 2.0, 0.0)
		_marker.scale = Vector3(s, 0.3, s)
		_marker.visible = s > 0.0


# --- Hulpjes ---------------------------------------------------------------

func ground_point(screen: Vector2) -> Vector3:
	var cam: Camera3D = game.camera
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -from.y / dir.y
	return from + dir * t


func pick(screen: Vector2):
	var cam: Camera3D = game.camera
	var from := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var best = null
	var best_score := INF
	for e in game.entities.values():
		if e.dead:
			continue
		var c: Vector3 = e.position + Vector3(0, e.pick_height * 0.5, 0)
		var t := (c - from).dot(dir)
		if t < 0.0:
			continue
		var miss := (from + dir * t).distance_to(c)
		if miss > e.pick_radius:
			continue
		# Units winnen van gebouwen als ze allebei onder de muis zitten.
		var score := t + (0.0 if e.kind == "unit" else 1000.0)
		if score < best_score:
			best_score = score
			best = e
	return best


func selected_entities() -> Array:
	var out := []
	for id in selected:
		var e = game.entities.get(id)
		if e and not e.dead:
			out.append(e)
	return out


func own_units() -> Array:
	return selected_entities().filter(func(e): return e.kind == "unit" and e.owner_slot == game.my_slot)


func own_workers() -> Array:
	return own_units().filter(func(e): return GameData.UNITS[e.type].get("can_build", false))


func own_buildings() -> Array:
	return selected_entities().filter(func(e): return e.kind == "building" and e.owner_slot == game.my_slot)


func _ids(list: Array) -> Array:
	return list.map(func(e): return e.id)


func set_selection(list: Array) -> void:
	for e in selected_entities():
		e.set_selected(false, Color.WHITE)
	selected = _ids(list)
	for e in list:
		e.set_selected(true, _ring_color(e))
	selection_changed.emit()


func _ring_color(e) -> Color:
	if e.owner_slot < 0:
		return Color(1, 0.9, 0.3)
	if e.owner_slot == game.my_slot:
		return Color(0.3, 1, 0.3)
	return Color(1, 0.3, 0.3)


func _on_entity_removed(id: int) -> void:
	if id in selected:
		selected.erase(id)
		selection_changed.emit()


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if place_type != "":
					_try_place(event.shift_pressed)
					return
				_dragging = true
				_drag_start = event.position
			elif _dragging:
				_dragging = false
				hud.set_drag_rect(false, Rect2())
				_finish_select(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if place_type != "":
				cancel_place()
				return
			_command(event.position)
	elif event is InputEventMouseMotion and _dragging:
		if _drag_start.distance_to(event.position) > DRAG_THRESHOLD:
			hud.set_drag_rect(true, Rect2(_drag_start, event.position - _drag_start).abs())
	elif event is InputEventKey and event.pressed and not event.echo:
		_hotkey(event)


func _hotkey(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			if place_type != "":
				cancel_place()
			else:
				set_selection([])
		KEY_SPACE:
			for e in game.entities.values():
				if e.kind == "building" and e.type == GameData.faction_data(game.my_faction)["hq"] and e.owner_slot == game.my_slot:
					game.cam_rig.focus(e.position)
					return
		KEY_PERIOD:
			select_idle_worker()
		KEY_X:
			var units := own_units()
			if units.size() > 0:
				game.cmd_stop.rpc_id(1, _ids(units))
		KEY_Q:
			var bs := own_buildings()
			if bs.size() > 0:
				var trains: Array = GameData.BUILDINGS[bs[0].type].get("trains", [])
				if trains.size() > 0:
					train(trains[0])
		_:
			if own_workers().size() > 0:
				for item in GameData.faction_data(game.my_faction)["build_menu"]:
					if OS.get_keycode_string(event.keycode) == item[1]:
						start_place(item[0])


func _finish_select(end: Vector2, additive: bool) -> void:
	var list: Array = selected_entities() if additive else []
	if _drag_start.distance_to(end) <= DRAG_THRESHOLD:
		var e = pick(end)
		if e:
			if additive and e.id in selected:
				list.erase(e)
			elif not e in list:
				list.append(e)
	else:
		var rect := Rect2(_drag_start, end - _drag_start).abs()
		var cam: Camera3D = game.camera
		for e in game.entities.values():
			if e.dead or e.kind != "unit" or e.owner_slot != game.my_slot or e in list:
				continue
			var p: Vector3 = e.position + Vector3(0, e.pick_height * 0.5, 0)
			if not cam.is_position_behind(p) and rect.has_point(cam.unproject_position(p)):
				list.append(e)
	# Eigen units en andermans spul niet door elkaar selecteren.
	if list.size() > 1:
		var own := list.filter(func(x): return x.owner_slot == game.my_slot)
		if own.size() > 0:
			list = own
		var units := list.filter(func(x): return x.kind == "unit")
		if units.size() > 0:
			list = units
	set_selection(list)


func _command(screen: Vector2) -> void:
	var target = pick(screen)
	var ground := ground_point(screen)
	var units := own_units()
	if units.size() > 0:
		if target and not (target.kind == "unit" and target.owner_slot == game.my_slot):
			game.cmd_target.rpc_id(1, _ids(units), target.id)
		else:
			game.cmd_move.rpc_id(1, _ids(units), ground)
		_show_marker(target.position if target else ground)
		return
	var bs := own_buildings()
	if bs.size() > 0:
		game.cmd_rally.rpc_id(1, _ids(bs), target.position if target and target.kind == "resource" else ground)
		_show_marker(ground)


func _show_marker(p: Vector3) -> void:
	_marker.position = Vector3(p.x, 0.08, p.z)
	_marker_t = 0.0
	_marker.visible = true


# --- Acties vanuit de HUD ---------------------------------------------------

func start_place(btype: String) -> void:
	var cost: Dictionary = GameData.BUILDINGS[btype]["cost"]
	if not GameData.can_afford(game.stocks[game.my_slot], cost):
		hud.flash(GameData.missing_text(game.stocks[game.my_slot], cost))
		return
	place_type = btype
	for c in _ghost.get_children():
		c.queue_free()
	var model: Node3D = ToyModels.build(btype, GameData.player_color(game.my_slot), 1)["root"]
	_ghost.add_child(model)
	# Vierkant op de grond dat laat zien hoeveel ruimte het gebouw nodig heeft.
	var size: float = GameData.BUILDINGS[btype]["size"]
	var foot := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size + 1.0, size + 1.0)
	foot.mesh = pm
	foot.position.y = 0.08
	_ghost.add_child(foot)
	_ghost_ok = -1
	_ghost.visible = true


func _tint_ghost(n: Node, mat: Material) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			c.material_override = mat
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if c is Label3D or c is Light3D:
			c.visible = false
		_tint_ghost(c, mat)


func cancel_place() -> void:
	place_type = ""
	_ghost.visible = false


func _try_place(keep: bool) -> void:
	var workers := own_workers()
	if workers.is_empty():
		cancel_place()
		return
	var p: Vector3 = game.snap_build_pos(ground_point(get_viewport().get_mouse_position()))
	if not game.can_place(place_type, p):
		hud.flash("Hier kun je niet bouwen")
		return
	var cost: Dictionary = GameData.BUILDINGS[place_type]["cost"]
	if not GameData.can_afford(game.stocks[game.my_slot], cost):
		hud.flash(GameData.missing_text(game.stocks[game.my_slot], cost))
		cancel_place()
		return
	game.cmd_build.rpc_id(1, _ids(workers), place_type, p)
	if not keep:
		cancel_place()


func train(utype: String) -> void:
	var ud: Dictionary = GameData.UNITS[utype]
	var stock: Dictionary = game.stocks[game.my_slot]
	if not GameData.can_afford(stock, ud["cost"]):
		hud.flash(GameData.missing_text(stock, ud["cost"]))
		return
	if stock.get("pop", 0) + ud["pop"] > stock.get("cap", 0):
		hud.flash("Populatie vol: bouw een Lego-huisje")
		return
	# Kies het gebouw met de kortste wachtrij.
	var best = null
	for b in own_buildings():
		if b.complete and utype in GameData.BUILDINGS[b.type].get("trains", []):
			if best == null or b.queue.size() < best.queue.size():
				best = b
	if best:
		game.cmd_train.rpc_id(1, best.id, utype)


func select_idle_worker() -> void:
	var idle := []
	for e in game.entities.values():
		if e.kind == "unit" and e.owner_slot == game.my_slot and e.state == "idle" and GameData.UNITS[e.type].get("can_gather", false):
			idle.append(e)
	if idle.is_empty():
		return
	idle.sort_custom(func(a, b): return a.id < b.id)
	var pick_e = idle[0]
	for e in idle:
		if selected.size() == 1 and e.id > selected[0]:
			pick_e = e
			break
	set_selection([pick_e])
	game.cam_rig.focus(pick_e.position)
