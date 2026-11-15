extends RefCounted
## Bouwt de 3D-modellen van alle units, gebouwen en grondstoffen uit
## afgeronde plastic onderdelen. Wordt gebruikt door entity.gd, de iconen
## in de HUD en het hoofdmenu.
##
## build() geeft een Dictionary terug met handige onderdelen voor animaties:
##   "root"   : Node3D met het hele model
##   "carry"  : MeshInstance3D voor wat een worker draagt (of null)
##   "wings"  : [links, rechts] pivots voor vleugelslag
##   "tail"   : pivot voor staartzwaai
##   "head"   : pivot van het hoofd
##   "muzzle" : Vector3 waar een schot vandaan komt (of null)
##   "lights" : lichten die bij het model horen

const M := preload("res://scripts/visual/toy_mesh.gd")
const Mat := preload("res://scripts/visual/toy_mat.gd")

const WHITE := Color(0.96, 0.95, 0.9)
const BONE := Color(0.95, 0.92, 0.82)
const DARK := Color(0.08, 0.08, 0.1)
const WOOD := Color(0.78, 0.55, 0.32)
const WOOD_DARK := Color(0.55, 0.36, 0.2)
const ROCK := Color(0.52, 0.47, 0.44)
const GOLD := Color(0.95, 0.72, 0.22)
const LEAF := Color(0.3, 0.68, 0.25)
const LAVA := Color(1.0, 0.42, 0.08)

static var _font: Font

var root: Node3D
var out := {}
var _rng := RandomNumberGenerator.new()


static func build(type: String, pc: Color, seed := 0) -> Dictionary:
	var b := new()
	b._rng.seed = seed if seed != 0 else type.hash()
	b.root = Node3D.new()
	b.root.name = "Model"
	b.out = {"root": b.root, "carry": null, "wings": [], "tail": null, "head": null, "muzzle": null, "lights": []}
	b._build(type, pc)
	return b.out


# --- Bouwstenen --------------------------------------------------------------

func p(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	(parent if parent else root).add_child(mi)
	return mi


func pivot(pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null, scl := Vector3.ONE) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	n.scale = scl
	(parent if parent else root).add_child(n)
	return n


func pl(c: Color, gloss := 0.75) -> Material:
	return Mat.plastic(c, gloss)


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	return _font


func text3d(t: String, color: Color, pos: Vector3, rot := Vector3.ZERO, size := 64, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = font()
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.position = pos
	l.rotation_degrees = rot
	(parent if parent else root).add_child(l)
	return l


func _build(type: String, pc: Color) -> void:
	match type:
		"worker": _army_man(pc, "worker")
		"rifleman": _army_man(pc, "rifle")
		"mini_raptor": _mini_raptor(pc)
		"velociraptor": _velociraptor(pc)
		"dilophosaurus": _dilophosaurus(pc)
		"triceratops": _triceratops(pc)
		"pteranodon": _pteranodon(pc)
		"trex": _trex(pc)
		"hq": _toybox(pc)
		"storage": _crate(pc)
		"house": _lego_house(pc)
		"barracks": _fort(pc)
		"tower": _tower(pc)
		"volcano": _volcano(pc)
		"nest": _nest(pc)
		"hatchery": _hatchery(pc)
		"fossil_lab": _fossil_lab(pc)
		"lookout": _lookout(pc)
		"plastic": _toy_chest()
		"blocks": _block_pile()
		"batteries": _batteries()
		"marbles": _marble_bag()
		# Losse iconen voor de interface
		"icon_plastic": _duck(Vector3.ZERO, 0.0, 1.0)
		"icon_blocks": _icon_blocks()
		"icon_batteries": _icon_battery()
		"icon_marbles": _icon_marbles()
		"icon_pop_soldiers": _icon_helmet(pc)
		"icon_pop_dinos": _icon_egg(pc)
		"icon_stop": _icon_stop()


# --- Toy Soldiers: units -------------------------------------------------------

## Klassiek groen-legermannetje-stijl: alles in een kleur glimmend plastic,
## op een voetstukje.
func _army_man(pc: Color, pose: String) -> void:
	var c := pc
	var mat := pl(c, 0.85)
	var dark := pl(c.darkened(0.18), 0.85)
	# Voetstuk
	p(M.rcyl(0.36, 0.07, 0.03), pl(c.darkened(0.1), 0.85), Vector3(0, 0.035, 0), Vector3.ZERO, Vector3(1, 1, 0.82))
	# Benen in een stap-houding
	for s in [-1.0, 1.0]:
		var hip := pivot(Vector3(0.1 * s, 0.62, 0), Vector3(-14.0 * s, 0, 0))
		p(M.rbox(Vector3(0.17, 0.5, 0.2), 0.07), mat, Vector3(0, -0.27, 0), Vector3.ZERO, Vector3.ONE, hip)
		p(M.rbox(Vector3(0.19, 0.11, 0.3), 0.04), dark, Vector3(0, -0.53, 0.05), Vector3(14.0 * s, 0, 0), Vector3.ONE, hip)
	# Romp, riem, rugzak
	p(M.rbox(Vector3(0.46, 0.5, 0.28), 0.1), mat, Vector3(0, 0.9, 0))
	p(M.rbox(Vector3(0.48, 0.07, 0.3), 0.03), dark, Vector3(0, 0.68, 0))
	p(M.rbox(Vector3(0.12, 0.08, 0.04), 0.02), dark, Vector3(0.12, 0.72, 0.15))
	p(M.rbox(Vector3(0.12, 0.08, 0.04), 0.02), dark, Vector3(-0.12, 0.72, 0.15))
	p(M.rbox(Vector3(0.32, 0.3, 0.14), 0.06), dark, Vector3(0, 0.95, -0.2))
	# Hoofd en helm
	var head := pivot(Vector3(0, 1.2, 0))
	out["head"] = head
	p(M.capsule(0.08, 0.2), mat, Vector3(0, -0.04, 0), Vector3.ZERO, Vector3.ONE, head)
	p(M.sphere(0.15), mat, Vector3(0, 0.1, 0.01), Vector3.ZERO, Vector3.ONE, head)
	p(M.rbox(Vector3(0.05, 0.05, 0.06), 0.02), mat, Vector3(0, 0.08, 0.16), Vector3.ZERO, Vector3.ONE, head)
	p(M.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.25, 0.025), Vector2(0.19, 0.05),
		Vector2(0.185, 0.12), Vector2(0.14, 0.19), Vector2(0.07, 0.22), Vector2(0, 0.225)]), 20, "helmet"),
		dark, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3.ONE, head)
	if pose == "rifle":
		# Geweer in de aanslag
		var ra := pivot(Vector3(0.25, 1.06, 0.02), Vector3(-78, -10, 0))
		p(M.capsule(0.07, 0.42), mat, Vector3(0, -0.18, 0), Vector3.ZERO, Vector3.ONE, ra)
		var la := pivot(Vector3(-0.25, 1.06, 0.02), Vector3(-70, 28, 0))
		p(M.capsule(0.07, 0.46), mat, Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.ONE, la)
		var gun := pivot(Vector3(0.1, 1.1, 0.3), Vector3(-3, 0, 0))
		p(M.rbox(Vector3(0.07, 0.11, 0.62), 0.025), dark, Vector3(0, 0, 0.05), Vector3.ZERO, Vector3.ONE, gun)
		p(M.rbox(Vector3(0.07, 0.15, 0.24), 0.03), dark, Vector3(0, -0.04, -0.3), Vector3.ZERO, Vector3.ONE, gun)
		p(M.rcyl(0.025, 0.4, 0.01, 8), dark, Vector3(0, 0.02, 0.5), Vector3(90, 0, 0), Vector3.ONE, gun)
		p(M.rbox(Vector3(0.05, 0.14, 0.06), 0.02), dark, Vector3(0, -0.09, 0.1), Vector3.ZERO, Vector3.ONE, gun)
		out["muzzle"] = Vector3(0.1, 1.12, 1.02)
	else:
		# Schepje en opwindsleutel
		var ra := pivot(Vector3(0.25, 1.06, 0.02), Vector3(-40, 0, 8))
		p(M.capsule(0.07, 0.44), mat, Vector3(0, -0.19, 0), Vector3.ZERO, Vector3.ONE, ra)
		var la := pivot(Vector3(-0.25, 1.06, 0.02), Vector3(-40, 0, -8))
		p(M.capsule(0.07, 0.44), mat, Vector3(0, -0.19, 0), Vector3.ZERO, Vector3.ONE, la)
		var shovel := pivot(Vector3(0.3, 0.75, 0.3), Vector3(25, 0, -10))
		p(M.rcyl(0.03, 0.9, 0.012, 8), pl(WOOD), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, shovel)
		p(M.rbox(Vector3(0.2, 0.26, 0.04), 0.03), Mat.metal(Color(0.7, 0.72, 0.75)), Vector3(0, -0.32, 0), Vector3.ZERO, Vector3.ONE, shovel)
		var key := pivot(Vector3(0, 0.95, -0.28))
		out["key"] = key
		p(M.rcyl(0.035, 0.22, 0.01, 8), Mat.metal(GOLD), Vector3(0, 0, -0.08), Vector3(90, 0, 0), Vector3.ONE, key)
		p(M.rbox(Vector3(0.36, 0.14, 0.04), 0.06), Mat.metal(GOLD), Vector3(0, 0, -0.2), Vector3.ZERO, Vector3.ONE, key)
		var carry := p(M.rbox(Vector3(0.32, 0.28, 0.3), 0.06), pl(Color.WHITE), Vector3(0, 0.9, 0.36))
		carry.visible = false
		out["carry"] = carry


