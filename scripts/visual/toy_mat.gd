extends RefCounted
## Gedeelde materialen. Alles is glimmend spuitgietplastic, behalve een paar
## uitzonderingen (metaal, glas, stof, hout, lava).

static var _cache := {}


## Glanzend plastic. gloss 0..1 (1 = heel glad).
static func plastic(color: Color, gloss := 0.75) -> Material:
	var key := "pl|%s|%.2f" % [color.to_html(true), gloss]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = lerpf(0.6, 0.16, gloss)
	m.metallic_specular = 0.6
	m.clearcoat_enabled = true
	m.clearcoat = 0.35 * gloss
	m.clearcoat_roughness = 0.15
	m.rim_enabled = true
	m.rim = 0.18
	m.rim_tint = 0.6
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m


static func metal(color: Color, rough := 0.28) -> Material:
	var key := "mt|%s|%.2f" % [color.to_html(true), rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.85
	m.roughness = rough
	_cache[key] = m
	return m


## Knikkerglas: glad, met wat eigen gloed zodat het "doorschijnend" oogt.
static func glass(color: Color) -> Material:
	var key := "gl|%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.15)
	m.roughness = 0.04
	m.metallic_specular = 1.0
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.02
	m.emission_enabled = true
	m.emission = color * 0.35
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.2
	_cache[key] = m
	return m


static func matte(color: Color, rough := 0.85) -> Material:
	var key := "mat|%s|%.2f" % [color.to_html(true), rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	_cache[key] = m
	return m


static func glow(color: Color, energy := 2.0) -> Material:
	var key := "glow|%s|%.2f" % [color.to_html(true), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[key] = m
	return m


static func unshaded(color: Color, double_sided := false) -> Material:
	var key := "un|%s|%s" % [color.to_html(true), double_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Dubbelzijdig plastic (vleugels, vlaggen).
static func plastic2(color: Color) -> Material:
	var key := "pl2|%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var m: StandardMaterial3D = plastic(color).duplicate()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Spookmateriaal voor de plaatsingspreview van gebouwen.
static func ghost(color: Color) -> Material:
	var key := "ghost|%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	_cache[key] = m
	return m


const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 color : source_color = vec4(0.3, 1.0, 0.3, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = smoothstep(0.70, 0.80, d) * (1.0 - smoothstep(0.90, 1.0, d));
	float glow = smoothstep(0.6, 0.82, d) * (1.0 - smoothstep(0.82, 1.0, d)) * 0.3;
	float a = atan(p.y, p.x);
	float dash = 0.75 + 0.25 * step(0.0, sin(a * 10.0 + TIME * 3.0));
	float v = ring * dash + glow;
	ALBEDO = color.rgb * v;
	ALPHA = clamp(v, 0.0, 1.0);
}
"""


## Gloeiende selectiering op de grond.
static func ring(color: Color) -> Material:
	var key := "ring|%s" % color.to_html(true)
	if _cache.has(key):
		return _cache[key]
	var sh := Shader.new()
	sh.code = RING_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("color", color)
	_cache[key] = m
	return m


## Zachte ronde schaduwvlek onder units (contactschaduw).
static func blob_shadow() -> Material:
	if _cache.has("blob"):
		return _cache["blob"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.05, 0.03, 0.02);
	ALPHA = (1.0 - smoothstep(0.2, 1.0, d)) * 0.45;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_cache["blob"] = m
	return m
