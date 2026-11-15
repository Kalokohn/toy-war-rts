extends Node3D
## De wereld en de simulatie.
##
## Netwerkmodel: de host is de server en de enige die de simulatie draait.
## - Clients sturen commando's (cmd_*) naar de server via RPC.
## - De server maakt/verwijdert entities met betrouwbare RPC's (_rpc_spawn/_rpc_despawn).
## - Tien keer per seconde stuurt de server een snapshot met de staat van alles.
## Singleplayer gebruikt precies hetzelfde pad met een OfflineMultiplayerPeer.

const Entity := preload("res://scripts/game/entity.gd")
const RTSCamera := preload("res://scripts/game/rts_camera.gd")
const PlayerController := preload("res://scripts/game/player_controller.gd")
const Hud := preload("res://scripts/game/hud.gd")

const SNAPSHOT_INTERVAL := 0.1
const SNAPSHOT_CHUNK := 12
const START_POSITIONS := [Vector3(-70, 0, -70), Vector3(70, 0, 70), Vector3(70, 0, -70), Vector3(-70, 0, 70)]
## Resources rond elke startpositie: [type, afstand richting midden, afstand opzij]
const START_RESOURCES := [
	["plastic", 4.0, 13.0], ["plastic", 8.5, 12.5],
	["blocks", 2.0, -15.0], ["blocks", 6.0, -16.0], ["blocks", 10.0, -14.0], ["blocks", -2.0, -16.5],
	["batteries", 17.0, 4.0], ["marbles", 17.0, -4.0],
]

signal entity_removed(id: int)
signal world_ready

var entities := {}          # id -> Entity
var stocks := {}            # slot -> {resource: int, "pop": int, "cap": int}
var my_slot := 0
var my_faction := "soldiers"
var factions := {}          # slot -> faction id
var world_started := false

var cam_rig: Node3D
var camera: Camera3D
var hud: CanvasLayer
var controller: Node

var _next_id := 1
var _ready_peers := {}
var _snap_timer := 0.0
var _statics: Array = []


func _ready() -> void:
	my_slot = Net.my_slot()
	for slot in GameData.MAX_PLAYERS:
		factions[slot] = Net.get_faction(slot)
	my_faction = factions[my_slot]
	for slot in GameData.MAX_PLAYERS:
		var s: Dictionary = GameData.START_RESOURCES.duplicate()
		s["pop"] = 0
		s["cap"] = 0
		stocks[slot] = s
	_build_environment()

	cam_rig = RTSCamera.new()
	add_child(cam_rig)
	camera = cam_rig.camera
	cam_rig.focus(START_POSITIONS[my_slot] * 0.9)

	hud = Hud.new()
	controller = PlayerController.new()
	hud.game = self
	hud.controller = controller
	controller.game = self
	controller.hud = hud
	add_child(hud)
	add_child(controller)

	if multiplayer.is_server():
		Net.players_changed.connect(_check_all_ready)
		_ready_peers[1] = true
		_check_all_ready()
	else:
		_client_ready.rpc_id(1)


# --- Opstarten -------------------------------------------------------------

@rpc("any_peer", "reliable")
func _client_ready() -> void:
	if multiplayer.is_server():
		_ready_peers[multiplayer.get_remote_sender_id()] = true
		_check_all_ready()


func _check_all_ready() -> void:
	if world_started:
		return
	for p in Net.players:
		if not _ready_peers.has(p):
			return
	_setup_world()


func _setup_world() -> void:
	world_started = true
	for p in Net.players:
		var slot := int(Net.players[p]["slot"])
		var start: Vector3 = START_POSITIONS[slot]
		var dir := -start.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var fd := GameData.faction_data(factions[slot])
		spawn_entity("building", fd["hq"], slot, start)
		for i in 3:
			spawn_entity("unit", fd["worker"], slot, start + dir * 6.5 + side * (i - 1) * 1.4)
		for r in START_RESOURCES:
			spawn_entity("resource", r[0], -1, (start + dir * r[1] + side * r[2]).round())
	# Gedeelde resources in het midden van de kaart
	for i in 8:
		var a := TAU * i / 8.0
		spawn_entity("resource", "batteries" if i % 2 == 0 else "marbles", -1, Vector3(cos(a), 0, sin(a)) * 16.0)
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		spawn_entity("resource", "blocks" if i % 2 == 0 else "plastic", -1, Vector3(cos(a), 0, sin(a)) * 32.0)
	_update_pop()
	_rpc_world_ready.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_world_ready() -> void:
	world_ready.emit()


