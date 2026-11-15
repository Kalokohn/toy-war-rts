extends CanvasLayer
## Schermoverlay: resources bovenin, selectie-info en knoppen onderin.

class DragBox extends Control:
	var rect := Rect2()
	var active := false

	func _draw() -> void:
		if active:
			draw_rect(rect, Color(0.3, 1, 0.3, 0.12), true)
			draw_rect(rect, Color(0.3, 1, 0.3, 0.9), false, 1.5)


var game: Node3D
var controller: Node

var _root: Control
var _res_labels := {}
var _pop_label: Label
var _idle_button: Button
var _info: Label
var _actions: HFlowContainer
var _flash: Label
var _flash_t := 0.0
var _drag: DragBox
var _action_key := ""


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_drag = DragBox.new()
	_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_drag)

	# Bovenbalk
	var top := PanelContainer.new()
	top.position = Vector2(8, 8)
	_root.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	top.add_child(row)
	var me := Label.new()
	me.text = "%s (%s)" % [Net.local_name, GameData.PLAYER_COLOR_NAMES[game.my_slot]]
	me.add_theme_color_override("font_color", GameData.player_color(game.my_slot).lightened(0.3))
	row.add_child(me)
	for res in GameData.RESOURCES:
		var l := Label.new()
		l.add_theme_color_override("font_color", GameData.RESOURCE_COLORS[res])
		row.add_child(l)
		_res_labels[res] = l
	_pop_label = Label.new()
	row.add_child(_pop_label)
	_idle_button = Button.new()
	_idle_button.focus_mode = Control.FOCUS_NONE
	_idle_button.tooltip_text = "Selecteer een werkeloos opwindsoldaatje (.)"
	_idle_button.pressed.connect(func(): controller.select_idle_worker())
	row.add_child(_idle_button)

	var leave := Button.new()
	leave.text = "Verlaten"
	leave.focus_mode = Control.FOCUS_NONE
	leave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave.position = Vector2(-100, 8)
	leave.pressed.connect(func(): get_tree().current_scene.leave_game())
	_root.add_child(leave)

	# Onderpaneel
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -150
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_bottom = -8
	_root.add_child(bottom)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	bottom.add_child(hb)
	_info = Label.new()
	_info.custom_minimum_size = Vector2(380, 0)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(_info)
	_actions = HFlowContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_actions)
	var help := Label.new()
	help.text = "Links: selecteren / slepen\nRechts: lopen, verzamelen, bouwen, aanvallen\nWASD/rand: camera, scroll: zoom\nSpatie: naar HQ   X: stop   Esc: annuleren"
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.7)
	hb.add_child(help)

	_flash = Label.new()
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.position = Vector2(-200, 60)
	_flash.custom_minimum_size = Vector2(400, 0)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", 20)
	_flash.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_flash.add_theme_constant_override("outline_size", 6)
	_root.add_child(_flash)

	controller.selection_changed.connect(_rebuild_actions)
	_rebuild_actions()


func set_drag_rect(active: bool, rect: Rect2) -> void:
	_drag.active = active
	_drag.rect = rect
	_drag.queue_redraw()


func flash(text: String) -> void:
	_flash.text = text
	_flash_t = 2.0


func _process(delta: float) -> void:
	var stock: Dictionary = game.stocks.get(game.my_slot, {})
	for res in GameData.RESOURCES:
		_res_labels[res].text = "%s: %d" % [GameData.RESOURCE_NAMES[res], stock.get(res, 0)]
	_pop_label.text = "Pop: %d/%d" % [stock.get("pop", 0), stock.get("cap", 0)]
	var idle := 0
	for e in game.entities.values():
		if e.kind == "unit" and e.owner_slot == game.my_slot and e.state == "idle" and e.type == "worker":
			idle += 1
	_idle_button.text = "Werkeloos: %d" % idle

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.modulate.a = clampf(_flash_t, 0.0, 1.0)

	_info.text = _info_text()
	# Knoppen opnieuw opbouwen als een gebouw klaar is of de selectie wijzigt.
	if _actions_key() != _action_key:
		_rebuild_actions()


func _info_text() -> String:
	if game.entities.is_empty():
		return "Wachten op de host..."
	var list: Array = controller.selected_entities()
	if list.is_empty():
		return "Niks geselecteerd."
	if list.size() == 1:
		var e = list[0]
		var who: String = "neutraal" if e.owner_slot < 0 else GameData.PLAYER_COLOR_NAMES[e.owner_slot]
		var t := "%s (%s)\n" % [GameData.display_name(e.kind, e.type), who]
		match e.kind:
			"unit":
				t += "HP %d/%d\n%s" % [e.hp, e.max_hp, _state_text(e.state)]
				if e.carry_amount > 0:
					t += "\nDraagt %d %s" % [e.carry_amount, GameData.RESOURCE_NAMES[e.carry_type]]
			"building":
				t += "HP %d/%d" % [e.hp, e.max_hp]
				if not e.complete:
					t += "\nIn aanbouw: %d%%" % int(e.progress * 100.0)
				elif e.queue.size() > 0:
					var names := []
					for q in e.queue:
						names.append(GameData.UNITS[q]["name"])
					t += "\nWachtrij: " + ", ".join(names)
			"resource":
				t += "%d %s over" % [e.amount, GameData.RESOURCE_NAMES[e.type]]
		return t
	var counts := {}
	for e in list:
		var n := GameData.display_name(e.kind, e.type)
		counts[n] = counts.get(n, 0) + 1
	var parts := []
	for n in counts:
		parts.append("%dx %s" % [counts[n], n])
	return "%d geselecteerd\n%s" % [list.size(), "\n".join(parts)]


func _state_text(s: String) -> String:
	match s:
		"move": return "Loopt"
		"gather": return "Verzamelt"
		"return": return "Brengt terug"
		"build": return "Bouwt"
		"attack": return "Valt aan"
	return "Doet niks"


func _actions_key() -> String:
	var k := ""
	for e in controller.selected_entities():
		k += "%d:%s," % [e.id, e.complete]
	return k


func _rebuild_actions() -> void:
	_action_key = _actions_key()
	for c in _actions.get_children():
		c.queue_free()
	if controller.own_workers().size() > 0:
		for item in GameData.BUILD_MENU:
			var bd: Dictionary = GameData.BUILDINGS[item[0]]
			var btype: String = item[0]
			_add_button("%s (%s)\n%s" % [bd["name"], item[1], GameData.cost_text(bd["cost"])],
				func(): controller.start_place(btype))
	var trainable := {}
	for b in controller.own_buildings():
		if b.complete:
			for u in GameData.BUILDINGS[b.type].get("trains", []):
				trainable[u] = true
	var first := true
	for u in trainable:
		var ud: Dictionary = GameData.UNITS[u]
		var utype: String = u
		_add_button("%s%s\n%s" % [ud["name"], " (Q)" if first else "", GameData.cost_text(ud["cost"])],
			func(): controller.train(utype))
		first = false


func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 56)
	b.pressed.connect(cb)
	_actions.add_child(b)
