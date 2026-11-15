extends Node
## Maakt iconen en portretten door de echte 3D-modellen in een kleine
## SubViewport te fotograferen. Zo passen de iconen altijd bij het spel.
## (Autoload "Icons".)

const ToyModels := preload("res://scripts/visual/toy_models.gd")

var _tex := {}


## Statisch icoon (een keer gerenderd). slot = spelerkleur, -1 = neutraal.
func icon(type: String, slot := -1, size := 128) -> Texture2D:
	var key := "%s|%d|%d" % [type, slot, size]
	if _tex.has(key):
		return _tex[key]
	var vp := _stage(type, slot, size, false)
	_tex[key] = vp.get_texture()
	return _tex[key]


## Levend portret dat langzaam ronddraait. De aanroeper beheert de SubViewport.
func portrait(type: String, slot: int, size := 160) -> SubViewport:
	return _stage(type, slot, size, true)


func resource_icon(res: String) -> Texture2D:
	return icon("icon_" + res, -1, 96)


func _stage(type: String, slot: int, size: int, live: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_ONCE
	if not live:
		add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.3
	key.light_color = Color(1.0, 0.95, 0.85)
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(rim)

	var pivot := Node3D.new()
	world.add_child(pivot)
	var data := ToyModels.build(type, GameData.player_color(slot), 4242)
	var model: Node3D = data["root"]
	pivot.add_child(model)
	for l in data.get("lights", []):
		l.visible = false
	var is_icon := type.begins_with("icon_")
	pivot.rotation_degrees.y = 0.0 if is_icon else -32.0
	if type == "pteranodon":
		pivot.rotation_degrees = Vector3(15, -20, 0)

	# Kader op basis van de omhullende doos van het model.
	var aabb := _bounds(model, pivot.transform)
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = radius * (1.5 if is_icon else 1.6)
	var dir := Vector3(0, 0.35 if is_icon else 0.5, 1).normalized()
	cam.position = center + dir * radius * 4.0
	cam.near = 0.05
	cam.far = radius * 10.0
	world.add_child(cam)
	cam.look_at_from_position(cam.position, center, Vector3.UP)
	if live:
		var spin := _Spinner.new()
		spin.target = pivot
		world.add_child(spin)
	return vp


func _bounds(n: Node3D, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var stack := [[n, xf * n.transform]]
	while stack.size() > 0:
		var item: Array = stack.pop_back()
		var node: Node3D = item[0]
		var t: Transform3D = item[1]
		if node is MeshInstance3D and node.visible and node.mesh:
			var b: AABB = t * node.mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, t * c.transform])
	if first:
		out = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	return out


class _Spinner extends Node:
	var target: Node3D

	func _process(delta: float) -> void:
		if target:
			target.rotation.y += delta * 0.6
