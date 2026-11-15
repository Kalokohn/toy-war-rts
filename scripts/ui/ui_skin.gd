extends RefCounted
## Het uiterlijk van de interface: een speelgoeddoos-thema met glimmende
## plastic panelen, schroefjes, dikke knoppen en een rond lettertype.
## Alle texturen worden bij het opstarten getekend (geen plaatjes nodig).

const CREAM := Color(0.98, 0.94, 0.84)
const CREAM_DIM := Color(0.8, 0.78, 0.72)
const GOLD := Color(1.0, 0.8, 0.25)
const INK := Color(0.24, 0.14, 0.06)
const GOOD := Color(0.45, 0.9, 0.35)
const BAD := Color(1.0, 0.4, 0.35)

static var _theme: Theme
static var _cache := {}
static var font_body: Font
static var font_title: Font


static func fonts() -> void:
	if font_body:
		return
	var fred: FontFile = load("res://assets/fonts/Fredoka-Variable.ttf")
	var fv := FontVariation.new()
	fv.base_font = fred
	fv.variation_opentype = {"wght": 600}
	font_body = fv
	font_title = load("res://assets/fonts/LilitaOne-Regular.ttf")


# --- Pixeltekenaar ------------------------------------------------------------

static func _sd_rrect(p: Vector2, center: Vector2, half: Vector2, r: float) -> float:
	var q := (p - center).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


static func _cov(sd: float) -> float:
	return clampf(0.5 - sd, 0.0, 1.0)


