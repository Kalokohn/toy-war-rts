extends RefCounted
## Kleine effecten die alleen visueel zijn (geen invloed op de simulatie):
## raakeffect, poef bij doodgaan, mondingsvuur en bouwstof.

const M := preload("res://scripts/visual/toy_mesh.gd")
const Mat := preload("res://scripts/visual/toy_mat.gd")


static func _burst(parent: Node, pos: Vector3, color: Color, amount: int, speed: float, size: float, life: float, spread := 70.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.mesh = M.rbox(Vector3(size, size, size), size * 0.25, 1)
	p.material_override = Mat.plastic(color)
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -18, 0)
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.angle_max = 180
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.75, 0.9))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Plastic splintertjes als iets geraakt wordt.
static func hit(parent: Node, pos: Vector3, color: Color) -> void:
	_burst(parent, pos, color, 6, 4.0, 0.09, 0.5)
	_burst(parent, pos, Color(1, 0.95, 0.7), 3, 3.0, 0.06, 0.25)


## Een unit of gebouw valt in stukjes uit elkaar.
static func poof(parent: Node, pos: Vector3, color: Color, big := false) -> void:
	if big:
		_burst(parent, pos + Vector3(0, 1.5, 0), color, 40, 9.0, 0.35, 1.4, 80.0)
		_burst(parent, pos + Vector3(0, 1.0, 0), Color(0.9, 0.88, 0.82), 24, 6.0, 0.25, 1.2, 90.0)
		_smoke(parent, pos, 3.0)
	else:
		_burst(parent, pos + Vector3(0, 0.7, 0), color, 16, 6.0, 0.14, 0.9)
		_burst(parent, pos + Vector3(0, 0.7, 0), Color(1, 1, 1), 6, 4.0, 0.08, 0.6)
		_smoke(parent, pos, 1.0)


static func _smoke(parent: Node, pos: Vector3, s: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = int(8 * s)
	p.lifetime = 0.9
	p.mesh = M.sphere(0.35 * s, 10)
	p.material_override = Mat.matte(Color(0.95, 0.93, 0.9), 1.0)
	p.direction = Vector3.UP
	p.spread = 90
	p.initial_velocity_min = 1.0 * s
	p.initial_velocity_max = 2.5 * s
	p.gravity = Vector3(0, 1.5, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = pos + Vector3(0, 0.4, 0)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Mondingsvuur: een kort flitsje met licht.
static func muzzle(parent: Node, pos: Vector3, color := Color(1.0, 0.8, 0.35)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = M.sphere(0.16, 10)
	mi.material_override = Mat.glow(color, 6.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 2.0
	l.omni_range = 3.0
	n.add_child(l)
	var tw := n.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.07)
	tw.parallel().tween_property(l, "light_energy", 0.0, 0.09)
	tw.tween_callback(n.queue_free)


## Klein wolkje stof/sterretjes bij bouwen en verzamelen.
static func dust(parent: Node, pos: Vector3, color := Color(0.95, 0.9, 0.75)) -> void:
	_burst(parent, pos, color, 3, 2.2, 0.09, 0.35, 45.0)
