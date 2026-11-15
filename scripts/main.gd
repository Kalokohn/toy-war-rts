extends Node
## Hoofdmenu en lobby. Start de wereld zodra de host op "Start" drukt.
##
## Handig voor testen, argumenten na "--":
##   --single               meteen singleplayer
##   --host                 meteen hosten
##   --join=127.0.0.1       meteen verbinden
##   --name=Piet            spelernaam
##   --faction=dinos        faction (soldiers of dinos)
##   --autostart=2          host start zodra er 2 spelers zijn
##   --smoke-test           geautomatiseerde test, sluit zichzelf af
##   --combat-test          gevechtstest (singleplayer), sluit zichzelf af

const GameScript := preload("res://scripts/game/game.gd")
const SmokeTest := preload("res://scripts/debug/smoke_test.gd")
const CombatTest := preload("res://scripts/debug/combat_test.gd")
const UISkin := preload("res://scripts/ui/ui_skin.gd")
const MenuScene := preload("res://scripts/ui/menu_scene.gd")

var args := {}
var game: Node3D = null
var _menu_scene: Node3D = null

var _ui: CanvasLayer
var _menu: Control
var _lobby: Control
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
var _faction_pick: OptionButton
var _lobby_faction: OptionButton
var _status: Label
var _players_box: VBoxContainer
var _start_button: Button
var _lobby_info: Label


func _ready() -> void:
	_parse_args()
	_build_ui()
	Net.players_changed.connect(_refresh_lobby)
	Net.game_started.connect(_on_game_started)
	Net.connection_failed.connect(func(reason): _show_menu(reason))
	Net.server_lost.connect(func(): _end_game("De verbinding met de host is verbroken."))
	if args.has("name"):
		_name_edit.text = args["name"]
	if args.has("faction"):
		_faction_pick.select(maxi(GameData.FACTION_ORDER.find(args["faction"]), 0))
	if args.has("menu-shot"):
		_menu_shot()
	if args.has("showcase"):
		_ui.visible = false
		_set_menu_scene(false)
		var sc = load("res://scripts/debug/showcase.gd").new()
		sc.what = args["showcase"]
		add_child(sc)
		return
	if args.has("single"):
		_on_single()
	elif args.has("host"):
		_on_host()
	elif args.has("join"):
		_ip_edit.text = args["join"] if args["join"] != "" else "127.0.0.1"
		_on_join()


## Screenshot van het menu (of de lobby) voor de documentatie.
func _menu_shot() -> void:
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png(args.get("screenshot", "user://menu.png"))
	print("MENU screenshot opgeslagen")
	get_tree().quit()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""


# --- Knoppen ---------------------------------------------------------------

func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Speler"


func _faction() -> String:
	return GameData.FACTION_ORDER[_faction_pick.selected]


func _port() -> int:
	var p := int(_port_edit.text)
	return p if p > 0 else Net.DEFAULT_PORT


func _on_single() -> void:
	Net.start_singleplayer(_player_name(), _faction())


func _on_host() -> void:
	var err := Net.host(_port(), _player_name(), _faction())
	if err != OK:
		_show_menu("Hosten mislukt (poort %d bezet?)" % _port())
		return
	var ips := []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254"):
			ips.append(ip)
	_lobby_info.text = "Je host op poort %d (UDP).\nJe IP: %s" % [_port(), ", ".join(ips) if ips.size() > 0 else "onbekend"]
	_show_lobby()


func _on_join() -> void:
	var err := Net.join(_ip_edit.text.strip_edges(), _port(), _player_name(), _faction())
	if err != OK:
		_show_menu("Verbinden mislukt.")
		return
	_lobby_info.text = "Verbonden met %s:%d" % [_ip_edit.text, _port()]
	_status.text = "Verbinden..."
	_show_lobby()


func _on_leave_lobby() -> void:
	Net.leave()
	_show_menu("")


func _refresh_lobby() -> void:
	for c in _players_box.get_children():
		c.queue_free()
	var by_slot := {}
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		by_slot[int(p["slot"])] = p
	for s in GameData.MAX_PLAYERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 40)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var col := GameData.player_color(s).lightened(0.35)
		if by_slot.has(s):
			var p: Dictionary = by_slot[s]
			var fd := GameData.faction_data(p.get("faction", ""))
			icon.texture = Icons.icon(fd["worker"], s, 96)
			row.add_child(UISkin.label(str(p["name"]), "NumberLabel", 20, col))
			row.add_child(UISkin.label("%s  ·  %s" % [GameData.PLAYER_COLOR_NAMES[s], fd["name"]], "SmallLabel", 15))
		else:
			row.add_child(UISkin.label("%s  ·  vrij" % GameData.PLAYER_COLOR_NAMES[s], "SmallLabel", 17))
			row.modulate = Color(1, 1, 1, 0.5)
		for c in row.get_children():
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_players_box.add_child(row)
	_start_button.visible = multiplayer.is_server()
	_lobby_faction.select(GameData.FACTION_ORDER.find(Net.local_faction))
	if args.has("autostart") and multiplayer.is_server() and not Net.in_game:
		if Net.players.size() >= int(args["autostart"]):
			Net.start_game()


