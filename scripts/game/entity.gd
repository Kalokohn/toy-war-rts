extends Node3D
## Een ding in de wereld: unit, gebouw of resourcebron.
## De server past de velden aan in de simulatie; clients krijgen ze via
## snapshots binnen (pack/unpack) en schuiven er soepel naartoe.

var id := 0
var kind := ""          # "unit", "building", "resource"
var type := ""
var owner_slot := -1    # -1 = neutraal
var hp := 1.0
var max_hp := 1.0
var radius := 0.5
var half := 0.0         # halve breedte van een gebouw
var pick_radius := 1.0
var pick_height := 1.0
var dead := false

# Unit
var state := "idle"     # idle, move, gather, return, build, attack
var move_target := Vector3.ZERO
var target_id := 0
var gather_type := ""
var carry_type := ""
var carry_amount := 0
var work_timer := 0.0
var cooldown := 0.0
var moving := false

# Gebouw
var progress := 1.0
var complete := true
var queue: Array = []
var train_timer := 0.0
var train_ratio := 0.0
var rally := Vector3.ZERO
var has_rally := false

# Resource
var amount := 0

# Visueel
var net_pos := Vector3.ZERO
var net_rot := 0.0
var model: Node3D
var ring: MeshInstance3D
var label: Label3D
var carry_mesh: MeshInstance3D
var _shown_carry := ""
var _bob := 0.0


func setup(p_id: int, p_kind: String, p_type: String, p_owner: int, pos: Vector3, p_progress: float) -> void:
	id = p_id
	kind = p_kind
	type = p_type
	owner_slot = p_owner
	position = pos
	net_pos = pos
	name = "E%d" % id
	match kind:
		"unit":
			var d: Dictionary = GameData.UNITS[type]
			max_hp = d["hp"]
			hp = max_hp
			radius = d["radius"]
			pick_radius = 0.8
			pick_height = 1.6
		"building":
			var d: Dictionary = GameData.BUILDINGS[type]
			max_hp = d["hp"]
			half = d["size"] * 0.5
			radius = half
			progress = p_progress
			complete = progress >= 1.0
			hp = max_hp if complete else max_hp * 0.1
			pick_radius = half * 1.1
			pick_height = d["height"]
		"resource":
			var d: Dictionary = GameData.RESOURCE_NODES[type]
			amount = d["amount"]
			radius = d["radius"]
			pick_radius = radius * 1.2
			pick_height = d["height"]
	_build_visual()


func distance_to_edge(p: Vector3) -> float:
	if kind == "building":
		var dx := maxf(absf(p.x - position.x) - half, 0.0)
		var dz := maxf(absf(p.z - position.z) - half, 0.0)
		return sqrt(dx * dx + dz * dz)
	return maxf(Vector2(p.x - position.x, p.z - position.z).length() - radius, 0.0)


func is_dropoff() -> bool:
	return kind == "building" and complete and GameData.BUILDINGS[type].get("dropoff", false)


# --- Netwerk ---------------------------------------------------------------

func pack() -> Array:
	match kind:
		"unit":
			return [id, position.x, position.z, rotation.y, hp,
				GameData.RESOURCES.find(carry_type), carry_amount, 1 if moving else 0, state]
		"building":
			var ratio := 0.0
			if queue.size() > 0:
				ratio = train_timer / GameData.UNITS[queue[0]]["train_time"]
			return [id, hp, progress, queue.duplicate(), ratio]
	return [id, amount]


func unpack(a: Array) -> void:
	match kind:
		"unit":
			net_pos = Vector3(a[1], 0, a[2])
			net_rot = a[3]
			hp = a[4]
			carry_type = "" if a[5] < 0 else GameData.RESOURCES[a[5]]
			carry_amount = a[6]
			moving = a[7] == 1
			state = a[8]
		"building":
			hp = a[1]
			progress = a[2]
			complete = progress >= 1.0
			queue = a[3]
			train_ratio = a[4]
		"resource":
			amount = a[1]


