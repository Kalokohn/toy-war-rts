extends RefCounted
## De speelwereld: een zonnige kinderkamer. Houten vloer met planken,
## een gevlochten kleed in het midden, plinten en behang, wat grote spullen
## langs de muren voor de schaal, en de belichting/nabewerking.

const M := preload("res://scripts/visual/toy_mesh.gd")
const Mat := preload("res://scripts/visual/toy_mat.gd")

const NOISE := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
"""

const FLOOR_SHADER := """
shader_type spatial;
uniform float plank_w = 4.0;
uniform float plank_len = 24.0;
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float col = floor(p.x / plank_w);
	float offs = hash(vec2(col, 7.0)) * plank_len;
	float row = floor((p.y + offs) / plank_len);
	vec2 id = vec2(col, row);
	vec2 local = vec2(fract(p.x / plank_w), fract((p.y + offs) / plank_len));
	float h = hash(id);
	float g = fbm(vec2(p.x * 1.3 + h * 17.0, p.y * 0.09 + h * 5.0));
	float rings = sin(p.x * 2.4 + g * 9.0 + h * 30.0) * 0.5 + 0.5;
	float fine = noise(vec2(p.x * 9.0, p.y * 0.35 + h * 40.0));
	vec3 light = vec3(0.62, 0.38, 0.2);
	vec3 darkc = vec3(0.4, 0.22, 0.1);
	vec3 base = mix(light, darkc, clamp(rings * 0.45 + g * 0.35 + fine * 0.2, 0.0, 1.0));
	base *= 0.86 + h * 0.26;
	float gx = min(local.x, 1.0 - local.x) * plank_w;
	float gz = min(local.y, 1.0 - local.y) * plank_len;
	float gap = smoothstep(0.02, 0.07, min(gx, gz));
	base *= mix(0.3, 1.0, gap);
	ALBEDO = base;
	ROUGHNESS = mix(0.22, 0.42, g) + (1.0 - gap) * 0.4;
	SPECULAR = 0.55;
	NORMAL_MAP = normalize(vec3(0.5 + (fine - 0.5) * 0.12, 0.5, 1.0));
}
"""

const RUG_SHADER := """
shader_type spatial;
uniform vec3 center = vec3(0.0);
uniform float band_w = 0.8;
varying vec3 wpos;
%s
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	const vec3 pal[6] = vec3[6](vec3(0.88, 0.8, 0.66), vec3(0.28, 0.42, 0.6), vec3(0.75, 0.33, 0.24),
		vec3(0.88, 0.64, 0.24), vec3(0.42, 0.56, 0.38), vec3(0.62, 0.4, 0.55));
	vec2 d = wpos.xz - center.xz;
	float r = length(d);
	float a = atan(d.y, d.x);
	float band = r / band_w;
	float idx = floor(band);
	float f = fract(band);
	int i = int(mod(idx * 4.0 + floor(hash(vec2(idx, 3.0)) * 3.0), 6.0));
	if (idx < 3.0) { i = 2; }
	if (r > 36.6) { i = 1; }
	vec3 c = pal[i];
	float s_arc = a * max(r, 1.0) * 5.0;
	float fade = 1.0 - smoothstep(0.4, 1.2, fwidth(s_arc));
	float braid = sin(s_arc + (f - 0.5) * 9.0 * (mod(idx, 2.0) * 2.0 - 1.0)) * fade;
	c *= 0.84 + 0.16 * braid;
	c *= mix(0.62, 1.0, smoothstep(0.0, 0.14, f) * smoothstep(1.0, 0.86, f));
	float fuzz = noise(wpos.xz * 22.0) * 0.5 + noise(wpos.xz * 47.0) * 0.5;
	c *= 0.9 + fuzz * 0.18;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	NORMAL_MAP = normalize(vec3(0.5 + braid * 0.03, 0.5 + (fuzz - 0.5) * 0.15, 1.0));
}
"""

const WALL_SHADER := """
shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float u = wpos.x + wpos.z;
	float stripe = smoothstep(0.45, 0.5, abs(fract(u / 6.0) - 0.5) * 2.0);
	vec3 c = mix(vec3(0.95, 0.9, 0.82), vec3(0.86, 0.9, 0.95), stripe);
	float dots = step(0.82, sin(u * 2.0) * sin(wpos.y * 2.0));
	c = mix(c, vec3(0.98, 0.8, 0.55), dots * (1.0 - stripe) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""


static func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func _mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func build(parent: Node, map_half: float) -> void:
	_environment(parent)
	var size := map_half * 2.0 + 24.0
	# Vloer
	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(size, size)
	_mesh(parent, floor_plane, _shader_mat(FLOOR_SHADER % NOISE), Vector3.ZERO, Vector3.ZERO, false)
	# Gevlochten kleed in het midden
	var rug := _shader_mat(RUG_SHADER % NOISE)
	_mesh(parent, M.rcyl(38.0, 0.06, 0.03, 96), rug, Vector3(0, 0.0, 0), Vector3.ZERO, false)
	# Plinten en behang
	var wall_mat := _shader_mat(WALL_SHADER)
	var trim := Mat.plastic(Color(0.97, 0.96, 0.93), 0.5)
	var w := map_half + 1.5
	for s in [-1.0, 1.0]:
		_mesh(parent, M.rbox(Vector3(size, 2.4, 1.0), 0.2), trim, Vector3(0, 1.2, s * w))
		_mesh(parent, M.rbox(Vector3(1.0, 2.4, size), 0.2), trim, Vector3(s * w, 1.2, 0))
		_mesh(parent, BoxMesh.new(), wall_mat, Vector3(0, 20, s * (w + 0.6))).scale = Vector3(size, 40, 0.4)
		_mesh(parent, BoxMesh.new(), wall_mat, Vector3(s * (w + 0.6), 20, 0)).scale = Vector3(0.4, 40, size)
	_props(parent, map_half)


static func _environment(parent: Node) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.62, 0.74, 0.92)
	sm.sky_horizon_color = Color(0.98, 0.9, 0.78)
	sm.ground_horizon_color = Color(0.85, 0.66, 0.46)
	sm.ground_bottom_color = Color(0.55, 0.38, 0.24)
	sm.sun_angle_max = 20.0
	sm.sky_energy_multiplier = 1.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 1.0
	we.environment = env
	parent.add_child(we)

	# Zonlicht door het raam, warm, met zachte schaduwen.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_max_distance = 130.0
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)
	# Koel invullicht van de andere kant (blauwe lucht).
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color(0.65, 0.75, 1.0)
	fill.light_energy = 0.28
	fill.light_specular = 0.3
	parent.add_child(fill)


