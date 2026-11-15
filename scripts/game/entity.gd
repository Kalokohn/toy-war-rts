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
var flying := false

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
const ToyModels := preload("res://scripts/visual/toy_models.gd")
const Mat := preload("res://scripts/visual/toy_mat.gd")
const ToyMesh := preload("res://scripts/visual/toy_mesh.gd")
const Fx := preload("res://scripts/visual/fx.gd")
const UNIT_VISUAL_SCALE := 1.2

var net_pos := Vector3.ZERO
var net_rot := 0.0
var model: Node3D
var parts := {}
var ring: MeshInstance3D
var carry_mesh: MeshInstance3D
var start_amount := 1
var _shown_carry := ""
var _bob := 0.0
var _anim := 0.0
var _atk_t := 0.0
var _last_hp := -1.0
var _was_complete := true
var _fx_t := 0.0


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
			flying = d.get("flying", false)
			pick_radius = maxf(0.8, radius * 1.3)
			pick_height = 7.0 if flying else maxf(1.6, radius * 2.5)
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
			start_amount = amount
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
	_anim += delta
	# Raakeffect als de HP omlaag gaat.
	if _last_hp >= 0.0 and hp < _last_hp - 0.5 and kind != "resource":
		Fx.hit(get_parent(), position + Vector3(0, pick_height * 0.6, 0), GameData.player_color(owner_slot).lightened(0.2))
		if kind == "unit":
			model.scale = Vector3(1.12, 0.88, 1.12)
	_last_hp = hp
	if model.scale != Vector3.ONE and kind == "unit":
		model.scale = model.scale.lerp(Vector3.ONE, clampf(delta * 10.0, 0.0, 1.0))
	match kind:
		"unit":
			_animate_unit(delta)
		"building":
			_animate_building(delta)
		"resource":
			var k := 0.55 + 0.45 * clampf(float(amount) / maxf(start_amount, 1.0), 0.0, 1.0)
			model.scale = model.scale.lerp(Vector3(k, k, k), clampf(delta * 4.0, 0.0, 1.0))


func _animate_unit(delta: float) -> void:
	var ud: Dictionary = GameData.UNITS[type]
	var base_y := 0.0
	var tilt := 0.0
	var wobble := 0.0
	if flying:
		_bob += delta * 3.0
		base_y = 4.0 + sin(_bob) * 0.3
		tilt = 6.0 if moving else 0.0
		var flap := sin(_anim * (9.0 if moving else 5.0)) * 28.0
		var wings: Array = parts.get("wings", [])
		if wings.size() == 2:
			wings[0].rotation_degrees.z = flap
			wings[1].rotation_degrees.z = -flap
	elif moving:
		# Speelgoed "huppelt" vooruit, alsof een kind het verplaatst.
		_bob += delta * 13.0
		base_y = absf(sin(_bob)) * 0.16
		wobble = sin(_bob) * 7.0
	else:
		_bob = 0.0
	# Poten zwaaien bij dino's
	for i in parts.get("legs", []).size():
		var leg: Node3D = parts["legs"][i]
		var ph := PI if i % 2 == 1 else 0.0
		leg.rotation_degrees.x = sin(_bob + ph) * 26.0 if moving else lerpf(leg.rotation_degrees.x, 0.0, 0.2)
	var tail: Node3D = parts.get("tail")
	if tail:
		tail.rotation_degrees.y = sin(_anim * (6.0 if moving else 1.6)) * (14.0 if moving else 8.0)
	var key: Node3D = parts.get("key")
	if key:
		key.rotation.z += delta * (6.0 if moving or state in ["gather", "build"] else 1.5)
	# Werken: hakken/pikken richting de bron of het gebouw.
	if not moving and state in ["gather", "build"] and not flying:
		tilt = maxf(sin(_anim * 9.0), 0.0) * 18.0
		_fx_t += delta
		if _fx_t > 0.55:
			_fx_t = 0.0
			Fx.dust(get_parent(), position + transform.basis.z * (radius + 0.4) + Vector3(0, 0.4, 0))
	# Aanvallen: mondingsvuur of een uitval.
	if state == "attack" and not moving and ud["damage"] > 0:
		_atk_t += delta
		var cd: float = ud["cooldown"]
		var lunge := 0.0
		if parts.get("muzzle") != null:
			if _atk_t >= cd:
				_atk_t = 0.0
				Fx.muzzle(get_parent(), to_global(parts["muzzle"] * model.scale))
		else:
			if _atk_t >= cd:
				_atk_t = 0.0
			lunge = sin(clampf(_atk_t / 0.25, 0.0, 1.0) * PI) * 0.35
			tilt = lunge * 40.0
		model.position.z = lunge
	else:
		_atk_t = 0.0
		model.position.z = lerpf(model.position.z, 0.0, 0.2)
	model.position.y = lerpf(model.position.y, base_y, clampf(delta * 14.0, 0.0, 1.0)) if not flying else base_y
	model.rotation_degrees.x = lerpf(model.rotation_degrees.x, tilt, clampf(delta * 12.0, 0.0, 1.0))
	model.rotation_degrees.z = lerpf(model.rotation_degrees.z, wobble, clampf(delta * 12.0, 0.0, 1.0))
	if carry_mesh:
		var want := carry_type if carry_amount > 0 else ""
		if want != _shown_carry:
			_shown_carry = want
			carry_mesh.visible = want != ""
			if want != "":
				carry_mesh.material_override = Mat.plastic(GameData.RESOURCE_COLORS[want])