# --- Toy Dinos: units ----------------------------------------------------------

## Tweebenige dino. k = schaal, head_k = relatieve kopgrootte.
func _biped(pc: Color, k: float, head_k := 1.0, arm_k := 1.0, upright := 0.0) -> Node3D:
	var body := pivot(Vector3.ZERO, Vector3.ZERO, null, Vector3(k, k, k))
	var mat := pl(pc, 0.8)
	var belly := pl(pc.lerp(Color(1, 0.95, 0.8), 0.45), 0.8)
	var stripe := pl(pc.darkened(0.4), 0.8)
	var torso := pivot(Vector3(0, 0.85, 0), Vector3(-upright, 0, 0), body)
	p(M.sphere(0.32), mat, Vector3(0, 0, 0), Vector3(-8, 0, 0), Vector3(0.85, 0.8, 1.35), torso)
	p(M.sphere(0.26), belly, Vector3(0, -0.08, 0.1), Vector3(-8, 0, 0), Vector3(0.82, 0.7, 1.2), torso)
	for i in 3:
		p(M.rbox(Vector3(0.5, 0.05, 0.08), 0.02), stripe, Vector3(0, 0.22, -0.18 + i * 0.16), Vector3(-8, 0, 0), Vector3(1.0 - i * 0.1, 1, 1), torso)
	# Nek en kop
	p(M.capsule(0.14, 0.5), mat, Vector3(0, 0.22, 0.38), Vector3(50, 0, 0), Vector3.ONE, torso)
	var head := pivot(Vector3(0, 0.44, 0.55), Vector3(upright * 0.6, 0, 0), torso, Vector3.ONE * head_k)
	out["head"] = head
	p(M.rbox(Vector3(0.28, 0.24, 0.4), 0.1), mat, Vector3(0, 0, 0.1), Vector3.ZERO, Vector3.ONE, head)
	p(M.rbox(Vector3(0.22, 0.12, 0.3), 0.05), mat, Vector3(0, -0.02, 0.36), Vector3.ZERO, Vector3.ONE, head)
	var jaw := pivot(Vector3(0, -0.08, 0.12), Vector3(16, 0, 0), head)
	p(M.rbox(Vector3(0.2, 0.06, 0.4), 0.03), belly, Vector3(0, -0.02, 0.18), Vector3.ZERO, Vector3.ONE, jaw)
	for s in [-1.0, 1.0]:
		for t in 3:
			p(M.rcone(0.022, 0.0, 0.07, 6), pl(WHITE), Vector3(0.08 * s, -0.11, 0.26 + t * 0.07), Vector3(180, 0, 0), Vector3.ONE, head)
		p(M.sphere(0.055, 12), pl(WHITE), Vector3(0.12 * s, 0.07, 0.14), Vector3.ZERO, Vector3.ONE, head)
		p(M.sphere(0.03, 10), pl(DARK, 1.0), Vector3(0.155 * s, 0.075, 0.165), Vector3.ZERO, Vector3.ONE, head)
		# Armpjes
		var arm := pivot(Vector3(0.18 * s, 0.0, 0.32), Vector3(-55, 0, 0), torso, Vector3.ONE * arm_k)
		p(M.capsule(0.05, 0.28), mat, Vector3(0, -0.1, 0), Vector3.ZERO, Vector3.ONE, arm)
		# Poten
		var leg := pivot(Vector3(0.2 * s, 0.75, -0.05), Vector3.ZERO, body)
		out.get_or_add("legs", []).append(leg)
		p(M.sphere(0.17), mat, Vector3(0, 0, 0), Vector3.ZERO, Vector3(0.8, 1.3, 1.1), leg)
		p(M.capsule(0.075, 0.66), mat, Vector3(0.01 * s, -0.42, -0.06), Vector3(14, 0, 0), Vector3.ONE, leg)
		p(M.rbox(Vector3(0.16, 0.08, 0.32), 0.035), stripe, Vector3(0.01 * s, -0.71, 0.04), Vector3.ZERO, Vector3.ONE, leg)
	# Staart
	var tail := pivot(Vector3(0, 0.05, -0.42), Vector3.ZERO, torso)
	out["tail"] = tail
	p(M.capsule(0.19, 0.6), mat, Vector3(0, 0, -0.15), Vector3(95, 0, 0), Vector3.ONE, tail)
	var t2 := pivot(Vector3(0, -0.03, -0.45), Vector3(-6, 0, 0), tail)
	p(M.capsule(0.12, 0.55), mat, Vector3(0, 0, -0.15), Vector3(95, 0, 0), Vector3.ONE, t2)
	p(M.rcone(0.08, 0.0, 0.45, 10), mat, Vector3(0, 0, -0.55), Vector3(-90, 0, 0), Vector3.ONE, t2)
	p(M.rbox(Vector3(0.3, 0.04, 0.07), 0.015), stripe, Vector3(0, 0.12, -0.05), Vector3.ZERO, Vector3.ONE, t2)
	return body


