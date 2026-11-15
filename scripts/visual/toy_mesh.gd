extends RefCounted
## Procedurele meshes met afgeronde randen, zodat alles eruitziet als
## spuitgietplastic in plaats van harde blokjes. Meshes worden gecachet.

static var _cache := {}


## Doos met afgeronde randen en hoeken.
static func rbox(size: Vector3, r := 0.08, seg := 3) -> Mesh:
	r = minf(r, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.001)
	if r <= 0.002:
		var b := BoxMesh.new()
		b.size = size
		return b
	var key := "rbox|%s|%.3f|%d" % [size, r, seg]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var inner := h - Vector3(r, r, r)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Per vlak: normaal-as, twee raaklijn-assen.
	var faces := [[0, 1, 2], [1, 2, 0], [2, 0, 1]]
	for f in faces:
		var n: int = f[0]
		var a: int = f[1]
		var b: int = f[2]
		for s in [-1.0, 1.0]:
			var ca := _axis_coords(h[a], r, seg)
			var cb := _axis_coords(h[b], r, seg)
			var base := verts.size()
			for j in cb.size():
				for i in ca.size():
					var p := Vector3()
					p[n] = s * h[n]
					p[a] = ca[i]
					p[b] = cb[j]
					var c := p.clamp(-inner, inner)
					var d := p - c
					var nrm: Vector3 = d.normalized() if d.length() > 0.00001 else Vector3()
					if nrm == Vector3():
						nrm[n] = s
					verts.append(c + nrm * r)
					norms.append(nrm)
					uvs.append(Vector2(ca[i] / size[a] + 0.5, cb[j] / size[b] + 0.5))
			var w := ca.size()
			for j in cb.size() - 1:
				for i in w - 1:
					var i0 := base + j * w + i
					var i1 := i0 + 1
					var i2 := i0 + w
					var i3 := i2 + 1
					_tri(idx, verts, i0, i1, i3, norms[i0])
					_tri(idx, verts, i0, i3, i2, norms[i0])
	var m := _arrays_mesh(verts, norms, uvs, idx)
	_cache[key] = m
	return m


