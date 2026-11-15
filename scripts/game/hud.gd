extends CanvasLayer
## De game-interface: grondstoffenbalk bovenin, minikaart linksonder,
## selectiepaneel met 3D-portret in het midden en de commandokaart rechtsonder.
## Daarnaast tekent hij levensbalken en de selectierechthoek over de wereld.

const UISkin := preload("res://scripts/ui/ui_skin.gd")
const Minimap := preload("res://scripts/ui/minimap.gd")

const DESCRIPTIONS := {
	"worker": "Verzamelt grondstoffen en bouwt gebouwen. Draai hem op en hij gaat aan de slag.",
	"rifleman": "Schiet van een afstandje met zijn plastic geweer.",
	"mini_raptor": "Verzamelt grondstoffen en bouwt. Klein maar ijverig.",
	"velociraptor": "Snel en bijt vaak. Goed om vijanden op te jagen.",
	"dilophosaurus": "Spuugt van een afstandje naar vijanden.",
	"triceratops": "Taai, en ramt gebouwen voor dubbele schade.",
	"pteranodon": "Vliegt over alles heen. Ideaal om te verkennen.",
	"trex": "De koning van de speelkamer. Heel sterk, maar duur.",
	"hq": "Je hoofdkwartier. Traint workers en neemt grondstoffen aan.",
	"storage": "Lever hier grondstoffen in, dichter bij de bron.",
	"house": "Geeft +10 populatie.",
	"barracks": "Traint geweerschutters.",
	"tower": "Schiet automatisch op vijandelijke units in de buurt.",
	"volcano": "Je hoofdkwartier. Broedt mini-raptors uit en neemt grondstoffen aan.",
	"nest": "Lever hier grondstoffen in. Geeft ook +5 populatie.",
	"hatchery": "Broedt velociraptors en dilophosaurussen uit.",
	"fossil_lab": "Wekt de grote dino's tot leven.",
	"lookout": "Bijt automatisch van zich af naar units in de buurt.",
}


## Knop in de commandokaart met een eigen tooltip.
class SlotButton extends Button:
	var tip := {}

	func _make_custom_tooltip(_for_text: String) -> Object:
		return UISkin.tooltip(tip)