func _mini_raptor(pc: Color) -> void:
	var body := _biped(pc, 0.8, 1.1)
	p(M.rcyl(0.22, 0.2, 0.05), pl(WOOD), Vector3(0, 1.12, -0.12), Vector3.ZERO, Vector3.ONE, body)
	p(M.torus(0.2, 0.25), pl(WOOD_DARK), Vector3(0, 1.22, -0.12), Vector3.ZERO, Vector3(1, 0.6, 1), body)
	var carry := p(M.rbox(Vector3(0.3, 0.26, 0.3), 0.06), pl(Color.WHITE), Vector3(0, 1.0, -0.1))
	carry.visible = false
	out["carry"] = carry


func _velociraptor(pc: Color) -> void:
	var body := _biped(pc, 1.0, 0.95)
	var head: Node3D = out["head"]
	for i in 4:
		p(M.rcone(0.05, 0.0, 0.22, 6), pl(GOLD), Vector3(0, 0.12 + i * 0.01, 0.0 - i * 0.09), Vector3(-30, 0, 0), Vector3.ONE, head)
	for s in [-1.0, 1.0]:
		p(M.rcone(0.03, 0.0, 0.16, 6), pl(WHITE), Vector3(0.2 * s, 0.06, 0.12), Vector3(110, 0, 0), Vector3.ONE, body)


func _dilophosaurus(pc: Color) -> void:
	_biped(pc, 1.15)
	var head: Node3D = out["head"]
	for s in [-1.0, 1.0]:
		p(M.rbox(Vector3(0.035, 0.22, 0.38), 0.05), pl(Color(1.0, 0.82, 0.2)), Vector3(0.06 * s, 0.18, 0.12), Vector3(0, 0, 12 * s), Vector3.ONE, head)
	# Nekkraag
	var frill := p(M.rcyl(0.27, 0.035, 0.015, 20), Mat.plastic2(Color(1.0, 0.55, 0.15)), Vector3(0, -0.06, -0.14), Vector3(-75, 0, 0), Vector3.ONE, head)
	frill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	out["muzzle"] = Vector3(0, 1.55, 1.0)


func _trex(pc: Color) -> void:
	_biped(pc, 2.1, 1.45, 0.55, 18.0)