# --- Visueel ---------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		var t := clampf(delta * 12.0, 0.0, 1.0)
		position = position.lerp(net_pos, t)
		rotation.y = lerp_angle(rotation.y, net_rot, t)
	match kind:
		"unit":
			if moving:
				_bob += delta * 14.0
				model.position.y = absf(sin(_bob)) * 0.12
			else:
				model.position.y = lerpf(model.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
			if carry_mesh:
				var want := carry_type if carry_amount > 0 else ""
				if want != _shown_carry:
					_shown_carry = want
					carry_mesh.visible = want != ""
					if want != "":
						carry_mesh.material_override = GameData.make_mat(GameData.RESOURCE_COLORS[want])
		"building":
			model.scale.y = 1.0 if complete else lerpf(0.15, 1.0, progress)
			if not complete:
				label.text = "Bouwen %d%%" % int(progress * 100.0)
			elif queue.size() > 0:
				var extra := "" if queue.size() == 1 else " (+%d)" % (queue.size() - 1)
				label.text = "%s %d%%%s" % [GameData.UNITS[queue[0]]["name"], int(train_ratio * 100.0), extra]
			else:
				label.text = ""


func set_selected(on: bool, color: Color) -> void:
	ring.visible = on
	if on:
		ring.material_override = GameData.make_mat(color, true)


func _build_visual() -> void:
	model = Node3D.new()
	add_child(model)
	var pc := GameData.player_color(owner_slot)
	match type:
		"worker":
			_soldier(pc)
			# Opwindsleutel op de rug
			_part(_cyl(0.04, 0.35), Color(0.85, 0.7, 0.2), Vector3(0, 0.85, -0.42), Vector3(90, 0, 0))
			_part(_box(Vector3(0.45, 0.16, 0.05)), Color(0.85, 0.7, 0.2), Vector3(0, 0.85, -0.6))
			carry_mesh = _part(_box(Vector3(0.32, 0.32, 0.32)), Color.WHITE, Vector3(0, 0.75, 0.38))
			carry_mesh.visible = false
		"rifleman":
			_soldier(pc)
			_part(_box(Vector3(0.07, 0.07, 0.85)), Color(0.2, 0.2, 0.2), Vector3(0.28, 0.85, 0.25))
		"hq":
			_part(_box(Vector3(8, 4, 8)), pc.lerp(Color.WHITE, 0.35), Vector3(0, 2, 0))
			_part(_box(Vector3(8.6, 0.6, 8.6)), pc.darkened(0.25), Vector3(0, 4.3, 0))
			_part(_box(Vector3(3, 3, 0.1)), Color(0.98, 0.85, 0.25), Vector3(0, 2.2, 4.01))
			_part(_box(Vector3(1.2, 1.2, 1.2)), Color(0.9, 0.25, 0.25), Vector3(-2.5, 5.2, -2))
			_part(_box(Vector3(1.2, 1.2, 1.2)), Color(0.25, 0.75, 0.3), Vector3(-1.1, 5.2, -2.3))
			_part(_box(Vector3(1.2, 1.2, 1.2)), Color(0.98, 0.85, 0.25), Vector3(-1.8, 6.4, -2.1))
			_flag(pc, Vector3(3.3, 4.6, 3.3))
		"storage":
			_part(_box(Vector3(4, 2.2, 4)), Color(0.55, 0.36, 0.2), Vector3(0, 1.1, 0))
			_part(_box(Vector3(4.06, 0.4, 4.06)), pc, Vector3(0, 1.2, 0))
			_part(_box(Vector3(4.2, 0.4, 4.2)), Color(0.42, 0.27, 0.15), Vector3(0, 2.4, 0))
		"house":
			_part(_box(Vector3(4, 2.4, 4)), pc, Vector3(0, 1.2, 0))
			for x in [-1, 1]:
				for z in [-1, 1]:
					_part(_cyl(0.6, 0.45), pc.lightened(0.1), Vector3(x, 2.62, z))
		"barracks":
			_part(_box(Vector3(6, 3, 6)), Color(0.55, 0.55, 0.35), Vector3(0, 1.5, 0))
			_part(_box(Vector3(6.4, 0.4, 6.4)), Color(0.4, 0.4, 0.25), Vector3(0, 3.2, 0))
			_part(_box(Vector3(1.6, 2, 0.1)), Color(0.2, 0.15, 0.1), Vector3(0, 1, 3.01))
			_flag(pc, Vector3(2.5, 3.4, 2.5))
		"tower":
			_part(_cyl(1.2, 6), Color(0.72, 0.72, 0.78), Vector3(0, 3, 0))
			_part(_box(Vector3(3, 0.8, 3)), pc, Vector3(0, 6.4, 0))
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_part(_sphere(0.35), GameData.RESOURCE_COLORS["marbles"], Vector3(cos(a) * 0.8, 7.1, sin(a) * 0.8))
		"plastic":
			_part(_box(Vector3(3, 1.6, 2)), Color(0.8, 0.2, 0.2), Vector3(0, 0.8, 0))
			_part(_box(Vector3(3.1, 0.3, 2.1)), Color(0.98, 0.85, 0.25), Vector3(0, 1.75, 0))
			_part(_sphere(0.4), Color(0.25, 0.5, 0.95), Vector3(0.6, 2.25, 0))
			_part(_box(Vector3(0.6, 0.6, 0.6)), Color(0.25, 0.75, 0.3), Vector3(-0.6, 2.2, 0.2), Vector3(0, 30, 0))
		"blocks":
			var rng := RandomNumberGenerator.new()
			rng.seed = id
			var colors := [Color(0.9, 0.25, 0.25), Color(0.25, 0.5, 0.95), Color(0.98, 0.85, 0.25), Color(0.25, 0.75, 0.3), Color(0.85, 0.55, 0.3)]
			for i in 8:
				var level := 0 if i < 4 else (1 if i < 7 else 2)
				var spread := 1.0 - level * 0.35
				var p := Vector3(rng.randf_range(-spread, spread), 0.45 + level * 0.9, rng.randf_range(-spread, spread))
				_part(_box(Vector3(0.9, 0.9, 0.9)), colors[rng.randi() % colors.size()], p, Vector3(0, rng.randf_range(0, 90), 0))
		"batteries":
			for i in 3:
				var a := TAU * i / 3.0
				var p := Vector3(cos(a) * 0.55, 0, sin(a) * 0.55)
				_part(_cyl(0.35, 1.4), Color(0.12, 0.12, 0.12), p + Vector3(0, 0.7, 0))
				_part(_cyl(0.36, 0.35), Color(0.85, 0.55, 0.25), p + Vector3(0, 1.45, 0))
				_part(_cyl(0.12, 0.15), Color(0.8, 0.8, 0.8), p + Vector3(0, 1.7, 0))
		"marbles":
			var rng := RandomNumberGenerator.new()
			rng.seed = id
			var colors := [Color(0.45, 0.75, 0.95), Color(0.95, 0.4, 0.6), Color(0.5, 0.95, 0.6), Color(0.95, 0.95, 0.95)]
			_part(_cyl(1.0, 0.5), Color(0.5, 0.35, 0.6), Vector3(0, 0.25, 0))
			for i in 9:
				var r := rng.randf_range(0.28, 0.42)
				var p := Vector3(rng.randf_range(-0.8, 0.8), 0.5 + r + (0.5 if i > 5 else 0.0), rng.randf_range(-0.8, 0.8))
				_part(_sphere(r), colors[i % colors.size()], p)

	# Selectiering
	var torus := TorusMesh.new()
	var r := (half * 1.3) if kind == "building" else radius + 0.2
	torus.inner_radius = r
	torus.outer_radius = r + 0.14
	ring = MeshInstance3D.new()
	ring.mesh = torus
	ring.position.y = 0.06
	ring.scale.y = 0.3
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	if kind == "building":
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		label.outline_size = 10
		label.pixel_size = 0.012
		label.position.y = pick_height + 1.2
		add_child(label)


func _soldier(pc: Color) -> void:
	_part(_capsule(0.28, 1.05), pc, Vector3(0, 0.6, 0))
	_part(_sphere(0.21), Color(0.96, 0.82, 0.66), Vector3(0, 1.3, 0))
	var helmet := _part(_sphere(0.25), pc.darkened(0.35), Vector3(0, 1.42, 0))
	helmet.scale = Vector3(1, 0.55, 1)


func _flag(pc: Color, base: Vector3) -> void:
	_part(_cyl(0.07, 3.0), Color(0.85, 0.85, 0.85), base + Vector3(0, 1.5, 0))
	_part(_box(Vector3(0.05, 0.7, 1.2)), pc, base + Vector3(0, 2.6, 0.62))


func _part(mesh: Mesh, color: Color, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = GameData.make_mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	model.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	return m