static func _over(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if a <= 0.0:
		return
	var src := Color(c.r, c.g, c.b, c.a * a)
	img.set_pixel(x, y, img.get_pixel(x, y).blend(src))


## Tekent een plastic "tegel".
## st: {size, radius, top, bottom, lip, lip_h, outline, hl, gloss, shadow, screws, inset, press, border, border_w}
static func _tile(st: Dictionary) -> ImageTexture:
	var key := str(st)
	if _cache.has(key):
		return _cache[key]
	var size: int = st.get("size", 64)
	var r: float = st.get("radius", 12.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var shadow: float = st.get("shadow", 4.0)
	var lip_h: float = st.get("lip_h", 4.0)
	var press: float = st.get("press", 0.0)
	var top: Color = st.get("top", Color(0.2, 0.3, 0.55))
	var bottom: Color = st.get("bottom", Color(0.12, 0.18, 0.36))
	var lip: Color = st.get("lip", bottom.darkened(0.4))
	var outline: Color = st.get("outline", Color(0.05, 0.07, 0.15))
	var hl: Color = st.get("hl", top.lightened(0.35))
	var gloss: float = st.get("gloss", 0.12)
	var inset: bool = st.get("inset", false)
	var border: Color = st.get("border", Color(0, 0, 0, 0))
	var border_w: float = st.get("border_w", 0.0)
	var w := float(size)
	var body_h := w - shadow
	var c_out := Vector2(w * 0.5, body_h * 0.5)
	var h_out := Vector2(w * 0.5 - 0.5, body_h * 0.5 - 0.5)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			# Schaduw onder het paneel
			if shadow > 0.0:
				var sd_s := _sd_rrect(p, c_out + Vector2(0, shadow * 0.8), h_out, r)
				_over(img, x, y, Color(0, 0, 0, 0.35), clampf(1.0 - (sd_s + 1.5) / 4.0, 0.0, 1.0))
			# Rand
			var sd := _sd_rrect(p, c_out, h_out, r)
			_over(img, x, y, outline, _cov(sd))
			if inset:
				# Verzonken: donker met binnenschaduw bovenaan en een lichte onderrand.
				var sd_i := _sd_rrect(p, c_out, h_out - Vector2(1.5, 1.5), r - 1.5)
				var t := clampf((p.y - 2.0) / (body_h - 4.0), 0.0, 1.0)
				_over(img, x, y, top.lerp(bottom, t), _cov(sd_i))
				var sd_sh := _sd_rrect(p, c_out + Vector2(0, 3), h_out - Vector2(1.5, 1.5), r - 1.5)
				var inner := clampf((sd_sh + 4.0) / 4.0, 0.0, 1.0) * _cov(sd_i)
				_over(img, x, y, Color(0, 0, 0, 0.55), inner)
				if p.y > body_h * 0.5 and sd_i > -1.6 and sd_i < 0.5:
					_over(img, x, y, hl, 0.6)
			else:
				# Onderlip (de dikte van het plastic)
				var sd_l := _sd_rrect(p, c_out, h_out - Vector2(1.5, 1.5), r - 1.5)
				_over(img, x, y, lip, _cov(sd_l))
				# Bovenvlak
				var face_top := 2.0 + press
				var face_bot := body_h - 2.0 - lip_h + press
				var fc := Vector2(w * 0.5, (face_top + face_bot) * 0.5)
				var fh := Vector2(w * 0.5 - 2.0, (face_bot - face_top) * 0.5)
				var sd_f := _sd_rrect(p, fc, fh, r - 2.0)
				var t := clampf((p.y - face_top) / maxf(face_bot - face_top, 1.0), 0.0, 1.0)
				_over(img, x, y, top.lerp(bottom, t), _cov(sd_f))
				# Glimlicht langs de bovenrand
				if sd_f < 0.0 and sd_f > -2.2 and p.y < fc.y:
					_over(img, x, y, hl, 0.75 * (1.0 - t))
				# Glans op de bovenste helft
				if gloss > 0.0 and p.y < face_top + (face_bot - face_top) * 0.42:
					_over(img, x, y, Color(1, 1, 1, gloss), _cov(sd_f + 3.0))
				if border_w > 0.0:
					_over(img, x, y, border, _cov(sd_f) - _cov(sd_f + border_w))
	# Schroefjes in de hoeken
	if st.get("screws", false):
		var o := r * 0.62 + 3.0
		for c in [Vector2(o, o), Vector2(w - o, o), Vector2(o, body_h - lip_h - o), Vector2(w - o, body_h - lip_h - o)]:
			_screw(img, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _screw(img: Image, c: Vector2) -> void:
	var rad := 3.6
	for y in range(int(c.y - 6), int(c.y + 6)):
		for x in range(int(c.x - 6), int(c.x + 6)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			_over(img, x, y, Color(0, 0, 0, 0.4), _cov(d - rad - 0.8))
			var t := clampf((p.y - c.y + rad) / (rad * 2.0), 0.0, 1.0)
			_over(img, x, y, Color(0.92, 0.9, 0.85).lerp(Color(0.55, 0.53, 0.5), t), _cov(d - rad))
			var q := (p - c).rotated(0.6)
			if absf(q.y) < 0.7 and absf(q.x) < rad - 1.0:
				_over(img, x, y, Color(0.3, 0.28, 0.26), 0.9)


static func _sb(tex: Texture2D, margin: float, content: Vector4, shadow := 4.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin + shadow
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb


# --- Stijlen -------------------------------------------------------------------

static func panel_style(screws := true) -> StyleBox:
	return _sb(_tile({"size": 64, "radius": 16.0, "top": Color(0.22, 0.33, 0.6), "bottom": Color(0.13, 0.2, 0.4),
		"lip": Color(0.07, 0.1, 0.22), "lip_h": 5.0, "hl": Color(0.45, 0.6, 0.95), "gloss": 0.05, "screws": screws}),
		24.0, Vector4(18, 14, 18, 18), 4.0)


static func inset_style(radius := 10.0) -> StyleBox:
	return _sb(_tile({"size": 48, "radius": radius, "top": Color(0.05, 0.07, 0.15), "bottom": Color(0.09, 0.12, 0.24),
		"outline": Color(0.04, 0.05, 0.1), "hl": Color(0.35, 0.48, 0.8), "inset": true, "shadow": 0.0}),
		radius + 4.0, Vector4(8, 6, 8, 6), 0.0)


static func pill_style() -> StyleBox:
	return inset_style(14.0)


static func button_style(kind: String, state: String) -> StyleBox:
	var top := Color(1.0, 0.85, 0.32)
	var bottom := Color(0.98, 0.64, 0.12)
	var lip := Color(0.72, 0.38, 0.05)
	var outline := Color(0.33, 0.17, 0.03)
	match kind:
		"red":
			top = Color(1.0, 0.45, 0.4)
			bottom = Color(0.86, 0.2, 0.18)
			lip = Color(0.55, 0.08, 0.08)
			outline = Color(0.28, 0.04, 0.04)
		"green":
			top = Color(0.55, 0.92, 0.42)
			bottom = Color(0.25, 0.7, 0.22)
			lip = Color(0.12, 0.42, 0.1)
			outline = Color(0.05, 0.2, 0.04)
		"slot":
			top = Color(0.3, 0.45, 0.78)
			bottom = Color(0.18, 0.28, 0.55)
			lip = Color(0.08, 0.12, 0.28)
			outline = Color(0.04, 0.06, 0.14)
	var press := 0.0
	var lip_h := 5.0
	var border := Color(0, 0, 0, 0)
	var border_w := 0.0
	match state:
		"hover":
			top = top.lightened(0.15)
			bottom = bottom.lightened(0.12)
			if kind == "slot":
				border = GOLD
				border_w = 2.5
		"pressed":
			press = 3.0
			lip_h = 2.0
			top = top.darkened(0.05)
			bottom = bottom.darkened(0.08)
			if kind == "slot":
				border = GOLD
				border_w = 2.5
		"disabled":
			top = top.lerp(Color(0.45, 0.45, 0.48), 0.75)
			bottom = bottom.lerp(Color(0.3, 0.3, 0.33), 0.75)
			lip = lip.lerp(Color(0.18, 0.18, 0.2), 0.75)
	var r := 10.0 if kind == "slot" else 13.0
	var tex := _tile({"size": 56, "radius": r, "top": top, "bottom": bottom, "lip": lip, "outline": outline,
		"lip_h": lip_h, "press": press, "gloss": 0.16, "shadow": 3.0, "border": border, "border_w": border_w,
		"hl": top.lightened(0.45)})
	var cm := Vector4(14, 8 + press, 14, 10 - press) if kind != "slot" else Vector4(5, 4 + press, 5, 8 - press)
	return _sb(tex, r + 6.0, cm, 3.0)


static func tooltip_style() -> StyleBox:
	return _sb(_tile({"size": 48, "radius": 10.0, "top": Color(1.0, 0.97, 0.88), "bottom": Color(0.96, 0.88, 0.7),
		"lip": Color(0.7, 0.55, 0.32), "outline": Color(0.3, 0.18, 0.07), "lip_h": 3.0, "gloss": 0.0, "shadow": 3.0,
		"hl": Color(1, 1, 1)}), 14.0, Vector4(12, 9, 12, 11), 3.0)


static func bar_fill(color: Color) -> StyleBox:
	return _sb(_tile({"size": 24, "radius": 5.0, "top": color.lightened(0.3), "bottom": color.darkened(0.1),
		"lip": color.darkened(0.45), "outline": Color(0, 0, 0, 0.0), "lip_h": 2.0, "gloss": 0.25, "shadow": 0.0,
		"hl": color.lightened(0.6)}), 7.0, Vector4(0, 0, 0, 0), 0.0)


static func bar_bg() -> StyleBox:
	return _sb(_tile({"size": 24, "radius": 6.0, "top": Color(0.03, 0.04, 0.09), "bottom": Color(0.08, 0.1, 0.18),
		"outline": Color(0.02, 0.03, 0.06), "hl": Color(0.3, 0.4, 0.7), "inset": true, "shadow": 0.0}), 8.0, Vector4(2, 2, 2, 2), 0.0)


# --- Thema ---------------------------------------------------------------------

static func theme() -> Theme:
	if _theme:
		return _theme
	fonts()
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 17
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", inset_style())
	t.set_type_variation("PillPanel", "PanelContainer")
	t.set_stylebox("panel", "PillPanel", pill_style())
	t.set_type_variation("PlainPanel", "PanelContainer")
	t.set_stylebox("panel", "PlainPanel", panel_style(false))

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", font_title)
	t.set_font_size("font_size", "TitleLabel", 26)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_color("font_outline_color", "TitleLabel", Color(0.12, 0.08, 0.02))
	t.set_constant("outline_size", "TitleLabel", 6)
	t.set_type_variation("NumberLabel", "Label")
	t.set_font("font", "NumberLabel", font_title)
	t.set_font_size("font_size", "NumberLabel", 22)
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 14)
	t.set_color("font_color", "SmallLabel", CREAM_DIM)

	for kind in ["yellow", "red", "green", "slot"]:
		var tn: String = "Button" if kind == "yellow" else kind.capitalize() + "Button"
		if tn != "Button":
			t.set_type_variation(tn, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(state, tn, button_style(kind, state))
		t.set_stylebox("hover_pressed", tn, button_style(kind, "pressed"))
		t.set_stylebox("focus", tn, StyleBoxEmpty.new())
		t.set_font("font", tn, font_title)
		t.set_font_size("font_size", tn, 21)
		var fc := INK if kind == "yellow" else CREAM
		t.set_color("font_color", tn, fc)
		t.set_color("font_hover_color", tn, fc)
		t.set_color("font_pressed_color", tn, fc)
		t.set_color("font_focus_color", tn, fc)
		t.set_color("font_hover_pressed_color", tn, fc)
		t.set_color("font_disabled_color", tn, Color(0.85, 0.85, 0.85, 0.6))
		t.set_color("icon_normal_color", tn, Color.WHITE)
		t.set_color("icon_hover_color", tn, Color(1.1, 1.1, 1.1))
		t.set_color("icon_disabled_color", tn, Color(0.6, 0.6, 0.6, 0.7))
		t.set_constant("h_separation", tn, 8)

	t.set_stylebox("normal", "LineEdit", inset_style(9.0))
	t.set_stylebox("focus", "LineEdit", inset_style(9.0))
	t.set_stylebox("read_only", "LineEdit", inset_style(9.0))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(1.0, 0.8, 0.25, 0.35))
	t.set_font_size("font_size", "LineEdit", 18)

	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "OptionButton", button_style("slot", state))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", CREAM)
	t.set_color("font_hover_color", "OptionButton", CREAM)
	t.set_color("font_pressed_color", "OptionButton", CREAM)
	t.set_font("font", "OptionButton", font_title)
	t.set_font_size("font_size", "OptionButton", 19)
	t.set_constant("h_separation", "OptionButton", 10)
	(t.get_stylebox("normal", "OptionButton") as StyleBoxTexture).content_margin_left = 14
	t.set_stylebox("panel", "PopupMenu", panel_style(false))
	t.set_stylebox("hover", "PopupMenu", bar_fill(Color(0.35, 0.5, 0.9)))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_font_size("font_size", "PopupMenu", 18)

	t.set_stylebox("panel", "TooltipPanel", tooltip_style())
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 16)

	t.set_stylebox("background", "ProgressBar", bar_bg())
	t.set_stylebox("fill", "ProgressBar", bar_fill(Color(0.4, 0.85, 0.3)))
	t.set_color("font_color", "ProgressBar", CREAM)
	t.set_font_size("font_size", "ProgressBar", 13)

	var sep := StyleBoxLine.new()
	sep.color = Color(0.45, 0.58, 0.9, 0.35)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = Color(0.45, 0.58, 0.9, 0.35)
	vsep.thickness = 2
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)
	_theme = t
	return t


# --- Kleine bouwhulpjes --------------------------------------------------------

static func label(text: String, variation := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func bar(color: Color, height := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.max_value = 1.0
	b.step = 0.0
	b.add_theme_stylebox_override("fill", bar_fill(color))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Tooltip voor knoppen in de commandokaart.
## tip: {title, cost (Dictionary), desc, key, stock_fn (Callable)}
static func tooltip(tip: Dictionary) -> Control:
	fonts()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(260, 0)
	var head := HBoxContainer.new()
	var t := label(tip.get("title", ""), "", 21, INK)
	t.add_theme_font_override("font", font_title)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if tip.get("key", "") != "":
		var k := label("[%s]" % tip["key"], "", 16, Color(0.55, 0.35, 0.1))
		k.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		head.add_child(k)
	box.add_child(head)
	var cost: Dictionary = tip.get("cost", {})
	if cost.size() > 0:
		var stock: Dictionary = tip["stock_fn"].call() if tip.has("stock_fn") else {}
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for res in cost:
			var it := HBoxContainer.new()
			it.add_theme_constant_override("separation", 3)
			var ic := TextureRect.new()
			ic.texture = Icons.resource_icon(res)
			ic.custom_minimum_size = Vector2(24, 24)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			it.add_child(ic)
			var ok: bool = stock.get(res, 0) >= cost[res]
			var n := label(str(cost[res]), "", 18, INK if ok else Color(0.8, 0.12, 0.1))
			n.add_theme_font_override("font", font_title)
			n.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
			it.add_child(n)
			row.add_child(it)
		box.add_child(row)
	if tip.get("extra", "") != "":
		var ex := label(tip["extra"], "", 15, Color(0.45, 0.3, 0.12))
		ex.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		box.add_child(ex)
	if tip.get("desc", "") != "":
		var d := label(tip["desc"], "", 15, Color(0.3, 0.2, 0.1))
		d.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(260, 0)
		box.add_child(d)
	return box