## Tekent levensbalken en de sleeprechthoek over de 3D-wereld.
class WorldOverlay extends Control:
	var hud: CanvasLayer
	var rect := Rect2()
	var active := false
	var _bg := StyleBoxFlat.new()
	var _fill := StyleBoxFlat.new()

	func _init() -> void:
		_bg.bg_color = Color(0.05, 0.05, 0.1, 0.85)
		_bg.set_corner_radius_all(4)
		_bg.set_border_width_all(1)
		_bg.border_color = Color(0, 0, 0, 0.9)
		_fill.set_corner_radius_all(3)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _bar(center: Vector2, w: float, h: float, ratio: float, col: Color) -> void:
		var r := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		draw_style_box(_bg, r.grow(1.5))
		if ratio > 0.0:
			_fill.bg_color = col
			draw_style_box(_fill, Rect2(r.position, Vector2(maxf(r.size.x * ratio, 3.0), r.size.y)))
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(maxf(r.size.x * ratio - 2.0, 1.0), 1.5)), Color(1, 1, 1, 0.35))

	func _draw() -> void:
		var game: Node3D = hud.game
		var cam: Camera3D = game.camera
		if cam == null:
			return
		var sel: Array = hud.controller.selected
		for e in game.entities.values():
			if e.dead or e.kind == "resource":
				continue
			var is_sel: bool = e.id in sel
			var damaged: bool = e.hp < e.max_hp - 0.5
			var building_busy: bool = e.kind == "building" and (not e.complete or e.queue.size() > 0)
			if not (is_sel or damaged or building_busy):
				continue
			var top: Vector3 = e.position + Vector3(0, e.pick_height + (4.2 if e.flying else 0.35), 0)
			if cam.is_position_behind(top):
				continue
			var sp := cam.unproject_position(top)
			if not Rect2(Vector2(-60, -60), size + Vector2(120, 120)).has_point(sp):
				continue
			var w := 64.0 if e.kind == "building" else clampf(26.0 + e.radius * 14.0, 30.0, 52.0)
			var ratio: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
			var col := Color(0.4, 0.9, 0.3).lerp(Color(1.0, 0.85, 0.2), clampf((0.75 - ratio) * 2.5, 0.0, 1.0))
			if ratio < 0.3:
				col = Color(1.0, 0.3, 0.25)
			if e.owner_slot != game.my_slot:
				col = Color(1.0, 0.35, 0.3)
			var y := sp.y
			if is_sel or damaged or (e.kind == "building" and e.complete):
				_bar(Vector2(sp.x, y), w, 6.0, ratio, col)
				y -= 10.0
			if e.kind == "building" and not e.complete:
				_bar(Vector2(sp.x, y), w, 7.0, e.progress, Color(1.0, 0.78, 0.2))
			elif e.kind == "building" and e.queue.size() > 0 and e.owner_slot == game.my_slot:
				_bar(Vector2(sp.x, y), w, 7.0, e.train_ratio, Color(0.35, 0.65, 1.0))
				var ic: Texture2D = Icons.icon(e.queue[0], e.owner_slot)
				draw_texture_rect(ic, Rect2(Vector2(sp.x - w * 0.5 - 30.0, y - 13.0), Vector2(26, 26)), false)
				if e.queue.size() > 1:
					draw_string(UISkin.font_title, Vector2(sp.x + w * 0.5 + 5.0, y + 6.0), "+%d" % (e.queue.size() - 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UISkin.CREAM)
		if active:
			draw_rect(rect, Color(1.0, 0.85, 0.3, 0.1), true)
			draw_rect(rect, Color(1.0, 0.85, 0.3, 0.9), false, 2.0)
			var k := minf(14.0, minf(rect.size.x, rect.size.y) * 0.4)
			for c in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				var sx := 1.0 if c.x == rect.position.x else -1.0
				var sy := 1.0 if c.y == rect.position.y else -1.0
				draw_line(c, c + Vector2(k * sx, 0), Color(1, 0.95, 0.6), 4.0)
				draw_line(c, c + Vector2(0, k * sy), Color(1, 0.95, 0.6), 4.0)


var game: Node3D
var controller: Node

var _root: Control
var _overlay: WorldOverlay
var _res_labels := {}
var _pop_label: Label
var _idle_button: Button
var _idle_count: Label
var _flash_box: PanelContainer
var _flash: Label
var _flash_t := 0.0
var _hint: PanelContainer
var _hint_label: Label
var _sel_body: Control
var _card: GridContainer
var _card_items: Array = []
var _action_key := ""
var _sel_key := ""
var _portrait_vp: SubViewport
var _portrait_type := ""
# Verwijzingen naar labels/balken in het selectiepaneel die elke frame bijwerken.
var _live := {}


func _ready() -> void:
	UISkin.fonts()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UISkin.theme()
	add_child(_root)

	_overlay = WorldOverlay.new()
	_overlay.hud = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_overlay)

	_build_top()
	_build_bottom()

	# Melding (bijv. "Niet genoeg Blokjes")
	_flash_box = PanelContainer.new()
	_flash_box.theme_type_variation = "PillPanel"
	_flash_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash = UISkin.label("", "TitleLabel", 22)
	_flash_box.add_child(_flash)
	_flash_box.visible = false
	_root.add_child(_flash_box)

	# Hint tijdens het plaatsen van een gebouw
	_hint = PanelContainer.new()
	_hint.theme_type_variation = "PillPanel"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = UISkin.label("", "", 17)
	_hint.add_child(_hint_label)
	_hint.visible = false
	_root.add_child(_hint)

	controller.selection_changed.connect(_on_selection_changed)
	_on_selection_changed()


# --- Opbouw ------------------------------------------------------------------