func _on_game_started() -> void:
	_ui.visible = false
	_set_menu_scene(false)
	game = GameScript.new()
	game.name = "Game"
	add_child(game)
	if args.has("smoke-test"):
		var t := SmokeTest.new()
		t.game = game
		game.add_child(t)
	if args.has("combat-test"):
		var c := CombatTest.new()
		c.game = game
		game.add_child(c)


func leave_game() -> void:
	Net.leave()
	_end_game("")


func _end_game(message: String) -> void:
	if game:
		remove_child(game)
		game.queue_free()
		game = null
	_ui.visible = true
	_set_menu_scene(true)
	_show_menu(message)
	if args.has("smoke-test"):
		print("SMOKE: spel beeindigd: ", message)
		get_tree().quit(0)


func _show_menu(message: String) -> void:
	_menu.visible = true
	_lobby.visible = false
	_status.text = message


func _show_lobby() -> void:
	_menu.visible = false
	_lobby.visible = true
	_refresh_lobby()


# --- UI --------------------------------------------------------------------

func _set_menu_scene(on: bool) -> void:
	if on and _menu_scene == null:
		_menu_scene = MenuScene.new()
		add_child(_menu_scene)
		move_child(_menu_scene, 0)
	elif not on and _menu_scene != null:
		_menu_scene.queue_free()
		remove_child(_menu_scene)
		_menu_scene = null


func _build_ui() -> void:
	_set_menu_scene(true)
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UISkin.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	# Zachte vignet links zodat het menu leesbaar blijft.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.07, 0.16, 0.75))
	grad.set_color(1, Color(0.05, 0.07, 0.16, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.anchor_bottom = 1.0
	shade.anchor_right = 0.6
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = 70
	col.offset_top = -380
	col.offset_bottom = 380
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(col)

	var title := Label.new()
	title.text = "TOY WAR"
	title.add_theme_font_override("font", UISkin.font_title)
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_color_override("font_color", UISkin.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.02))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_outline_size", 22)
	col.add_child(title)
	var sub := UISkin.label("Strijd om de speelkamer", "TitleLabel", 28)
	sub.add_theme_color_override("font_color", UISkin.CREAM)
	col.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# Hoofdmenu
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 9)
	outer.add_child(_menu)
	_name_edit = _field(_menu, "Naam", "Speler")
	_faction_pick = _faction_field(_menu)
	_button(_menu, "Singleplayer", _on_single).custom_minimum_size = Vector2(0, 58)
	var sep := HSeparator.new()
	_menu.add_child(sep)
	_ip_edit = _field(_menu, "IP van host", "127.0.0.1")
	_port_edit = _field(_menu, "Poort", str(Net.DEFAULT_PORT))
	var mp := HBoxContainer.new()
	mp.add_theme_constant_override("separation", 8)
	_menu.add_child(mp)
	var hb := _button(mp, "Hosten", _on_host, "SlotButton")
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var jb := _button(mp, "Meedoen", _on_join, "SlotButton")
	jb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(_menu, "Afsluiten", func(): get_tree().quit(), "RedButton")

	# Lobby
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 9)
	_lobby.visible = false
	outer.add_child(_lobby)
	_lobby.add_child(UISkin.label("Lobby", "TitleLabel", 30))
	_lobby_info = UISkin.label("", "SmallLabel", 16)
	_lobby.add_child(_lobby_info)
	var slots := PanelContainer.new()
	slots.theme_type_variation = "InsetPanel"
	_lobby.add_child(slots)
	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", 4)
	slots.add_child(_players_box)
	_lobby_faction = _faction_field(_lobby)
	_lobby_faction.item_selected.connect(func(i): Net.set_faction(GameData.FACTION_ORDER[i]))
	_start_button = _button(_lobby, "Start spel", func(): Net.start_game(), "GreenButton")
	_start_button.custom_minimum_size = Vector2(0, 58)
	_button(_lobby, "Lobby verlaten", _on_leave_lobby, "RedButton")

	_status = UISkin.label("", "TitleLabel", 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_status)

	var credits := UISkin.label("Lettertypen: Lilita One en Fredoka (SIL Open Font License)", "SmallLabel", 13)
	credits.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credits.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credits.offset_right = -14
	credits.offset_bottom = -10
	root.add_child(credits)


func _field(parent: Control, label: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UISkin.label(label, "NumberLabel", 18)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(0, 42)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(e)
	parent.add_child(row)
	return e


func _faction_field(parent: Control) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UISkin.label("Faction", "NumberLabel", 18)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var o := OptionButton.new()
	for f in GameData.FACTION_ORDER:
		o.add_icon_item(Icons.icon(GameData.FACTIONS[f]["worker"], 0, 96), GameData.FACTIONS[f]["name"])
	o.expand_icon = false
	o.add_theme_constant_override("icon_max_width", 34)
	o.custom_minimum_size = Vector2(0, 50)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.focus_mode = Control.FOCUS_NONE
	row.add_child(o)
	parent.add_child(row)
	return o


func _button(parent: Control, text: String, cb: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