# --- Entities aanmaken/verwijderen ------------------------------------------

## Alleen op de server aanroepen.
func spawn_entity(kind: String, type: String, slot: int, pos: Vector3, progress := 1.0) -> Node3D:
	var id := _next_id
	_next_id += 1
	_rpc_spawn.rpc(id, kind, type, slot, pos.x, pos.z, progress)
	return entities.get(id)


func despawn(id: int) -> void:
	if entities.has(id):
		_rpc_despawn.rpc(id)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn(id: int, kind: String, type: String, slot: int, x: float, z: float, progress: float) -> void:
	var e := Entity.new()
	e.setup(id, kind, type, slot, Vector3(x, 0, z), progress)
	entities[id] = e
	add_child(e)


@rpc("authority", "call_local", "reliable")
func _rpc_despawn(id: int) -> void:
	var e = entities.get(id)
	if e == null:
		return
	e.dead = true
	entities.erase(id)
	e.queue_free()
	entity_removed.emit(id)


@rpc("authority", "unreliable_ordered")
func _rpc_snapshot(data: Array, new_stocks: Dictionary) -> void:
	for item in data:
		var e = entities.get(item[0])
		if e:
			e.unpack(item)
	stocks = new_stocks


# --- Commando's (client -> server) ------------------------------------------

func _sender_slot() -> int:
	var sid := multiplayer.get_remote_sender_id()
	if sid == 0:
		sid = multiplayer.get_unique_id()
	return Net.get_slot(sid)


func _own_units(ids: Array, slot: int) -> Array:
	var out := []
	for id in ids:
		var e = entities.get(int(id))
		if e and not e.dead and e.kind == "unit" and e.owner_slot == slot:
			out.append(e)
	return out