func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.theme_type_variation = "PlainPanel"
	bar.position = Vector2(10, 8)
	_root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for res in GameData.RESOURCES:
		var pill := PanelContainer.new()
		pill.theme_type_variation = "PillPanel"
		pill.tooltip_text = GameData.RESOURCE_NAMES[res]
		row.add_child(pill)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		pill.add_child(h)
		h.add_child(_icon_rect(Icons.resource_icon(res), 34))
		var l := UISkin.label("0", "NumberLabel", 22)
		l.custom_minimum_size = Vector2(52, 0)
		h.add_child(l)
		_res_labels[res] = l
	var pop := PanelContainer.new()
	pop.theme_type_variation = "PillPanel"
	pop.tooltip_text = "Populatie"
	row.add_child(pop)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 4)
	pop.add_child(ph)
	ph.add_child(_icon_rect(Icons.icon("icon_pop_" + game.my_faction, game.my_slot, 96), 34))
	_pop_label = UISkin.label("0/0", "NumberLabel", 22)
	_pop_label.custom_minimum_size = Vector2(70, 0)
	ph.add_child(_pop_label)

	_idle_button = SlotButton.new()
	_idle_button.theme_type_variation = "SlotButton"
	_idle_button.focus_mode = Control.FOCUS_NONE
	_idle_button.custom_minimum_size = Vector2(52, 48)
	_idle_button.tooltip_text = " "
	_idle_button.tip = {"title": "Werkeloze worker", "key": ".", "desc": "Selecteert een worker die niks doet en zet de camera erop."}
	_idle_button.pressed.connect(func(): controller.select_idle_worker())
	row.add_child(_idle_button)
	var wi := _icon_rect(Icons.icon(GameData.faction_data(game.my_faction)["worker"], game.my_slot, 96), 0)
	wi.set_anchors_preset(Control.PRESET_FULL_RECT)
	wi.offset_left = 5
	wi.offset_top = 3
	wi.offset_right = -5
	wi.offset_bottom = -7
	_idle_button.add_child(wi)
	_idle_count = UISkin.label("0", "NumberLabel", 17)
	_idle_count.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_idle_count.add_theme_constant_override("outline_size", 5)
	_idle_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_idle_count.offset_right = -4
	_idle_count.offset_bottom = -2
	_idle_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_idle_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_idle_button.add_child(_idle_count)

	# Rechtsboven: speler en menu
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var chip := PanelContainer.new()
	chip.theme_type_variation = "PlainPanel"
	right.add_child(chip)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	chip.add_child(ch)
	ch.add_child(_icon_rect(Icons.icon(GameData.faction_data(game.my_faction)["hq"], game.my_slot, 96), 34))
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	ch.add_child(nv)
	nv.add_child(UISkin.label(Net.local_name, "NumberLabel", 19, GameData.player_color(game.my_slot).lightened(0.45)))
	nv.add_child(UISkin.label("%s · %s" % [GameData.faction_data(game.my_faction)["name"], GameData.PLAYER_COLOR_NAMES[game.my_slot]], "SmallLabel", 13))
	var leave := Button.new()
	leave.theme_type_variation = "RedButton"
	leave.text = "Verlaten"
	leave.focus_mode = Control.FOCUS_NONE
	leave.custom_minimum_size = Vector2(0, 50)
	leave.pressed.connect(func(): get_tree().current_scene.leave_game())
	right.add_child(leave)
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)