func _animate_building(delta: float) -> void:
	if complete:
		if not _was_complete:
			_was_complete = true
			model.scale = Vector3(1.08, 1.12, 1.08)
			Fx.poof(get_parent(), position, Color(1, 0.9, 0.5), false)
		model.scale = model.scale.lerp(Vector3.ONE, clampf(delta * 6.0, 0.0, 1.0))
	else:
		_was_complete = false
		var k := lerpf(0.12, 1.0, progress)
		model.scale = Vector3(1.0, k, 1.0)
		_fx_t += delta
		if _fx_t > 0.4 and progress > 0.0:
			_fx_t = 0.0
			Fx.dust(get_parent(), position + Vector3(randf_range(-half, half), half * k, randf_range(-half, half)))
	for f in parts.get("flags", []):
		f.rotation_degrees.y = sin(_anim * 2.5 + id) * 14.0


## Wordt aangeroepen vlak voordat de entity verdwijnt.
func on_removed() -> void:
	var parent := get_parent()
	match kind:
		"unit":
			Fx.poof(parent, position + Vector3(0, 4.0 if flying else 0.0, 0), GameData.player_color(owner_slot), false)
		"building":
			Fx.poof(parent, position, GameData.player_color(owner_slot), true)
		"resource":
			Fx.poof(parent, position, GameData.RESOURCE_COLORS.get(type, Color.WHITE), false)


func set_selected(on: bool, color: Color) -> void:
	ring.visible = on
	if on:
		ring.material_override = Mat.ring(color)


func _build_visual() -> void:
	parts = ToyModels.build(type, GameData.player_color(owner_slot), id * 7919 + 13)
	model = parts["root"]
	add_child(model)
	carry_mesh = parts.get("carry")
	if kind == "unit":
		# Units iets groter tonen dan hun botsingsstraal, dan lees je ze beter.
		for c in model.get_children():
			c.position *= UNIT_VISUAL_SCALE
			c.scale *= UNIT_VISUAL_SCALE
		if parts.get("muzzle") != null:
			parts["muzzle"] *= UNIT_VISUAL_SCALE
	_was_complete = complete

	# Selectiering (gloeiende ring op de grond)
	var r := (half * 1.45) if kind == "building" else radius + 0.35
	ring = MeshInstance3D.new()
	ring.mesh = ToyMesh.plane(r * 2.0, r * 2.0)
	ring.position.y = 0.07
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# Zachte contactschaduw onder units
	if kind == "unit":
		var blob := MeshInstance3D.new()
		var s := radius * 2.6
		blob.mesh = ToyMesh.plane(s, s)
		blob.material_override = Mat.blob_shadow()
		blob.position.y = 0.04
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)
