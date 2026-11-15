extends Node
## Gevechtstest voor de Dino-regels (start met `-- --single --faction=dinos --combat-test`).
## Zet dino's en vijandelijke soldaatjes naast elkaar en controleert:
## T-rex wint van een geweerschutter, Triceratops doet dubbele schade aan
## gebouwen, Pteranodon vliegt over gebouwen heen en dino's genezen vanzelf.

var game: Node3D
var _t := 0.0
var _step := 0
var _ids := {}


func _process(delta: float) -> void:
	if not game.world_started:
		return
	_t += delta
	if _step == 0:
		_step = 1
		var c := Vector3(0, 0, 40)
		_ids["trex"] = game.spawn_entity("unit", "trex", 0, c).id
		_ids["rifle"] = game.spawn_entity("unit", "rifleman", 1, c + Vector3(4, 0, 0)).id
		_ids["trice"] = game.spawn_entity("unit", "triceratops", 0, c + Vector3(-20, 0, 0)).id
		_ids["barracks"] = game.spawn_entity("building", "barracks", 1, c + Vector3(-20, 0, 8)).id
		_ids["ptera"] = game.spawn_entity("unit", "pteranodon", 0, c + Vector3(20, 0, -8)).id
		_ids["raptor"] = game.spawn_entity("unit", "velociraptor", 0, c + Vector3(30, 0, 0)).id
		_ids["block"] = game.spawn_entity("building", "barracks", 1, c + Vector3(20, 0, 0)).id
		game.entities[_ids["raptor"]].hp = 20.0
		game.cmd_target([_ids["trice"]], _ids["barracks"])
		game.cmd_move([_ids["ptera"]], c + Vector3(20, 0, 8))   # recht over de barak heen
	elif _step == 1 and _t > 2.5 and not _ids.has("shot"):
		_ids["shot"] = 1
		var main := get_tree().current_scene
		if main.args.has("screenshot"):
			game.cam_rig.focus(Vector3(5, 0, 38))
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(main.args["screenshot"])
	elif _step == 1 and _t > 8.0:
		_step = 2
		var rifle_dead: bool = not game.entities.has(_ids["rifle"])
		var b = game.entities.get(_ids["barracks"])
		var b_lost: float = 800.0 - b.hp if b else 800.0
		var p = game.entities[_ids["ptera"]]
		var raptor_hp: float = game.entities[_ids["raptor"]].hp
		var ptera_ok: bool = p.position.distance_to(Vector3(20, 0, 48)) < 1.0
		print("COMBAT geweerschutter dood=%s, barak schade=%d, pteranodon over barak=%s, raptor hp 20 -> %.1f" % [rifle_dead, b_lost, ptera_ok, raptor_hp])
		var ok: bool = rifle_dead and b_lost >= 4 * 28 and ptera_ok and raptor_hp > 24.0
		print("COMBAT RESULTAAT: %s" % ("OK" if ok else "MISLUKT"))
		get_tree().quit(0 if ok else 1)