func _triceratops(pc: Color) -> void:
	var mat := pl(pc, 0.8)
	var dark := pl(pc.darkened(0.35), 0.8)
	var belly := pl(pc.lerp(Color(1, 0.95, 0.8), 0.4), 0.8)
	p(M.sphere(0.6), mat, Vector3(0, 1.0, -0.05), Vector3.ZERO, Vector3(1.0, 0.85, 1.45))
	p(M.sphere(0.5), belly, Vector3(0, 0.82, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.4))
	for i in 5:
		var a := _rng.randf_range(-0.6, 0.6)
		p(M.sphere(0.12, 10), dark, Vector3(sin(a) * 0.5, 1.38 - absf(a) * 0.2, -0.6 + i * 0.28), Vector3.ZERO, Vector3(1, 0.4, 1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := pivot(Vector3(0.4 * sx, 0.62, 0.55 * sz))
			out.get_or_add("legs", []).append(leg)
			p(M.rcyl(0.17, 0.62, 0.06), mat, Vector3(0, -0.28, 0), Vector3.ZERO, Vector3.ONE, leg)
			p(M.rcyl(0.2, 0.08, 0.03), dark, Vector3(0, -0.58, 0.02), Vector3.ZERO, Vector3.ONE, leg)
	var head := pivot(Vector3(0, 1.05, 0.9), Vector3(12, 0, 0))
	out["head"] = head
	p(M.rbox(Vector3(0.6, 0.52, 0.66), 0.2), mat, Vector3(0, 0, 0.18), Vector3.ZERO, Vector3.ONE, head)
	p(M.rcone(0.2, 0.05, 0.36, 12), belly, Vector3(0, -0.12, 0.58), Vector3(80, 0, 0), Vector3.ONE, head)
	# Kraag met randjes
	var frill := pivot(Vector3(0, 0.3, -0.1), Vector3(-65, 0, 0), head)
	p(M.rcyl(0.58, 0.1, 0.04, 28), pl(pc.lightened(0.25), 0.8), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, frill)
	for i in 9:
		var a := lerpf(-PI * 0.42, PI * 0.42, i / 8.0)
		p(M.sphere(0.07, 10), pl(GOLD), Vector3(sin(a) * 0.58, 0.04, cos(a) * 0.58), Vector3.ZERO, Vector3.ONE, frill)
	for s in [-1.0, 1.0]:
		p(M.rcone(0.08, 0.008, 0.62, 10), pl(BONE), Vector3(0.18 * s, 0.3, 0.4), Vector3(62, 0, 0), Vector3.ONE, head)
		p(M.sphere(0.06, 12), pl(WHITE), Vector3(0.28 * s, 0.12, 0.38), Vector3.ZERO, Vector3.ONE, head)
		p(M.sphere(0.035, 10), pl(DARK, 1.0), Vector3(0.31 * s, 0.13, 0.41), Vector3.ZERO, Vector3.ONE, head)
	p(M.rcone(0.07, 0.005, 0.3, 10), pl(BONE), Vector3(0, 0.08, 0.66), Vector3(50, 0, 0), Vector3.ONE, head)
	var tail := pivot(Vector3(0, 1.0, -0.85))
	out["tail"] = tail
	p(M.rcone(0.32, 0.03, 1.0, 14), mat, Vector3(0, -0.12, -0.42), Vector3(-80, 0, 0), Vector3.ONE, tail)


func _pteranodon(pc: Color) -> void:
	var mat := pl(pc, 0.8)
	var wing_mat := Mat.plastic2(pc.lightened(0.15))
	var body := pivot(Vector3.ZERO)
	p(M.capsule(0.16, 0.95), mat, Vector3(0, 0, -0.05), Vector3(90, 0, 0), Vector3.ONE, body)
	p(M.sphere(0.12), pl(pc.lerp(Color.WHITE, 0.5)), Vector3(0, -0.06, 0.05), Vector3.ZERO, Vector3(1, 0.8, 2.2), body)
	var head := pivot(Vector3(0, 0.1, 0.48), Vector3(-10, 0, 0), body)
	out["head"] = head
	p(M.sphere(0.13), mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.3), head)
	p(M.rcone(0.08, 0.005, 0.6, 10), pl(GOLD), Vector3(0, -0.03, 0.38), Vector3(90, 0, 0), Vector3.ONE, head)
	p(M.rcone(0.07, 0.005, 0.5, 10), pl(pc.darkened(0.3)), Vector3(0, 0.12, -0.25), Vector3(-65, 0, 0), Vector3.ONE, head)
	for s in [-1.0, 1.0]:
		p(M.sphere(0.04, 10), pl(DARK, 1.0), Vector3(0.1 * s, 0.04, 0.08), Vector3.ZERO, Vector3.ONE, head)
		var w := pivot(Vector3(0.12 * s, 0.04, 0.12), Vector3.ZERO, body)
		out["wings"].append(w)
		p(M.sphere(1.0, 16), wing_mat, Vector3(0.82 * s, 0, -0.12), Vector3(0, 12 * s, 0), Vector3(0.85, 0.035, 0.34), w)
		p(M.capsule(0.04, 1.6), mat, Vector3(0.8 * s, 0.02, 0.1), Vector3(0, 0, 90), Vector3.ONE, w)
	p(M.rcone(0.1, 0.0, 0.5, 8), mat, Vector3(0, 0, -0.68), Vector3(-90, 0, 0), Vector3.ONE, body)


# --- Toy Soldiers: gebouwen ----------------------------------------------------

func _flag(pc: Color, base: Vector3, h := 3.0) -> void:
	p(M.rcyl(0.07, h, 0.03, 10), Mat.metal(Color(0.85, 0.85, 0.88)), base + Vector3(0, h * 0.5, 0))
	p(M.sphere(0.12, 12), Mat.metal(GOLD), base + Vector3(0, h + 0.05, 0))
	var f := pivot(base + Vector3(0, h - 0.45, 0))
	out.get_or_add("flags", []).append(f)
	p(M.rbox(Vector3(0.05, 0.7, 1.2), 0.03), Mat.plastic2(pc), Vector3(0, 0, 0.62), Vector3.ZERO, Vector3.ONE, f)


## Speelgoeddoos (HQ): een houten speelgoedkist in spelerkleur met
## open deksel waar speelgoed uitpiept.
func _toybox(pc: Color) -> void:
	var trim := pl(Color(0.98, 0.94, 0.84))
	p(M.rbox(Vector3(8.0, 0.35, 8.0), 0.12), pl(pc.darkened(0.35)), Vector3(0, 0.17, 0))
	p(M.rbox(Vector3(7.2, 3.5, 7.2), 0.25), pl(pc), Vector3(0, 2.05, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			p(M.rbox(Vector3(0.75, 3.9, 0.75), 0.2), trim, Vector3(3.5 * sx, 2.1, 3.5 * sz))
			p(M.sphere(0.48), pl(GOLD), Vector3(3.5 * sx, 4.15, 3.5 * sz))
	for s in [-1.0, 1.0]:
		p(M.rbox(Vector3(6.4, 0.35, 0.3), 0.1), trim, Vector3(0, 0.75, 3.6 * s))
		p(M.rbox(Vector3(0.3, 0.35, 6.4), 0.1), trim, Vector3(3.6 * s, 0.75, 0))
	# Voorpaneel met ster
	p(M.rbox(Vector3(4.6, 2.2, 0.2), 0.12), pl(pc.lightened(0.3)), Vector3(0, 2.05, 3.62))
	text3d("★", Color(1.0, 0.85, 0.2), Vector3(0, 2.05, 3.74), Vector3.ZERO, 260)
	# Deksel op een kier
	var lid := pivot(Vector3(0, 3.8, -3.6), Vector3(-24, 0, 0))
	p(M.rbox(Vector3(7.6, 0.45, 7.5), 0.2), pl(pc.darkened(0.15)), Vector3(0, 0.22, 3.7), Vector3.ZERO, Vector3.ONE, lid)
	p(M.rbox(Vector3(1.6, 0.3, 0.4), 0.12), pl(GOLD), Vector3(0, 0.1, 7.45), Vector3.ZERO, Vector3.ONE, lid)
	# Speelgoed dat eruit piept
	var ball := p(M.sphere(0.95), pl(Color(0.92, 0.2, 0.2)), Vector3(1.6, 4.0, 1.2))
	p(M.torus(0.9, 1.0), pl(WHITE), Vector3(1.6, 4.0, 1.2), Vector3(0, 0, 70), Vector3(1, 1, 1))
	ball.rotation_degrees = Vector3(0, 0, 20)
	p(M.rbox(Vector3(1.1, 1.1, 1.1), 0.12), pl(Color(0.25, 0.65, 0.95)), Vector3(-1.4, 3.9, 0.8), Vector3(10, 30, 15))
	p(M.rbox(Vector3(0.9, 0.9, 0.9), 0.1), pl(Color(0.98, 0.82, 0.2)), Vector3(-2.3, 3.8, -0.6), Vector3(-15, 10, 5))
	p(M.rcyl(0.12, 2.6, 0.05, 10), pl(Color(0.3, 0.75, 0.35)), Vector3(0.0, 4.3, -1.2), Vector3(25, 0, -35))
	p(M.sphere(0.25), pl(Color(0.3, 0.75, 0.35)), Vector3(0.75, 5.35, -0.6))
	_flag(pc, Vector3(3.5, 4.3, -3.5), 2.6)


## Opslagkist: houten krat met spelerkleur-deksel.
func _crate(pc: Color) -> void:
	var wood := pl(WOOD, 0.45)
	var wood2 := pl(WOOD_DARK, 0.45)
	p(M.rbox(Vector3(3.6, 2.0, 3.6), 0.12), wood, Vector3(0, 1.05, 0))
	for y in [0.35, 1.05, 1.75]:
		p(M.rbox(Vector3(3.72, 0.26, 3.72), 0.08), wood2, Vector3(0, y, 0))
	for s in [-1.0, 1.0]:
		p(M.rbox(Vector3(4.3, 0.22, 0.12), 0.06), wood2, Vector3(0, 1.05, 1.86 * s), Vector3(0, 0, 26))
		p(M.rbox(Vector3(0.12, 0.22, 4.3), 0.06), wood2, Vector3(1.86 * s, 1.05, 0), Vector3(26, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			p(M.rbox(Vector3(0.45, 2.2, 0.45), 0.08), Mat.metal(Color(0.65, 0.66, 0.7), 0.35), Vector3(1.72 * sx, 1.1, 1.72 * sz))
	p(M.rbox(Vector3(3.9, 0.35, 3.9), 0.14), pl(pc), Vector3(0, 2.25, 0))
	p(M.rbox(Vector3(1.2, 0.3, 0.3), 0.1), pl(pc.darkened(0.3)), Vector3(0, 2.5, 0))
	# Wat spullen erop
	p(M.rbox(Vector3(0.8, 0.8, 0.8), 0.1), pl(Color(0.95, 0.3, 0.3)), Vector3(-0.9, 2.82, 0.6), Vector3(0, 20, 0))
	p(M.sphere(0.4), pl(Color(0.3, 0.6, 0.95)), Vector3(0.9, 2.82, -0.5))


## Lego-huisje: bakstenen muren, dak en noppen op een groene grondplaat.
func _lego_house(pc: Color) -> void:
	var green := pl(Color(0.3, 0.62, 0.28))
	p(M.rbox(Vector3(4.0, 0.22, 4.0), 0.05), green, Vector3(0, 0.11, 0))
	for x in 4:
		for z in 4:
			if x in [1, 2] and z in [1, 2]:
				continue
			p(M.rcyl(0.22, 0.16, 0.04, 14), green, Vector3(-1.5 + x, 0.28, -1.5 + z))
	var wall := pl(pc.lerp(Color.WHITE, 0.15))
	var wall2 := pl(pc.lerp(Color.WHITE, 0.3))
	for row in 3:
		var col := wall if row % 2 == 0 else wall2
		p(M.rbox(Vector3(3.3, 0.55, 2.7), 0.05), col, Vector3(0, 0.5 + row * 0.56, 0))
	# Ramen en deur
	var frame := pl(WHITE)
	var glass := pl(Color(0.35, 0.65, 0.9), 1.0)
	for s in [-1.0, 1.0]:
		p(M.rbox(Vector3(0.75, 0.75, 0.12), 0.04), frame, Vector3(0.95 * s, 1.15, 1.36))
		p(M.rbox(Vector3(0.55, 0.55, 0.12), 0.03), glass, Vector3(0.95 * s, 1.15, 1.39))
		p(M.rbox(Vector3(0.12, 0.75, 0.75), 0.04), frame, Vector3(1.66 * s, 1.15, 0))
		p(M.rbox(Vector3(0.12, 0.55, 0.55), 0.03), glass, Vector3(1.69 * s, 1.15, 0))
	p(M.rbox(Vector3(0.7, 1.1, 0.12), 0.05), pl(Color(0.95, 0.75, 0.2)), Vector3(0, 0.78, 1.37))
	p(M.sphere(0.05), Mat.metal(GOLD), Vector3(0.2, 0.78, 1.45))
	# Dak
	var roof := pl(pc.darkened(0.25))
	var r := p(M.prism(3.3, 1.25, 3.8), roof, Vector3(0, 1.98, 0), Vector3(0, 90, 0))
	r.scale = Vector3(1, 1, 1)
	p(M.rbox(Vector3(3.9, 0.15, 0.2), 0.05), frame, Vector3(0, 3.24, 0))
	# Schoorsteen met noppen
	p(M.rbox(Vector3(0.6, 0.9, 0.6), 0.05), pl(Color(0.85, 0.25, 0.2)), Vector3(1.0, 2.75, -0.7))
	p(M.rcyl(0.14, 0.12, 0.03, 12), pl(Color(0.85, 0.25, 0.2)), Vector3(1.0, 3.26, -0.7))


## Barak: een speelgoedfort met kantelen, hoektorens en een poort.
func _fort(pc: Color) -> void:
	var stone := pl(Color(0.86, 0.78, 0.62), 0.55)
	var stone2 := pl(Color(0.74, 0.66, 0.52), 0.55)
	p(M.rbox(Vector3(6.0, 0.25, 6.0), 0.08), pl(Color(0.42, 0.55, 0.3)), Vector3(0, 0.12, 0))
	p(M.rbox(Vector3(4.2, 0.12, 4.2), 0.04), pl(Color(0.72, 0.6, 0.42), 0.4), Vector3(0, 0.28, 0))
	for side in 4:
		var rot := side * 90.0
		var w := pivot(Vector3.ZERO, Vector3(0, rot, 0))
		p(M.rbox(Vector3(4.4, 2.0, 0.5), 0.08), stone, Vector3(0, 1.2, 2.45), Vector3.ZERO, Vector3.ONE, w)
		for i in 5:
			p(M.rbox(Vector3(0.48, 0.42, 0.56), 0.06), stone2, Vector3(-1.8 + i * 0.9, 2.4, 2.45), Vector3.ZERO, Vector3.ONE, w)
		if side != 0:
			p(M.rbox(Vector3(0.9, 1.1, 0.08), 0.03), Mat.plastic2(pc), Vector3(0, 1.45, 2.74), Vector3.ZERO, Vector3.ONE, w)
	# Poort
	p(M.rbox(Vector3(1.5, 1.6, 0.56), 0.15), pl(Color(0.35, 0.22, 0.12), 0.4), Vector3(0, 0.95, 2.48))
	p(M.rbox(Vector3(1.9, 0.3, 0.62), 0.08), pl(pc), Vector3(0, 1.85, 2.48))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(2.55 * sx, 0, 2.55 * sz)
			p(M.rcyl(0.78, 3.0, 0.1), stone, c + Vector3(0, 1.7, 0))
			p(M.rcyl(0.9, 0.3, 0.08), stone2, c + Vector3(0, 3.25, 0))
			p(M.rcone(1.0, 0.04, 1.3, 20), pl(pc), c + Vector3(0, 4.05, 0))
	# Tentje binnen
	p(M.prism(2.0, 1.2, 1.8), pl(Color(0.45, 0.55, 0.3), 0.4), Vector3(-0.6, 0.34, -0.6), Vector3(0, 90, 0))
	_flag(pc, Vector3(0.9, 0.3, -0.8), 3.4)


## Wachttoren: een kasteeltorentje met kantelen en een puntdak.
func _tower(pc: Color) -> void:
	var stone := pl(Color(0.86, 0.82, 0.74), 0.55)
	var stone2 := pl(Color(0.7, 0.66, 0.6), 0.55)
	p(M.rcyl(1.45, 0.6, 0.12, 24), stone2, Vector3(0, 0.3, 0))
	p(M.rcyl(1.05, 4.4, 0.1, 24), stone, Vector3(0, 2.8, 0))
	p(M.rcyl(1.1, 0.3, 0.08, 24), pl(pc), Vector3(0, 2.0, 0))
	p(M.rcyl(1.1, 0.3, 0.08, 24), pl(pc), Vector3(0, 3.8, 0))
	p(M.rbox(Vector3(0.5, 0.9, 0.2), 0.06), pl(Color(0.2, 0.18, 0.2)), Vector3(0, 3.0, 1.0))
	p(M.rcyl(1.45, 0.4, 0.1, 24), stone2, Vector3(0, 5.15, 0))
	for i in 8:
		var a := TAU * i / 8.0
		p(M.rbox(Vector3(0.45, 0.45, 0.35), 0.06), stone, Vector3(cos(a) * 1.25, 5.55, sin(a) * 1.25), Vector3(0, -rad_to_deg(a) + 90, 0))
	p(M.rcone(1.15, 0.04, 1.5, 24), pl(pc), Vector3(0, 6.45, 0))
	p(M.sphere(0.15), Mat.metal(GOLD), Vector3(0, 7.25, 0))
	out["muzzle"] = Vector3(0, 5.6, 0)


# --- Toy Dinos: gebouwen -------------------------------------------------------

func _palm(pos: Vector3, h := 2.2, s := 1.0) -> void:
	var trunk := pivot(pos, Vector3(_rng.randf_range(-8, 8), _rng.randf_range(0, 360), _rng.randf_range(-8, 8)), null, Vector3.ONE * s)
	for i in 4:
		p(M.rcyl(0.14 - i * 0.015, h / 4.0 + 0.05, 0.04, 10), pl(Color(0.55, 0.38, 0.22), 0.4), Vector3(0, h / 8.0 + i * h / 4.0, 0), Vector3.ZERO, Vector3.ONE, trunk)
	for i in 6:
		var a := TAU * i / 6.0
		var lf := pivot(Vector3(0, h, 0), Vector3(0, rad_to_deg(a), 0), trunk)
		p(M.sphere(0.5, 12), pl(LEAF.lightened(_rng.randf_range(-0.1, 0.15))), Vector3(0, -0.15, 0.5), Vector3(-25, 0, 0), Vector3(0.35, 0.08, 1.0), lf)


## Vulkaan-speelset (HQ): een vulkaan met gloeiende lava op een plastic voet.
func _volcano(pc: Color) -> void:
	p(M.rcyl(4.0, 0.45, 0.15, 32), pl(pc), Vector3(0, 0.22, 0))
	p(M.rcyl(3.7, 0.2, 0.06, 32), pl(Color(0.45, 0.6, 0.3), 0.4), Vector3(0, 0.5, 0))
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(3.5, 0), Vector2(3.3, 0.6), Vector2(2.9, 1.5),
		Vector2(2.45, 2.6), Vector2(2.0, 3.7), Vector2(1.6, 4.7), Vector2(1.45, 5.2), Vector2(1.25, 5.25),
		Vector2(1.05, 4.95), Vector2(0, 4.9)])
	p(M.lathe(prof, 28, "volcano"), pl(Color(0.45, 0.33, 0.28), 0.5), Vector3(0, 0.55, 0))
	# Rotsbulten
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf()
		var rr := _rng.randf_range(2.2, 3.0)
		var hh := 3.3 - rr * 0.9
		p(M.sphere(_rng.randf_range(0.35, 0.6), 12), pl(Color(0.38, 0.28, 0.24), 0.5), Vector3(cos(a) * rr, 0.55 + hh, sin(a) * rr), Vector3.ZERO, Vector3(1, 0.7, 1))
	p(M.rcyl(1.1, 0.12, 0.05, 24), Mat.glow(LAVA, 3.0), Vector3(0, 5.48, 0))
	# Lavastromen
	for a in [0.4, 2.2, 4.1]:
		var dir := Vector3(cos(a), 0, sin(a))
		var st := pivot(Vector3(0, 5.75, 0) + dir * 1.4, Vector3(0, 90 - rad_to_deg(a), 0))
		p(M.rbox(Vector3(0.4, 0.16, 2.2), 0.07), Mat.glow(LAVA, 2.4), Vector3(0, -1.0, 0.38), Vector3(68, 0, 0), Vector3.ONE, st)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 6.6, 0)
	root.add_child(light)
	out["lights"].append(light)
	_palm(Vector3(2.9, 0.55, 2.2), 2.0)
	_palm(Vector3(-3.0, 0.55, 1.8), 2.4)
	_palm(Vector3(-2.2, 0.55, -2.9), 1.8)
	_flag(pc, Vector3(3.0, 0.5, -2.8), 2.6)


## Nest: een kom van takjes met gespikkelde eieren.
func _nest(pc: Color) -> void:
	p(M.rcyl(1.95, 0.14, 0.05, 28), pl(pc), Vector3(0, 0.07, 0))
	var prof := PackedVector2Array([Vector2(0, 0.1), Vector2(1.5, 0.1), Vector2(1.85, 0.4), Vector2(1.9, 0.85),
		Vector2(1.7, 1.0), Vector2(1.45, 0.75), Vector2(0, 0.55)])
	p(M.lathe(prof, 24, "nest"), pl(Color(0.58, 0.42, 0.25), 0.3), Vector3.ZERO)
	for i in 18:
		var a := TAU * i / 18.0 + _rng.randf() * 0.3
		var rr := _rng.randf_range(1.55, 1.85)
		p(M.capsule(0.06, 1.3), pl(Color(0.48, 0.33, 0.2).lightened(_rng.randf_range(0, 0.2)), 0.3),
			Vector3(cos(a) * rr, 0.8 + _rng.randf_range(-0.1, 0.15), sin(a) * rr),
			Vector3(_rng.randf_range(60, 120), -rad_to_deg(a), _rng.randf_range(-20, 20)))
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		var egg := pivot(Vector3(cos(a) * 0.6, 1.05, sin(a) * 0.6), Vector3(_rng.randf_range(-15, 15), 0, _rng.randf_range(-15, 15)))
		p(M.sphere(0.42), pl(pc.lerp(Color(1, 0.97, 0.88), 0.7)), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1), egg)
		for j in 5:
			var b := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(-1, 1)).normalized()
			p(M.sphere(0.07, 8), pl(pc.darkened(0.15)), Vector3(b.x * 0.4, b.y * 0.53, b.z * 0.4), Vector3.ZERO, Vector3(1, 0.6, 1), egg)