## Grote spullen langs de muren, zodat je ziet hoe klein de soldaatjes zijn.
static func _props(parent: Node, map_half: float) -> void:
	var e := map_half - 4.0
	# Waskrijtjes
	var crayons := [[Vector3(-30, 0, e + 1.5), 8.0, Color(0.9, 0.2, 0.25)], [Vector3(-24, 0, e + 2.2), -6.0, Color(0.25, 0.55, 0.95)],
		[Vector3(e + 1.8, 0, 22), 95.0, Color(0.98, 0.8, 0.2)], [Vector3(-e - 1.8, 0, -25), 80.0, Color(0.3, 0.75, 0.35)],
		[Vector3(18, 0, -e - 1.5), 3.0, Color(0.95, 0.5, 0.15)]]
	for c in crayons:
		var n := Node3D.new()
		n.position = c[0] + Vector3(0, 0.75, 0)
		n.rotation_degrees = Vector3(0, c[1], 90)
		parent.add_child(n)
		var col: Color = c[2]
		_mesh(n, M.rcyl(0.75, 9.0, 0.1, 18), Mat.plastic(col, 0.35), Vector3.ZERO)
		_mesh(n, M.rcyl(0.78, 6.0, 0.05, 18), Mat.matte(col.lightened(0.35)), Vector3(0, -0.6, 0))
		_mesh(n, M.rcone(0.75, 0.2, 1.6, 18), Mat.plastic(col, 0.35), Vector3(0, 5.3, 0))
	# Stapel boeken in een hoek
	var book_cols := [Color(0.75, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.95, 0.75, 0.25), Color(0.3, 0.6, 0.4)]
	var y := 0.0
	for i in 4:
		var h := 1.4 + (i % 2) * 0.4
		var n := Node3D.new()
		n.position = Vector3(e - 1.0, y + h * 0.5, -e + 1.0)
		n.rotation_degrees = Vector3(0, 10 + i * 9.0, 0)
		parent.add_child(n)
		_mesh(n, M.rbox(Vector3(13.0 - i, h, 10.0 - i * 0.6), 0.25), Mat.plastic(book_cols[i], 0.3), Vector3.ZERO)
		_mesh(n, M.rbox(Vector3(12.6 - i, h - 0.3, 9.8 - i * 0.6), 0.1), Mat.matte(Color(0.97, 0.95, 0.88)), Vector3(0.3, 0, 0.15))
		y += h
	# Strandbal
	var ball := Node3D.new()
	ball.position = Vector3(-e + 2.0, 5.0, e - 2.0)
	ball.rotation_degrees = Vector3(20, 30, 10)
	parent.add_child(ball)
	var bm := _shader_mat("""
shader_type spatial;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	const vec3 cols[6] = vec3[6](vec3(0.95, 0.22, 0.22), vec3(0.98, 0.97, 0.93), vec3(0.22, 0.5, 0.95),
		vec3(0.98, 0.97, 0.93), vec3(0.98, 0.8, 0.18), vec3(0.98, 0.97, 0.93));
	float a = atan(lp.x, lp.z) / 6.2831853 + 0.5;
	vec3 c = cols[int(floor(a * 6.0)) % 6];
	if (abs(lp.y) > 4.6) { c = vec3(0.98, 0.97, 0.93); }
	ALBEDO = c;
	ROUGHNESS = 0.2;
	SPECULAR = 0.6;
}
""")
	_mesh(ball, M.sphere(5.0, 36), bm, Vector3.ZERO)
	# Speelgoedautootje
	var car := Node3D.new()
	car.position = Vector3(e - 2.0, 0, e - 18.0)
	car.rotation_degrees = Vector3(0, -70, 0)
	parent.add_child(car)
	_mesh(car, M.rbox(Vector3(3.2, 1.3, 6.5), 0.5), Mat.plastic(Color(0.9, 0.2, 0.2), 0.95), Vector3(0, 1.4, 0))
	_mesh(car, M.rbox(Vector3(2.8, 1.2, 3.2), 0.5), Mat.plastic(Color(0.9, 0.2, 0.2), 0.95), Vector3(0, 2.5, -0.4))
	_mesh(car, M.rbox(Vector3(2.9, 0.9, 2.9), 0.35), Mat.glass(Color(0.3, 0.45, 0.6)), Vector3(0, 2.55, -0.4))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh(car, M.rcyl(0.85, 0.6, 0.2, 20), Mat.plastic(Color(0.12, 0.12, 0.14), 0.4), Vector3(1.6 * sx, 0.85, 2.0 * sz), Vector3(0, 0, 90))
			_mesh(car, M.rcyl(0.4, 0.64, 0.1, 14), Mat.metal(Color(0.85, 0.85, 0.9)), Vector3(1.62 * sx, 0.85, 2.0 * sz), Vector3(0, 0, 90))