static func _axis_coords(hh: float, r: float, seg: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var inn := hh - r
	for k in seg + 1:
		var a := PI * 0.5 * float(k) / seg
		out.append(-inn - r * cos(a))
	for k in range(seg, -1, -1):
		var a := PI * 0.5 * float(k) / seg
		out.append(inn + r * cos(a))
	return out


## Voegt een driehoek toe met de goede draairichting (Godot: met de klok mee = voorkant).
static func _tri(idx: PackedInt32Array, v: PackedVector3Array, i0: int, i1: int, i2: int, outward: Vector3) -> void:
	var cr := (v[i1] - v[i0]).cross(v[i2] - v[i0])
	if cr.length_squared() < 1e-12:
		# Ontaarde driehoek (in een hoek): toch toevoegen, kijk naar de normaal.
		cr = outward
	if cr.dot(outward) > 0.0:
		idx.append_array([i0, i2, i1])
	else:
		idx.append_array([i0, i1, i2])


static func _arrays_mesh(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Draait een profiel (x = straal, y = hoogte, van onder naar boven) rond de Y-as.
static func lathe(profile: PackedVector2Array, segs := 24, key := "") -> Mesh:
	if key != "" and _cache.has(key):
		return _cache[key]
	var n := profile.size()
	# Normalen in het profiel (gemiddelde van aangrenzende segmenten).
	var pn := PackedVector2Array()
	for i in n:
		var t := Vector2.ZERO
		if i > 0:
			t += (profile[i] - profile[i - 1]).normalized()
		if i < n - 1:
			t += (profile[i + 1] - profile[i]).normalized()
		pn.append(Vector2(t.y, -t.x).normalized())
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for s in segs + 1:
		var a := TAU * float(s) / segs
		var ca := cos(a)
		var sa := sin(a)
		for i in n:
			var p := profile[i]
			verts.append(Vector3(p.x * ca, p.y, p.x * sa))
			norms.append(Vector3(pn[i].x * ca, pn[i].y, pn[i].x * sa).normalized())
			uvs.append(Vector2(float(s) / segs, float(i) / (n - 1)))
	for s in segs:
		for i in n - 1:
			var i0 := s * n + i
			var i1 := i0 + 1
			var i2 := i0 + n
			var i3 := i2 + 1
			var out := (norms[i0] + norms[i3]).normalized()
			_tri(idx, verts, i0, i2, i3, out)
			_tri(idx, verts, i0, i3, i1, out)
	var m := _arrays_mesh(verts, norms, uvs, idx)
	if key != "":
		_cache[key] = m
	return m


## Cilinder met afgeronde randen (knopjes, voetstukken, batterijen).
static func rcyl(radius: float, height: float, r := 0.05, segs := 24) -> Mesh:
	r = minf(r, minf(radius, height * 0.5) - 0.001)
	var key := "rcyl|%.3f|%.3f|%.3f|%d" % [radius, height, r, segs]
	if _cache.has(key):
		return _cache[key]
	var p := PackedVector2Array()
	var hh := height * 0.5
	p.append(Vector2(0.0, -hh))
	if r > 0.002:
		for k in 5:
			var a := PI * 0.5 * float(k) / 4.0
			p.append(Vector2(radius - r + sin(a) * r, -hh + r - cos(a) * r))
		for k in 5:
			var a := PI * 0.5 * float(k) / 4.0
			p.append(Vector2(radius - r + cos(a) * r, hh - r + sin(a) * r))
	else:
		p.append(Vector2(radius, -hh))
		p.append(Vector2(radius, -hh))
		p.append(Vector2(radius, hh))
		p.append(Vector2(radius, hh))
	p.append(Vector2(0.0, hh))
	return lathe(p, segs, key)


## Afgeknotte kegel met afgeronde rand onder en boven.
static func rcone(bottom: float, top: float, height: float, segs := 24) -> Mesh:
	var key := "rcone|%.3f|%.3f|%.3f|%d" % [bottom, top, height, segs]
	if _cache.has(key):
		return _cache[key]
	var hh := height * 0.5
	var p := PackedVector2Array([
		Vector2(0, -hh), Vector2(bottom * 0.96, -hh), Vector2(bottom, -hh + 0.03),
		Vector2(top, hh - 0.02), Vector2(top * 0.9, hh), Vector2(0, hh)])
	return lathe(p, segs, key)


static func sphere(r: float, segs := 20) -> Mesh:
	var key := "sph|%.3f|%d" % [r, segs]
	if _cache.has(key):
		return _cache[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = segs / 2
	_cache[key] = m
	return m


static func capsule(r: float, h: float) -> Mesh:
	var key := "cap|%.3f|%.3f" % [r, h]
	if _cache.has(key):
		return _cache[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 16
	m.rings = 6
	_cache[key] = m
	return m


static func torus(inner: float, outer: float) -> Mesh:
	var key := "tor|%.3f|%.3f" % [inner, outer]
	if _cache.has(key):
		return _cache[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 10
	_cache[key] = m
	return m


## Prisma (dakvorm): driehoek in het XY-vlak, diepte langs Z.
static func prism(w: float, h: float, d: float) -> Mesh:
	var key := "prism|%.3f|%.3f|%.3f" % [w, h, d]
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-w * 0.5, 0, 0)
	var b := Vector3(w * 0.5, 0, 0)
	var c := Vector3(0, h, 0)
	var zf := Vector3(0, 0, d * 0.5)
	var zb := Vector3(0, 0, -d * 0.5)
	var quads := [[a + zb, c + zb, c + zf, a + zf], [c + zb, b + zb, b + zf, c + zf], [b + zb, a + zb, a + zf, b + zf]]
	for q in quads:
		var nrm: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		if nrm.dot((q[0] + q[2]) * 0.5 - Vector3(0, h / 3.0, 0)) < 0:
			nrm = -nrm
		_st_quad(st, q, nrm)
	for s in [zf, zb]:
		var nrm: Vector3 = s.normalized()
		var tri := [a + s, b + s, c + s]
		var cr: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
		if cr.dot(nrm) > 0:
			tri = [tri[0], tri[2], tri[1]]
		for v in tri:
			st.set_normal(nrm)
			st.add_vertex(v)
	var m := st.commit()
	_cache[key] = m
	return m


static func _st_quad(st: SurfaceTool, q: Array, nrm: Vector3) -> void:
	var tris := [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
	for t in tris:
		var cr: Vector3 = (t[1] - t[0]).cross(t[2] - t[0])
		if cr.dot(nrm) > 0:
			t = [t[0], t[2], t[1]]
		for v in t:
			st.set_normal(nrm)
			st.add_vertex(v)


## Plat vlak (voor vleugels, vlaggen): breedte X, diepte Z, dubbelzijdig via materiaal.
static func plane(w: float, d: float) -> Mesh:
	var key := "plane|%.3f|%.3f" % [w, d]
	if _cache.has(key):
		return _cache[key]
	var m := PlaneMesh.new()
	m.size = Vector2(w, d)
	_cache[key] = m
	return m