## Broedplaats: een koepel-hut tussen de palmbomen met grote eieren.
func _hatchery(pc: Color) -> void:
	p(M.rbox(Vector3(5.8, 0.5, 5.8), 0.2), pl(Color(0.45, 0.58, 0.3), 0.4), Vector3(0, 0.25, 0))
	p(M.rcyl(2.7, 0.35, 0.12, 32), pl(Color(0.75, 0.62, 0.42), 0.4), Vector3(0, 0.62, 0))
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI * 0.5 * i / 12.0
		dome.append(Vector2(cos(a) * 2.4, sin(a) * 2.2))
	dome.append(Vector2(0, 2.2))
	p(M.lathe(dome, 32, "hatch_dome"), pl(pc), Vector3(0, 0.75, 0))
	for i in 3:
		p(M.torus(2.0 - i * 0.55, 2.15 - i * 0.55), pl(pc.darkened(0.3)), Vector3(0, 1.3 + i * 0.55, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	p(M.rbox(Vector3(1.3, 1.5, 0.6), 0.4), pl(Color(0.18, 0.12, 0.08), 0.3), Vector3(0, 1.3, 2.15))
	p(M.torus(0.65, 0.85), pl(BONE), Vector3(0, 1.45, 2.3), Vector3(90, 0, 0), Vector3(1, 1, 1.2))
	var egg := pivot(Vector3(0, 3.0, 0))
	p(M.sphere(0.6), pl(Color(0.98, 0.95, 0.85)), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1.3, 1), egg)
	for i in 6:
		var a := TAU * i / 6.0
		p(M.rcone(0.18, 0.0, 0.35, 6), pl(Color(0.98, 0.95, 0.85)), Vector3(cos(a) * 0.5, 0.95, sin(a) * 0.5), Vector3(0, 0, 0), Vector3.ONE, egg)
	for i in 4:
		var a := TAU * i / 4.0 + 0.8
		var e := pivot(Vector3(cos(a) * 2.6, 0.95, sin(a) * 2.6), Vector3(0, 0, _rng.randf_range(-15, 15)))
		p(M.sphere(0.35), pl(pc.lerp(Color(1, 0.97, 0.88), 0.6)), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1), e)
	_palm(Vector3(2.4, 0.5, -2.3), 2.4)
	_palm(Vector3(-2.5, 0.5, -2.2), 2.0)


