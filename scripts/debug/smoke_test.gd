extends Node
## Geautomatiseerde rooktest (start met `-- --smoke-test`).
## Elke speler geeft via de echte RPC-route commando's: verzamelen, worker
## trainen en een Lego-huisje bouwen. Daarna print hij een samenvatting en
## sluit af. Met `--screenshot=pad.png` maakt hij ook een schermafbeelding.

var game: Node3D
var _t := 0.0
var _step := 0
var _start_stock := {}


func _ready() -> void:
	if game.world_started:
		_step = 1
	else:
		game.world_ready.connect(func(): _step = 1)


func _process(delta: float) -> void:
	if _step == 0:
		return
	_t += delta
	var main := get_tree().current_scene
	if _step == 1 and _t > 1.0:
		_step = 2
		_start_stock = game.stocks[game.my_slot].duplicate()
		var fd := GameData.faction_data(game.my_faction)
		var workers := _mine(fd["worker"])
		print("SMOKE slot=%d start: entities=%d eigen workers=%d" % [game.my_slot, game.entities.size(), workers.size()])
		# Twee workers naar plastic, een bouwt een huisje.
		var plastic = _nearest_resource("plastic", workers[0].position)
		game.cmd_target.rpc_id(1, [workers[0].id, workers[1].id], plastic.id)
		var hq = _mine(fd["hq"])[0]
		var spot := _free_spot(_pop_building(), hq.position)
		game.cmd_build.rpc_id(1, [workers[2].id], _pop_building(), spot)
		game.cmd_train.rpc_id(1, hq.id, fd["worker"])
		# Camera en selectie zodat de screenshot iets laat zien.
		game.cam_rig.focus(hq.position.lerp(Vector3.ZERO, 0.08))
		game.controller.set_selection(workers)
	elif _step == 2 and _t > 14.0:
		_step = 3
		if main.args.has("screenshot"):
			var img := get_viewport().get_texture().get_image()
			img.save_png(main.args["screenshot"])
			print("SMOKE screenshot opgeslagen: ", main.args["screenshot"])
	elif _step == 3 and _t > float(main.args.get("smoke-seconds", "30")):
		_step = 4
		var s: Dictionary = game.stocks[game.my_slot]
		var fd := GameData.faction_data(game.my_faction)
		var houses := _mine(_pop_building())
		var workers := _mine(fd["worker"]).size()
		print("SMOKE slot=%d (%s) eind: plastic %d -> %d, blokjes %d -> %d, workers=%d, pop-gebouw klaar=%s, pop=%d/%d, entities=%d" % [
			game.my_slot, game.my_faction, _start_stock["plastic"], s["plastic"], _start_stock["blocks"], s["blocks"],
			workers, houses.size() > 0 and houses[0].complete, s["pop"], s["cap"], game.entities.size()])
		var ok: bool = s["plastic"] > _start_stock["plastic"] - 50 and houses.size() > 0 and houses[0].complete and workers == 4 and s["cap"] > 10
		print("SMOKE slot=%d RESULTAAT: %s" % [game.my_slot, "OK" if ok else "MISLUKT"])
		get_tree().quit(0 if ok else 1)


## Het eerste gebouw uit het bouwmenu dat populatie geeft.
func _pop_building() -> String:
	for item in GameData.faction_data(game.my_faction)["build_menu"]:
		if GameData.BUILDINGS[item[0]].get("pop", 0) > 0:
			return item[0]
	return ""


func _mine(type: String) -> Array:
	var out := []
	for e in game.entities.values():
		if e.owner_slot == game.my_slot and e.type == type:
			out.append(e)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func _nearest_resource(type: String, pos: Vector3):
	var best = null
	for e in game.entities.values():
		if e.kind == "resource" and e.type == type:
			if best == null or e.position.distance_to(pos) < best.position.distance_to(pos):
				best = e
	return best


func _free_spot(btype: String, near: Vector3) -> Vector3:
	var dir := -near.normalized()
	for d in range(9, 30, 2):
		for side in [-6, 0, 6]:
			var p: Vector3 = game.snap_build_pos(near + dir * d + Vector3(-dir.z, 0, dir.x) * side)
			if game.can_place(btype, p):
				return p
	return near