@rpc("any_peer", "call_local", "reliable")
func cmd_move(ids: Array, target: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var units := _own_units(ids, _sender_slot())
	var offsets := _formation(units.size())
	for i in units.size():
		var u = units[i]
		u.state = "move"
		u.target_id = 0
		u.move_target = _clamp_map(target + offsets[i])


## Rechtsklik op een entity: verzamelen, bouwen, inleveren of aanvallen.
@rpc("any_peer", "call_local", "reliable")
func cmd_target(ids: Array, target_id: int) -> void:
	if not multiplayer.is_server():
		return
	var slot := _sender_slot()
	var t = entities.get(target_id)
	if t == null or t.dead:
		return
	for u in _own_units(ids, slot):
		var ud: Dictionary = GameData.UNITS[u.type]
		if t.kind == "resource":
			if ud.get("can_gather", false):
				u.state = "gather"
				u.target_id = t.id
				u.gather_type = t.type
			else:
				_order_move(u, _approach_point(t, u.position))
		elif t.owner_slot == slot:
			if t.kind == "building" and not t.complete and ud.get("can_build", false):
				u.state = "build"
				u.target_id = t.id
			elif t.is_dropoff() and u.carry_amount > 0:
				u.state = "return"
			else:
				_order_move(u, _approach_point(t, u.position))
		elif ud["damage"] > 0:
			u.state = "attack"
			u.target_id = t.id


@rpc("any_peer", "call_local", "reliable")
func cmd_build(ids: Array, btype: String, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var slot := _sender_slot()
	if slot < 0 or not GameData.can_build_type(factions[slot], btype):
		return
	var workers := _own_units(ids, slot).filter(func(u): return GameData.UNITS[u.type].get("can_build", false))
	if workers.is_empty():
		return
	pos = snap_build_pos(pos)
	var cost: Dictionary = GameData.BUILDINGS[btype]["cost"]
	if not can_place(btype, pos) or not GameData.can_afford(stocks[slot], cost):
		return
	GameData.pay(stocks[slot], cost)
	var b := spawn_entity("building", btype, slot, pos, 0.0)
	for w in workers:
		w.state = "build"
		w.target_id = b.id


@rpc("any_peer", "call_local", "reliable")
func cmd_train(building_id: int, utype: String) -> void:
	if not multiplayer.is_server():
		return
	var slot := _sender_slot()
	var b = entities.get(building_id)
	if b == null or b.dead or b.kind != "building" or b.owner_slot != slot or not b.complete:
		return
	if not utype in GameData.BUILDINGS[b.type].get("trains", []) or b.queue.size() >= 5:
		return
	var ud: Dictionary = GameData.UNITS[utype]
	if pop_used(slot) + ud["pop"] > pop_cap(slot) or not GameData.can_afford(stocks[slot], ud["cost"]):
		return
	GameData.pay(stocks[slot], ud["cost"])
	b.queue.append(utype)


@rpc("any_peer", "call_local", "reliable")
func cmd_rally(ids: Array, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var slot := _sender_slot()
	for id in ids:
		var b = entities.get(int(id))
		if b and b.kind == "building" and b.owner_slot == slot:
			b.rally = _clamp_map(pos)
			b.has_rally = true


@rpc("any_peer", "call_local", "reliable")
func cmd_stop(ids: Array) -> void:
	if not multiplayer.is_server():
		return
	for u in _own_units(ids, _sender_slot()):
		u.state = "idle"
		u.target_id = 0


# --- Gedeelde regels (server en client) --------------------------------------

func snap_build_pos(pos: Vector3) -> Vector3:
	return Vector3(round(pos.x), 0, round(pos.z))


func can_place(btype: String, pos: Vector3) -> bool:
	var h: float = GameData.BUILDINGS[btype]["size"] * 0.5
	var lim := GameData.MAP_HALF - 2.0
	if absf(pos.x) + h > lim or absf(pos.z) + h > lim:
		return false
	for e in entities.values():
		if e.dead or e.kind == "unit":
			continue
		var oh: float = e.half if e.kind == "building" else e.radius
		if absf(e.position.x - pos.x) < h + oh + 0.5 and absf(e.position.z - pos.z) < h + oh + 0.5:
			return false
	return true


func pop_used(slot: int) -> int:
	var n := 0
	for e in entities.values():
		if e.dead or e.owner_slot != slot:
			continue
		if e.kind == "unit":
			n += GameData.UNITS[e.type]["pop"]
		elif e.kind == "building":
			for q in e.queue:
				n += GameData.UNITS[q]["pop"]
	return n


func pop_cap(slot: int) -> int:
	var n := 0
	for e in entities.values():
		if not e.dead and e.kind == "building" and e.owner_slot == slot and e.complete:
			n += GameData.BUILDINGS[e.type].get("pop", 0)
	return mini(n, GameData.POP_MAX)


# --- Simulatie (alleen server) ----------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or not world_started:
		return
	var list := entities.values()
	_statics = list.filter(func(e): return e.kind != "unit" and not e.dead)
	var units := []
	for e in list:
		if e.dead:
			continue
		if e.kind == "unit":
			units.append(e)
			_sim_unit(e, delta)
		elif e.kind == "building":
			_sim_building(e, delta)
	_resolve_collisions(units)
	for e in list:
		if not e.dead and e.kind != "resource" and e.hp <= 0:
			despawn(e.id)

	_snap_timer += delta
	if _snap_timer >= SNAPSHOT_INTERVAL:
		_snap_timer = 0.0
		_update_pop()
		if multiplayer.get_peers().size() > 0:
			# In stukjes, zodat elk pakketje onder de MTU blijft.
			var data := []
			for e in entities.values():
				if not e.dead:
					data.append(e.pack())
					if data.size() >= SNAPSHOT_CHUNK:
						_rpc_snapshot.rpc(data, stocks)
						data = []
			if data.size() > 0:
				_rpc_snapshot.rpc(data, stocks)


func _update_pop() -> void:
	for slot in GameData.MAX_PLAYERS:
		stocks[slot]["pop"] = pop_used(slot)
		stocks[slot]["cap"] = pop_cap(slot)


func _sim_unit(u, delta: float) -> void:
	var ud: Dictionary = GameData.UNITS[u.type]
	u.cooldown = maxf(u.cooldown - delta, 0.0)
	u.moving = false
	var regen: float = GameData.faction_data(factions[u.owner_slot])["regen"]
	if regen > 0.0 and u.hp < u.max_hp:
		u.hp = minf(u.hp + regen * delta, u.max_hp)
	match u.state:
		"idle":
			if ud["sight"] > 0.0:
				var enemy = _nearest_enemy(u.owner_slot, u.position, ud["sight"])
				if enemy:
					u.state = "attack"
					u.target_id = enemy.id
		"move":
			if _move_towards(u, u.move_target, 0.3, delta):
				u.state = "idle"
		"gather":
			_sim_gather(u, ud, delta)
		"return":
			_sim_return(u, delta)
		"build":
			_sim_build(u, delta)
		"attack":
			_sim_attack(u, ud, delta)


func _sim_gather(u, ud: Dictionary, delta: float) -> void:
	var r = entities.get(u.target_id)
	if r == null or r.dead or r.kind != "resource":
		r = _nearest_resource(u.gather_type, u.position, 25.0)
		if r == null:
			u.state = "return" if u.carry_amount > 0 else "idle"
			return
		u.target_id = r.id
	if u.carry_amount > 0 and u.carry_type != r.type:
		u.carry_amount = 0   # Andere resource: wat je droeg laat je vallen (zoals in AOE)
	u.gather_type = r.type
	if u.carry_amount >= ud["carry"]:
		u.state = "return"
		return
	if r.distance_to_edge(u.position) > u.radius + 0.6:
		_move_towards(u, r.position, 0.0, delta, r.id)
		return
	_face(u, r.position)
	u.work_timer += delta * ud["gather_rate"]
	while u.work_timer >= 1.0:
		u.work_timer -= 1.0
		r.amount -= 1
		u.carry_amount += 1
		u.carry_type = r.type
		if r.amount <= 0:
			despawn(r.id)
			break
		if u.carry_amount >= ud["carry"]:
			break


func _sim_return(u, delta: float) -> void:
	if u.carry_amount <= 0:
		u.state = "gather"
		return
	var dp = _nearest_dropoff(u.owner_slot, u.position)
	if dp == null:
		u.state = "idle"
		return
	if dp.distance_to_edge(u.position) > u.radius + 0.6:
		_move_towards(u, dp.position, 0.0, delta, dp.id)
		return
	stocks[u.owner_slot][u.carry_type] += u.carry_amount
	u.carry_amount = 0
	u.state = "gather"


func _sim_build(u, delta: float) -> void:
	var b = entities.get(u.target_id)
	if b == null or b.dead or b.kind != "building" or b.owner_slot != u.owner_slot or b.complete:
		u.state = "idle"
		return
	if b.distance_to_edge(u.position) > u.radius + 0.6:
		_move_towards(u, b.position, 0.0, delta, b.id)
		return
	_face(u, b.position)
	var bt: float = GameData.BUILDINGS[b.type]["build_time"]
	b.progress = minf(b.progress + delta / bt, 1.0)
	b.hp = minf(b.hp + b.max_hp * 0.9 * delta / bt, b.max_hp)
	if b.progress >= 1.0:
		b.complete = true
		# Na een opslagkist meteen gaan verzamelen bij de dichtstbijzijnde bron.
		if b.is_dropoff():
			var r = _nearest_resource("", b.position, 15.0)
			if r:
				u.state = "gather"
				u.target_id = r.id
				u.gather_type = r.type
				return
		u.state = "idle"


func _sim_attack(u, ud: Dictionary, delta: float) -> void:
	var t = entities.get(u.target_id)
	if t == null or t.dead or t.kind == "resource" or t.owner_slot == u.owner_slot:
		u.state = "idle"
		return
	if t.distance_to_edge(u.position) > u.radius + ud["range"]:
		_move_towards(u, t.position, 0.0, delta, t.id)
		return
	_face(u, t.position)
	if u.cooldown <= 0.0:
		u.cooldown = ud["cooldown"]
		_damage(t, ud["damage"] * ud.get("bonus", {}).get(t.kind, 1.0), u)


func _damage(t, amount: float, attacker) -> void:
	t.hp -= amount
	# Units die niks doen slaan terug.
	if t.kind == "unit" and t.state == "idle" and GameData.UNITS[t.type]["damage"] > 0 and attacker and attacker.kind == "unit":
		t.state = "attack"
		t.target_id = attacker.id


func _sim_building(b, delta: float) -> void:
	if not b.complete:
		return
	var bd: Dictionary = GameData.BUILDINGS[b.type]
	if b.queue.size() > 0:
		b.train_timer += delta
		var ut: String = b.queue[0]
		if b.train_timer >= GameData.UNITS[ut]["train_time"]:
			b.train_timer = 0.0
			b.queue.pop_front()
			_spawn_trained(b, ut)
	if bd.has("damage"):
		b.cooldown = maxf(b.cooldown - delta, 0.0)
		if b.cooldown <= 0.0:
			var enemy = _nearest_enemy(b.owner_slot, b.position, bd["range"] + b.half, true)
			if enemy:
				b.cooldown = bd["cooldown"]
				_damage(enemy, bd["damage"], b)


func _spawn_trained(b, ut: String) -> void:
	var dir := Vector3(0, 0, 1)
	if b.has_rally:
		var d: Vector3 = b.rally - b.position
		d.y = 0
		if d.length() > 0.1:
			dir = d.normalized()
	var p: Vector3 = b.position + dir * (b.half + 1.0) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	var u := spawn_entity("unit", ut, b.owner_slot, p)
	if not b.has_rally:
		return
	if GameData.UNITS[ut].get("can_gather", false):
		var r = _nearest_resource("", b.rally, 2.5)
		if r:
			u.state = "gather"
			u.target_id = r.id
			u.gather_type = r.type
			return
	u.state = "move"
	u.move_target = b.rally


# --- Hulpjes voor de simulatie ----------------------------------------------

## Beweegt naar target. Geeft true terug als hij er is.
func _move_towards(u, target: Vector3, stop_dist: float, delta: float, ignore_id := 0) -> bool:
	var to: Vector3 = target - u.position
	to.y = 0
	var dist := to.length()
	if dist <= stop_dist or dist < 0.01:
		return true
	var dir := to / dist
	# Simpel om obstakels heen sturen (vervangen we later door een navmesh).
	for s in ([] if u.flying else _statics):
		if s.id == ignore_id:
			continue
		var rel: Vector3 = s.position - u.position
		rel.y = 0
		var ahead := rel.dot(dir)
		var sr: float = s.half * 1.3 if s.kind == "building" else s.radius
		if ahead <= 0.0 or ahead > 3.0 + sr or ahead > dist:
			continue
		var lateral := rel - dir * ahead
		var clear: float = sr + u.radius + 0.3
		var ll := lateral.length()
		if ll < clear:
			var away := -lateral / ll if ll > 0.01 else Vector3(-dir.z, 0, dir.x)
			dir = (dir + away * (1.0 - ll / clear) * 1.5).normalized()
	var speed: float = GameData.UNITS[u.type]["speed"]
	u.position += dir * minf(speed * delta, dist)
	u.rotation.y = atan2(dir.x, dir.z)
	u.moving = true
	return false


func _face(u, p: Vector3) -> void:
	var d: Vector3 = p - u.position
	if Vector2(d.x, d.z).length() > 0.01:
		u.rotation.y = atan2(d.x, d.z)


func _resolve_collisions(units: Array) -> void:
	var lim := GameData.MAP_HALF - 1.0
	for i in units.size():
		var a = units[i]
		for j in range(i + 1, units.size()):
			var b = units[j]
			if a.flying != b.flying:
				continue
			var d: Vector3 = b.position - a.position
			d.y = 0
			var min_d: float = a.radius + b.radius
			var dist2 := d.length_squared()
			if dist2 >= min_d * min_d:
				continue
			var dist := sqrt(dist2)
			var n := d / dist if dist > 0.001 else Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU)
			var push := (min_d - dist) * 0.5
			a.position -= n * push
			b.position += n * push
		if not a.flying:
			for s in _statics:
				_push_out(a, s)
		a.position.x = clampf(a.position.x, -lim, lim)
		a.position.z = clampf(a.position.z, -lim, lim)
		a.position.y = 0


func _push_out(u, s) -> void:
	if s.kind == "building":
		var h: float = s.half + u.radius
		var dx: float = u.position.x - s.position.x
		var dz: float = u.position.z - s.position.z
		if absf(dx) >= h or absf(dz) >= h:
			return
		if h - absf(dx) < h - absf(dz):
			u.position.x = s.position.x + (1.0 if dx >= 0 else -1.0) * h
		else:
			u.position.z = s.position.z + (1.0 if dz >= 0 else -1.0) * h
	else:
		var d: Vector3 = u.position - s.position
		d.y = 0
		var m: float = s.radius + u.radius
		if d.length() < m:
			if d.length() < 0.001:
				d = Vector3(1, 0, 0)
			u.position = s.position + d.normalized() * m


func _nearest_resource(rtype: String, pos: Vector3, max_dist: float):
	var best = null
	var best_d := max_dist
	for e in entities.values():
		if e.dead or e.kind != "resource" or (rtype != "" and e.type != rtype):
			continue
		var d: float = e.distance_to_edge(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_dropoff(slot: int, pos: Vector3):
	var best = null
	var best_d := INF
	for e in entities.values():
		if e.dead or e.owner_slot != slot or not e.is_dropoff():
			continue
		var d: float = e.distance_to_edge(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_enemy(slot: int, pos: Vector3, max_dist: float, units_only := false):
	var best = null
	var best_d := max_dist
	for e in entities.values():
		if e.dead or e.kind == "resource" or e.owner_slot == slot or e.owner_slot < 0:
			continue
		if units_only and e.kind != "unit":
			continue
		var d: float = e.distance_to_edge(pos)
		if d < best_d:
			best_d = d
			best = e
	return best


func _approach_point(t, from: Vector3) -> Vector3:
	var d: Vector3 = from - t.position
	d.y = 0
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	var r: float = t.half * 1.42 if t.kind == "building" else t.radius
	return t.position + d.normalized() * (r + 1.0)


func _formation(n: int) -> Array:
	var out := []
	if n == 0:
		return out
	var cols := int(ceil(sqrt(n)))
	var rows := int(ceil(float(n) / cols))
	for i in n:
		var r := floori(float(i) / cols)
		var c := i % cols
		out.append(Vector3((c - (cols - 1) / 2.0) * 1.3, 0, (r - (rows - 1) / 2.0) * 1.3))
	return out


func _clamp_map(p: Vector3) -> Vector3:
	var lim := GameData.MAP_HALF - 1.5
	return Vector3(clampf(p.x, -lim, lim), 0, clampf(p.z, -lim, lim))


func _order_move(u, p: Vector3) -> void:
	u.state = "move"
	u.target_id = 0
	u.move_target = _clamp_map(p)


# --- Omgeving: een kinderkamervloer -----------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.88, 0.85)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

	var size := GameData.MAP_HALF * 2.0 + 20.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	_static_mesh(plane, Color(0.66, 0.47, 0.3), Vector3.ZERO)
	# Planken in de houten vloer
	for i in range(-22, 23):
		var line := BoxMesh.new()
		line.size = Vector3(0.08, 0.01, size)
		_static_mesh(line, Color(0.5, 0.35, 0.22), Vector3(i * 5.0, 0.005, 0))
	# Speelkleed in het midden
	var rugs := [[36.0, Color(0.3, 0.45, 0.75)], [28.0, Color(0.92, 0.78, 0.35)], [26.0, Color(0.3, 0.45, 0.75)]]
	for i in rugs.size():
		var c := CylinderMesh.new()
		c.top_radius = rugs[i][0]
		c.bottom_radius = rugs[i][0]
		c.height = 0.04
		c.radial_segments = 64
		_static_mesh(c, rugs[i][1], Vector3(0, 0.02 + i * 0.01, 0))
	# Plinten rond de kamer
	for s in [-1, 1]:
		var wall := BoxMesh.new()
		wall.size = Vector3(size, 3, 1)
		_static_mesh(wall, Color(0.95, 0.95, 0.92), Vector3(0, 1.5, s * (GameData.MAP_HALF + 1.0)))
		var wall2 := BoxMesh.new()
		wall2.size = Vector3(1, 3, size)
		_static_mesh(wall2, Color(0.95, 0.95, 0.92), Vector3(s * (GameData.MAP_HALF + 1.0), 1.5, 0))


func _static_mesh(mesh: Mesh, color: Color, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = GameData.make_mat(color)
	mi.position = pos
	add_child(mi)