## Fossielenlab: een museumpje met zuilen en een dinoskelet op het dak.
func _fossil_lab(pc: Color) -> void:
	var white := pl(Color(0.95, 0.93, 0.88), 0.6)
	p(M.rbox(Vector3(5.9, 0.3, 5.9), 0.08), pl(Color(0.8, 0.78, 0.74)), Vector3(0, 0.15, 0))
	p(M.rbox(Vector3(5.4, 0.3, 5.4), 0.08), white, Vector3(0, 0.45, 0))
	p(M.rbox(Vector3(4.6, 2.6, 3.8), 0.15), white, Vector3(0, 1.9, -0.4))
	for i in 4:
		p(M.rcyl(0.24, 2.6, 0.06, 14), white, Vector3(-1.8 + i * 1.2, 1.9, 2.0))
		p(M.rbox(Vector3(0.6, 0.18, 0.6), 0.04), white, Vector3(-1.8 + i * 1.2, 0.7, 2.0))
	p(M.rbox(Vector3(5.0, 0.3, 4.9), 0.1), pl(pc), Vector3(0, 3.35, 0.1))
	p(M.prism(5.0, 0.9, 0.4), pl(pc.darkened(0.15)), Vector3(0, 3.5, 2.35))
	p(M.rbox(Vector3(1.3, 1.9, 0.12), 0.05), pl(Color(0.25, 0.4, 0.55), 1.0), Vector3(0, 1.55, 1.52))
	# Skelet
	var bone := pl(BONE, 0.5)
	var sk := pivot(Vector3(0, 3.5, -0.4), Vector3(0, 35, 0))
	p(M.capsule(0.1, 3.0), bone, Vector3(0, 0.9, 0), Vector3(90, 0, 0), Vector3.ONE, sk)
	for i in 5:
		p(M.torus(0.35 - absf(i - 2) * 0.05, 0.42 - absf(i - 2) * 0.05), bone, Vector3(0, 0.6, -0.8 + i * 0.4), Vector3(90, 0, 0), Vector3(1, 1, 1), sk)
	p(M.rbox(Vector3(0.45, 0.4, 0.75), 0.12), bone, Vector3(0, 1.0, 1.65), Vector3.ZERO, Vector3.ONE, sk)
	p(M.rcone(0.1, 0.0, 1.0, 8), bone, Vector3(0, 0.8, -2.0), Vector3(-90, 0, 0), Vector3.ONE, sk)
	for s in [-1.0, 1.0]:
		p(M.capsule(0.07, 0.95), bone, Vector3(0.25 * s, 0.4, -0.3), Vector3(0, 0, 0), Vector3.ONE, sk)
		p(M.capsule(0.07, 0.95), bone, Vector3(0.25 * s, 0.4, 0.6), Vector3(0, 0, 0), Vector3.ONE, sk)