func _build_bottom() -> void:
	# Minikaart
	var mm_panel := PanelContainer.new()
	_anchor_bottom(mm_panel, 0.0, 0.0, 10, -236, 236, -8)
	_root.add_child(mm_panel)
	var mm_inset := PanelContainer.new()
	mm_inset.theme_type_variation = "InsetPanel"
	mm_panel.add_child(mm_inset)
	var mm := Minimap.new()
	mm.game = game
	mm.controller = controller
	mm.custom_minimum_size = Vector2(180, 180)
	mm_inset.add_child(mm)

	# Selectiepaneel
	var sel := PanelContainer.new()
	_anchor_bottom(sel, 0.0, 1.0, 244, -200, -324, -8)
	_root.add_child(sel)
	_sel_body = MarginContainer.new()
	sel.add_child(_sel_body)

	# Commandokaart
	var card_panel := PanelContainer.new()
	_anchor_bottom(card_panel, 1.0, 1.0, -316, -236, -10, -8)
	_root.add_child(card_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card_panel.add_child(cv)
	_card = GridContainer.new()
	_card.columns = 4
	_card.add_theme_constant_override("h_separation", 6)
	_card.add_theme_constant_override("v_separation", 6)
	cv.add_child(_card)


func _anchor_bottom(c: Control, al: float, ar: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_right = ar
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _icon_rect(tex: Texture2D, s: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if s > 0:
		r.custom_minimum_size = Vector2(s, s)
	return r


# --- Publieke functies --------------------------------------------------------

func set_drag_rect(active: bool, rect: Rect2) -> void:
	_overlay.active = active
	_overlay.rect = rect


func flash(text: String) -> void:
	_flash.text = text
	_flash_t = 2.2
	_flash_box.visible = true
	_flash_box.reset_size()
	_flash_box.position = Vector2((_root.size.x - _flash_box.size.x) * 0.5, 84)


# --- Elke frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	var stock: Dictionary = game.stocks.get(game.my_slot, {})
	for res in GameData.RESOURCES:
		_res_labels[res].text = str(stock.get(res, 0))
	_pop_label.text = "%d/%d" % [stock.get("pop", 0), stock.get("cap", 0)]
	_pop_label.add_theme_color_override("font_color", UISkin.BAD if stock.get("pop", 0) >= stock.get("cap", 0) and stock.get("cap", 0) > 0 else UISkin.CREAM)
	var idle := 0
	for e in game.entities.values():
		if e.kind == "unit" and e.owner_slot == game.my_slot and e.state == "idle" and GameData.UNITS[e.type].get("can_gather", false):
			idle += 1
	_idle_count.text = str(idle)
	_idle_button.modulate = Color(1, 1, 1) if idle > 0 else Color(0.7, 0.7, 0.75)

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash_box.modulate.a = clampf(_flash_t * 2.0, 0.0, 1.0)
		_flash_box.visible = _flash_t > 0.0

	_hint.visible = controller.place_type != ""
	if _hint.visible:
		_hint_label.text = "%s plaatsen  ·  Klik = bouwen  ·  Shift = meer  ·  Rechts = annuleren" % GameData.BUILDINGS[controller.place_type]["name"]
		_hint.reset_size()
		_hint.position = Vector2((_root.size.x - _hint.size.x) * 0.5, _root.size.y - 252 - _hint.size.y)

	if _actions_key() != _action_key:
		_rebuild_actions()
	_update_card_state(stock)
	if _selection_key() != _sel_key:
		_rebuild_selection()
	_update_selection()


# --- Commandokaart --------------------------------------------------------------

func _actions_key() -> String:
	var k := ""
	for e in controller.selected_entities():
		k += "%d:%s," % [e.id, e.complete]
	return k


func _on_selection_changed() -> void:
	_rebuild_actions()
	_rebuild_selection()


func _rebuild_actions() -> void:
	_action_key = _actions_key()
	for c in _card.get_children():
		c.queue_free()
	_card_items.clear()
	var items := []
	var stock_fn := func(): return game.stocks.get(game.my_slot, {})
	if controller.own_workers().size() > 0:
		for item in GameData.faction_data(game.my_faction)["build_menu"]:
			var bd: Dictionary = GameData.BUILDINGS[item[0]]
			var btype: String = item[0]
			var extra := ""
			if bd.get("pop", 0) > 0:
				extra = "+%d populatie" % bd["pop"]
			items.append({"icon": Icons.icon(btype, game.my_slot), "key": item[1], "cost": bd["cost"],
				"tip": {"title": bd["name"], "cost": bd["cost"], "desc": DESCRIPTIONS.get(btype, ""), "key": item[1], "stock_fn": stock_fn, "extra": extra},
				"cb": func(): controller.start_place(btype)})
	var trainable := {}
	for b in controller.own_buildings():
		if b.complete:
			for u in GameData.BUILDINGS[b.type].get("trains", []):
				trainable[u] = true
	var first := true
	for u in trainable:
		var ud: Dictionary = GameData.UNITS[u]
		var utype: String = u
		var key := "Q" if first else ""
		var extra := "Populatie %d · %d s" % [ud["pop"], int(ud["train_time"])]
		items.append({"icon": Icons.icon(utype, game.my_slot), "key": key, "cost": ud["cost"],
			"tip": {"title": ud["name"], "cost": ud["cost"], "desc": DESCRIPTIONS.get(utype, ""), "key": key, "stock_fn": stock_fn, "extra": extra},
			"cb": func(): controller.train(utype)})
		first = false
	if controller.own_units().size() > 0:
		items.append({"icon": Icons.icon("icon_stop", -1, 96), "key": "X", "cost": {},
			"tip": {"title": "Stop", "desc": "De geselecteerde units stoppen met wat ze doen.", "key": "X"},
			"cb": func(): game.cmd_stop.rpc_id(1, controller.own_units().map(func(u): return u.id))})
	for i in 12:
		if i < items.size():
			_card.add_child(_slot(items[i]))
		else:
			var empty := PanelContainer.new()
			empty.theme_type_variation = "InsetPanel"
			empty.custom_minimum_size = Vector2(64, 60)
			empty.modulate = Color(1, 1, 1, 0.55)
			_card.add_child(empty)


func _slot(it: Dictionary) -> Control:
	var b := SlotButton.new()
	b.theme_type_variation = "SlotButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(64, 60)
	b.tooltip_text = " "
	b.tip = it["tip"]
	b.pressed.connect(it["cb"])
	var ic := _icon_rect(it["icon"], 0)
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6
	ic.offset_top = 4
	ic.offset_right = -6
	ic.offset_bottom = -9
	b.add_child(ic)
	if it["key"] != "":
		var badge := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.08, 0.04, 0.85)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.border_color = UISkin.GOLD
		sb.set_border_width_all(1)
		badge.add_theme_stylebox_override("panel", sb)
		badge.position = Vector2(4, 3)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kl := UISkin.label(it["key"], "NumberLabel", 14, UISkin.GOLD)
		kl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		badge.add_child(kl)
		b.add_child(badge)
	_card_items.append({"button": b, "icon": ic, "cost": it["cost"]})
	return b


func _update_card_state(stock: Dictionary) -> void:
	for it in _card_items:
		if not is_instance_valid(it["button"]):
			continue
		var ok := GameData.can_afford(stock, it["cost"])
		it["icon"].modulate = Color(1, 1, 1) if ok else Color(0.55, 0.4, 0.4)


# --- Selectiepaneel ---------------------------------------------------------------

func _selection_key() -> String:
	var list: Array = controller.selected_entities()
	if list.size() == 1:
		return "1:%d:%s" % [list[0].id, list[0].complete]
	var k := "n:"
	for e in list:
		k += "%d," % e.id
	return k + str(game.entities.is_empty())


func _rebuild_selection() -> void:
	_sel_key = _selection_key()
	for c in _sel_body.get_children():
		c.queue_free()
	_live.clear()
	var list: Array = controller.selected_entities()
	if game.entities.is_empty():
		_sel_body.add_child(UISkin.label("Wachten op de host...", "TitleLabel"))
		_free_portrait()
	elif list.is_empty():
		_free_portrait()
		_build_help()
	elif list.size() == 1:
		_build_single(list[0])
	else:
		_free_portrait()
		_build_multi(list)


func _build_help() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_sel_body.add_child(v)
	v.add_child(UISkin.label("Speelkamer-commandant", "TitleLabel", 24))
	var lines := [
		["Links", "selecteren, of slepen voor een groep"],
		["Rechts", "lopen, verzamelen, bouwen of aanvallen"],
		["WASD / rand", "camera schuiven  ·  scrollen = zoomen"],
		["Spatie", "naar je hoofdkwartier  ·  .  = werkeloze worker"],
		["X / Esc", "stoppen  ·  annuleren"],
	]
	for l in lines:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var k := UISkin.label(l[0], "NumberLabel", 16, UISkin.GOLD)
		k.custom_minimum_size = Vector2(110, 0)
		h.add_child(k)
		h.add_child(UISkin.label(l[1], "", 16, UISkin.CREAM_DIM))
		v.add_child(h)


func _free_portrait() -> void:
	if _portrait_vp and is_instance_valid(_portrait_vp):
		_portrait_vp.queue_free()
	_portrait_vp = null
	_portrait_type = ""


func _build_single(e) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_sel_body.add_child(h)
	# Portret
	var frame := PanelContainer.new()
	frame.theme_type_variation = "InsetPanel"
	frame.custom_minimum_size = Vector2(160, 160)
	h.add_child(frame)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(svc)
	_free_portrait()
	_portrait_vp = Icons.portrait(e.type, e.owner_slot, 160)
	svc.add_child(_portrait_vp)
	_portrait_type = e.type

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var title := HBoxContainer.new()
	v.add_child(title)
	title.add_child(UISkin.label(GameData.display_name(e.kind, e.type), "TitleLabel", 28))
	var owner_text := "Neutraal"
	var owner_col := UISkin.CREAM_DIM
	if e.owner_slot >= 0:
		owner_text = "%s  ·  %s" % [GameData.PLAYER_COLOR_NAMES[e.owner_slot], GameData.faction_data(game.factions.get(e.owner_slot, "soldiers"))["name"]]
		owner_col = GameData.player_color(e.owner_slot).lightened(0.4)
	var ol := UISkin.label("   " + owner_text, "", 16, owner_col)
	ol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(ol)

	if e.kind == "resource":
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 8)
		v.add_child(rr)
		rr.add_child(_icon_rect(Icons.resource_icon(e.type), 34))
		var b := UISkin.bar(GameData.RESOURCE_COLORS[e.type], 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rr.add_child(b)
		_live["amount_bar"] = b
		var al := UISkin.label("", "NumberLabel", 18)
		rr.add_child(al)
		_live["amount_label"] = al
		v.add_child(UISkin.label("Rechtsklik met workers om te verzamelen.", "SmallLabel", 15))
		return

	# Levensbalk
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	v.add_child(hr)
	var hp_bar := UISkin.bar(Color(0.4, 0.88, 0.3), 20)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hp_bar)
	var hp_label := UISkin.label("", "NumberLabel", 18)
	hp_label.custom_minimum_size = Vector2(96, 0)
	hr.add_child(hp_label)
	_live["hp_bar"] = hp_bar
	_live["hp_label"] = hp_label

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	v.add_child(stats)
	if e.kind == "unit":
		var ud: Dictionary = GameData.UNITS[e.type]
		if ud["damage"] > 0:
			_stat(stats, "Schade", str(ud["damage"]))
			_stat(stats, "Bereik", "%.0f" % ud["range"] if ud["range"] > 1.5 else "dichtbij")
		_stat(stats, "Snelheid", "%.1f" % ud["speed"])
		if ud.get("can_gather", false):
			_stat(stats, "Draagt", str(ud["carry"]))
		var st := UISkin.label("", "", 18, UISkin.GOLD)
		v.add_child(st)
		_live["state"] = st
	else:
		var bd: Dictionary = GameData.BUILDINGS[e.type]
		if bd.has("damage"):
			_stat(stats, "Schade", str(bd["damage"]))
			_stat(stats, "Bereik", "%.0f" % bd["range"])
		if bd.get("pop", 0) > 0:
			_stat(stats, "Populatie", "+%d" % bd["pop"])
		if bd.get("dropoff", false):
			_stat(stats, "Inleveren", "ja")
		if not e.complete:
			var pr := HBoxContainer.new()
			pr.add_theme_constant_override("separation", 8)
			v.add_child(pr)
			pr.add_child(UISkin.label("In aanbouw", "NumberLabel", 17, UISkin.GOLD))
			var pb := UISkin.bar(Color(1.0, 0.78, 0.2), 16)
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pr.add_child(pb)
			_live["progress"] = pb
		elif e.owner_slot == game.my_slot and bd.get("trains", []).size() > 0:
			var q := HBoxContainer.new()
			q.add_theme_constant_override("separation", 6)
			v.add_child(q)
			_live["queue"] = []
			for i in 5:
				var slot := PanelContainer.new()
				slot.theme_type_variation = "InsetPanel"
				slot.custom_minimum_size = Vector2(52, 52)
				q.add_child(slot)
				var ic := _icon_rect(null, 0)
				slot.add_child(ic)
				_live["queue"].append(ic)
			var tb := UISkin.bar(Color(0.35, 0.65, 1.0), 12)
			tb.custom_minimum_size = Vector2(120, 12)
			tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			q.add_child(tb)
			_live["train_bar"] = tb


func _stat(parent: Control, name: String, value: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.add_child(UISkin.label(name, "SmallLabel", 15))
	h.add_child(UISkin.label(value, "NumberLabel", 17))
	parent.add_child(h)


func _build_multi(list: Array) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sel_body.add_child(v)
	v.add_child(UISkin.label("%d geselecteerd" % list.size(), "TitleLabel", 22))
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	_live["multi"] = []
	for i in mini(list.size(), 24):
		var e = list[i]
		var b := SlotButton.new()
		b.theme_type_variation = "SlotButton"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(54, 58)
		b.tooltip_text = " "
		b.tip = {"title": GameData.display_name(e.kind, e.type), "desc": "Klik om alleen deze te selecteren."}
		var ent = e
		b.pressed.connect(func(): controller.set_selection([ent]))
		var ic := _icon_rect(Icons.icon(e.type, e.owner_slot), 0)
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 3
		ic.offset_top = 2
		ic.offset_right = -3
		ic.offset_bottom = -14
		b.add_child(ic)
		var hb := UISkin.bar(Color(0.4, 0.88, 0.3), 6)
		hb.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hb.offset_left = 6
		hb.offset_right = -6
		hb.offset_top = -15
		hb.offset_bottom = -9
		b.add_child(hb)
		grid.add_child(b)
		_live["multi"].append([e, hb])
	if list.size() > 24:
		v.add_child(UISkin.label("+%d meer" % (list.size() - 24), "SmallLabel"))


func _update_selection() -> void:
	var list: Array = controller.selected_entities()
	if list.size() == 1:
		var e = list[0]
		if _live.has("hp_bar"):
			_live["hp_bar"].value = e.hp / e.max_hp
			_live["hp_label"].text = "%d / %d" % [ceili(e.hp), int(e.max_hp)]
		if _live.has("amount_bar"):
			_live["amount_bar"].value = float(e.amount) / maxf(e.start_amount, 1.0)
			_live["amount_label"].text = str(e.amount)
		if _live.has("state"):
			var t := _state_text(e.state)
			if e.carry_amount > 0:
				t += "  ·  draagt %d %s" % [e.carry_amount, GameData.RESOURCE_NAMES[e.carry_type]]
			_live["state"].text = t
		if _live.has("progress"):
			_live["progress"].value = e.progress
		if _live.has("queue"):
			for i in 5:
				_live["queue"][i].texture = Icons.icon(e.queue[i], e.owner_slot) if i < e.queue.size() else null
			_live["train_bar"].value = e.train_ratio if e.queue.size() > 0 else 0.0
	elif _live.has("multi"):
		for pair in _live["multi"]:
			if is_instance_valid(pair[0]) and not pair[0].dead:
				pair[1].value = pair[0].hp / pair[0].max_hp


func _state_text(s: String) -> String:
	match s:
		"move": return "Onderweg"
		"gather": return "Aan het verzamelen"
		"return": return "Brengt spullen terug"
		"build": return "Aan het bouwen"
		"attack": return "Valt aan!"
	return "Wacht op orders"