## Uitkijkrots: gestapelde rotsen met een houten uitkijkpost.
func _lookout(pc: Color) -> void:
	var rk := [pl(ROCK, 0.45), pl(ROCK.darkened(0.15), 0.45), pl(ROCK.lightened(0.12), 0.45)]
	p(M.rbox(Vector3(2.9, 1.6, 2.9), 0.45), rk[0], Vector3(0, 0.8, 0), Vector3(0, 15, 0))
	p(M.rbox(Vector3(2.3, 1.5, 2.3), 0.45), rk[1], Vector3(0.1, 2.25, -0.05), Vector3(4, -12, 3))
	p(M.rbox(Vector3(1.8, 1.4, 1.8), 0.4), rk[2], Vector3(-0.05, 3.6, 0.05), Vector3(-3, 28, 0))
	for i in 5:
		var a := TAU * i / 5.0
		p(M.sphere(_rng.randf_range(0.3, 0.5), 12), rk[i % 3], Vector3(cos(a) * 1.5, 0.25, sin(a) * 1.5), Vector3.ZERO, Vector3(1, 0.7, 1))
	p(M.rbox(Vector3(2.6, 0.25, 2.6), 0.08), pl(WOOD, 0.4), Vector3(0, 4.45, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			p(M.rcyl(0.08, 0.9, 0.03, 8), pl(WOOD_DARK, 0.4), Vector3(1.15 * sx, 4.95, 1.15 * sz))
	for s in [-1.0, 1.0]:
		p(M.rbox(Vector3(2.4, 0.12, 0.12), 0.04), pl(pc), Vector3(0, 5.25, 1.15 * s))
		p(M.rbox(Vector3(0.12, 0.12, 2.4), 0.04), pl(pc), Vector3(1.15 * s, 5.25, 0))
	_flag(pc, Vector3(-1.15, 4.5, -1.15), 1.6)
	out["muzzle"] = Vector3(0, 5.2, 0)


# --- Grondstoffen -------------------------------------------------------------

## Speelgoedkist vol plastic: kist, badeend, bal en stapelringen.
func _toy_chest() -> void:
	p(M.rbox(Vector3(2.4, 1.2, 1.6), 0.15), pl(Color(0.85, 0.22, 0.22)), Vector3(0, 0.6, 0))
	p(M.rbox(Vector3(2.5, 0.2, 1.7), 0.08), pl(Color(0.98, 0.82, 0.25)), Vector3(0, 1.2, 0))
	var lid := pivot(Vector3(0, 1.25, -0.8), Vector3(-110, 0, 0))
	p(M.rbox(Vector3(2.45, 0.2, 1.6), 0.08), pl(Color(0.85, 0.22, 0.22)), Vector3(0, 0.1, 0.8), Vector3.ZERO, Vector3.ONE, lid)
	p(M.sphere(0.48), pl(Color(0.25, 0.55, 0.95)), Vector3(0.55, 1.45, 0.1))
	p(M.rbox(Vector3(0.6, 0.6, 0.6), 0.1), pl(Color(0.3, 0.75, 0.35)), Vector3(-0.5, 1.4, 0.05), Vector3(15, 35, 10))
	_duck(Vector3(1.4, 0, 1.1), -40.0, 1.0)
	# Stapelringen
	var rings := [Color(0.9, 0.2, 0.2), Color(1.0, 0.6, 0.15), Color(0.98, 0.88, 0.2), Color(0.3, 0.75, 0.35), Color(0.3, 0.55, 0.95)]
	var base := Vector3(-1.4, 0, 1.0)
	p(M.rcyl(0.5, 0.15, 0.06, 18), pl(Color(0.3, 0.55, 0.95)), base + Vector3(0, 0.075, 0))
	p(M.rcyl(0.08, 1.3, 0.04, 10), pl(WOOD), base + Vector3(0, 0.7, 0))
	for i in rings.size():
		var rr := 0.45 - i * 0.06
		p(M.torus(rr * 0.35, rr), pl(rings[i]), base + Vector3(0, 0.24 + i * 0.2, 0), Vector3.ZERO, Vector3(1, 1.1, 1))


## Stapel houten bouwblokken in allerlei vormen.
func _block_pile() -> void:
	var colors := [Color(0.92, 0.25, 0.25), Color(0.25, 0.52, 0.95), Color(0.98, 0.82, 0.22), Color(0.3, 0.75, 0.35), Color(0.95, 0.55, 0.2), Color(0.85, 0.65, 0.42)]
	for i in 9:
		var level := 0 if i < 5 else (1 if i < 8 else 2)
		var spread := 1.1 - level * 0.4
		var pos := Vector3(_rng.randf_range(-spread, spread), 0.42 + level * 0.82, _rng.randf_range(-spread, spread))
		var c: Color = colors[_rng.randi() % colors.size()]
		var rot := Vector3(0, _rng.randf_range(0, 90), 0)
		match _rng.randi() % 5:
			0, 1, 2:
				p(M.rbox(Vector3(0.82, 0.82, 0.82), 0.1), pl(c, 0.55), pos, rot)
			3:
				p(M.rcyl(0.4, 0.82, 0.08, 18), pl(c, 0.55), pos, rot)
			4:
				p(M.prism(0.9, 0.8, 0.82), pl(c, 0.55), pos - Vector3(0, 0.41, 0), rot)
	p(M.rbox(Vector3(2.0, 0.4, 0.5), 0.08), pl(colors[_rng.randi() % colors.size()], 0.55), Vector3(0.2, 0.2, 1.3), Vector3(0, 12, 0))


## AA-batterijen: zwart met een gouden kop.
func _batteries() -> void:
	var body := pl(Color(0.1, 0.1, 0.12), 0.9)
	var top := Mat.metal(Color(0.95, 0.65, 0.25), 0.25)
	var nub := Mat.metal(Color(0.85, 0.86, 0.9), 0.2)
	for i in 3:
		var a := TAU * i / 3.0
		var pos := Vector3(cos(a) * 0.5, 0, sin(a) * 0.5)
		var hh := 1.5 - i * 0.05
		p(M.rcyl(0.33, hh * 0.68, 0.05), body, pos + Vector3(0, hh * 0.34, 0))
		p(M.rcyl(0.33, hh * 0.32, 0.05), top, pos + Vector3(0, hh * 0.84, 0))
		p(M.rcyl(0.13, 0.14, 0.04, 12), nub, pos + Vector3(0, hh + 0.05, 0))
		p(M.rbox(Vector3(0.08, 0.3, 0.02), 0.01), pl(WHITE), pos + Vector3(cos(a) * 0.33, hh * 0.45, sin(a) * 0.33), Vector3(0, -rad_to_deg(a) + 90, 0))
	var lying := pivot(Vector3(0.2, 0.3, 1.1), Vector3(0, 70, 90))
	p(M.rcyl(0.3, 0.9, 0.05), body, Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.ONE, lying)
	p(M.rcyl(0.3, 0.45, 0.05), top, Vector3(0, 0.45, 0), Vector3.ZERO, Vector3.ONE, lying)


## Stoffen knikkerzak met knikkers die eruit rollen.
func _marble_bag() -> void:
	var cloth := Mat.matte(Color(0.5, 0.3, 0.62), 0.9)
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.8, 0.02), Vector2(1.0, 0.3), Vector2(0.95, 0.7),
		Vector2(0.6, 1.0), Vector2(0.4, 1.1), Vector2(0.55, 1.35), Vector2(0.45, 1.4), Vector2(0, 1.3)])
	p(M.lathe(prof, 20, "bag"), cloth, Vector3(-0.3, 0, -0.2), Vector3(0, 0, -8))
	p(M.torus(0.38, 0.46), Mat.metal(GOLD, 0.4), Vector3(-0.38, 1.1, -0.2), Vector3(0, 0, -8), Vector3(1, 0.7, 1))
	var colors := [Color(0.35, 0.7, 0.98), Color(0.98, 0.35, 0.55), Color(0.4, 0.95, 0.55), Color(0.98, 0.8, 0.3), Color(0.7, 0.5, 0.98)]
	for i in 9:
		var r := _rng.randf_range(0.2, 0.3)
		var a := _rng.randf_range(-0.6, 1.8)
		var d := _rng.randf_range(0.9, 1.5)
		p(M.sphere(r, 16), Mat.glass(colors[i % colors.size()]), Vector3(cos(a) * d, r, sin(a) * d))


func _duck(pos: Vector3, rot_y: float, k: float) -> void:
	var duck := pivot(pos, Vector3(0, rot_y, 0), null, Vector3.ONE * k)
	var yel := pl(Color(1.0, 0.85, 0.15), 0.9)
	p(M.sphere(0.45), yel, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1, 0.8, 1.25), duck)
	p(M.sphere(0.27), yel, Vector3(0, 0.88, 0.25), Vector3.ZERO, Vector3.ONE, duck)
	p(M.rbox(Vector3(0.22, 0.08, 0.22), 0.04), pl(Color(1.0, 0.5, 0.1)), Vector3(0, 0.84, 0.52), Vector3.ZERO, Vector3.ONE, duck)
	p(M.rcone(0.18, 0.0, 0.3, 8), yel, Vector3(0, 0.55, -0.55), Vector3(-60, 0, 0), Vector3.ONE, duck)
	for s in [-1.0, 1.0]:
		p(M.sphere(0.045, 8), pl(DARK, 1.0), Vector3(0.17 * s, 0.95, 0.43), Vector3.ZERO, Vector3.ONE, duck)


func _icon_blocks() -> void:
	p(M.rbox(Vector3(0.8, 0.8, 0.8), 0.1), pl(Color(0.92, 0.25, 0.25), 0.55), Vector3(-0.3, 0.4, 0), Vector3(0, 20, 0))
	p(M.rbox(Vector3(0.8, 0.8, 0.8), 0.1), pl(Color(0.25, 0.52, 0.95), 0.55), Vector3(0.45, 0.4, 0.2), Vector3(0, -15, 0))
	p(M.rbox(Vector3(0.8, 0.8, 0.8), 0.1), pl(Color(0.98, 0.82, 0.22), 0.55), Vector3(0.1, 1.2, 0.1), Vector3(0, 40, 0))
	text3d("A", Color(0.98, 0.95, 0.88), Vector3(-0.17, 0.4, 0.38), Vector3(0, 20, 0), 60)


func _icon_battery() -> void:
	var b := pivot(Vector3(0, 0.6, 0), Vector3(0, 0, -30))
	p(M.rcyl(0.33, 1.0, 0.05), pl(Color(0.1, 0.1, 0.12), 0.9), Vector3(0, -0.2, 0), Vector3.ZERO, Vector3.ONE, b)
	p(M.rcyl(0.33, 0.45, 0.05), Mat.metal(Color(0.95, 0.65, 0.25), 0.25), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3.ONE, b)
	p(M.rcyl(0.13, 0.14, 0.04, 12), Mat.metal(Color(0.85, 0.86, 0.9), 0.2), Vector3(0, 0.78, 0), Vector3.ZERO, Vector3.ONE, b)
	text3d("+", Color(1, 1, 1), Vector3(0, 0.5, 0.34), Vector3.ZERO, 60, b)


func _icon_marbles() -> void:
	p(M.sphere(0.42, 20), Mat.glass(Color(0.35, 0.7, 0.98)), Vector3(-0.3, 0.42, 0))
	p(M.sphere(0.36, 20), Mat.glass(Color(0.98, 0.35, 0.55)), Vector3(0.42, 0.36, 0.2))
	p(M.sphere(0.32, 20), Mat.glass(Color(0.4, 0.95, 0.55)), Vector3(0.1, 0.95, -0.05))


func _icon_helmet(pc: Color) -> void:
	p(M.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.25, 0), Vector2(0.25, 0.025), Vector2(0.19, 0.05),
		Vector2(0.185, 0.12), Vector2(0.14, 0.19), Vector2(0.07, 0.22), Vector2(0, 0.225)]), 20, "helmet"),
		pl(pc.darkened(0.1), 0.85), Vector3.ZERO, Vector3(-10, 0, 0), Vector3.ONE * 3.0)


func _icon_egg(pc: Color) -> void:
	var egg := pivot(Vector3(0, 0.55, 0), Vector3(0, 0, 12))
	p(M.sphere(0.42), pl(pc.lerp(Color(1, 0.97, 0.88), 0.6)), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1), egg)
	for j in 7:
		var b := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(0.2, 1)).normalized()
		p(M.sphere(0.07, 8), pl(pc.darkened(0.15)), Vector3(b.x * 0.4, b.y * 0.53, b.z * 0.4), Vector3.ZERO, Vector3(1, 0.6, 1), egg)


func _icon_stop() -> void:
	p(M.rcyl(0.6, 0.18, 0.06, 8), pl(Color(0.9, 0.18, 0.15), 0.85), Vector3(0, 0.6, 0), Vector3(90, 22.5, 0))
	p(M.rcyl(0.52, 0.2, 0.04, 8), pl(Color(0.98, 0.97, 0.93), 0.85), Vector3(0, 0.6, -0.01), Vector3(90, 22.5, 0))
	p(M.rcyl(0.47, 0.22, 0.04, 8), pl(Color(0.9, 0.18, 0.15), 0.85), Vector3(0, 0.6, 0), Vector3(90, 22.5, 0))
	p(M.rbox(Vector3(0.62, 0.16, 0.08), 0.05), pl(Color(0.98, 0.97, 0.93), 0.85), Vector3(0, 0.6, 0.13))
