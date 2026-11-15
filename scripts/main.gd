extends Node
## Hoofdmenu en lobby. Start de wereld zodra de host op "Start" drukt.
##
## Handig voor testen, argumenten na "--":
##   --single               meteen singleplayer
##   --host                 meteen hosten
##   --join=127.0.0.1       meteen verbinden
##   --name=Piet            spelernaam
##   --autostart=2          host start zodra er 2 spelers zijn
##   --smoke-test           geautomatiseerde test, sluit zichzelf af

const GameScript := preload("res://scripts/game/game.gd")
const SmokeTest := preload("res://scripts/debug/smoke_test.gd")

var args := {}
var game: Node3D = null

var _ui: CanvasLayer
var _menu: Control
var _lobby: Control
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _port_edit: LineEdit
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
	if args.has("single"):
		_on_single()
	elif args.has("host"):
		_on_host()
	elif args.has("join"):
		_ip_edit.text = args["join"] if args["join"] != "" else "127.0.0.1"
		_on_join()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else ""


# --- Knoppen ---------------------------------------------------------------

func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Speler"


func _port() -> int:
	var p := int(_port_edit.text)
	return p if p > 0 else Net.DEFAULT_PORT


func _on_single() -> void:
	Net.start_singleplayer(_player_name())


func _on_host() -> void:
	var err := Net.host(_port(), _player_name())
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
	var err := Net.join(_ip_edit.text.strip_edges(), _port(), _player_name())
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
		by_slot[int(Net.players[id]["slot"])] = Net.players[id]["name"]
	for s in GameData.MAX_PLAYERS:
		var l := Label.new()
		if by_slot.has(s):
			l.text = "%s  -  %s" % [GameData.PLAYER_COLOR_NAMES[s], by_slot[s]]
			l.add_theme_color_override("font_color", GameData.player_color(s).lightened(0.25))
		else:
			l.text = "%s  -  (vrij)" % GameData.PLAYER_COLOR_NAMES[s]
			l.modulate = Color(1, 1, 1, 0.4)
		_players_box.add_child(l)
	_start_button.visible = multiplayer.is_server()
	if args.has("autostart") and multiplayer.is_server() and not Net.in_game:
		if Net.players.size() >= int(args["autostart"]):
			Net.start_game()


func _on_game_started() -> void:
	_ui.visible = false
	game = GameScript.new()
	game.name = "Game"
	add_child(game)
	if args.has("smoke-test"):
		var t := SmokeTest.new()
		t.game = game
		game.add_child(t)


func leave_game() -> void:
	Net.leave()
	_end_game("")


func _end_game(message: String) -> void:
	if game:
		remove_child(game)
		game.queue_free()
		game = null
	_ui.visible = true
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

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var bg := ColorRect.new()
	bg.color = Color(0.78, 0.6, 0.42)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "TOY WAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	outer.add_child(title)
	var sub := Label.new()
	sub.text = "Speelgoedsoldaatjes RTS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(sub)

	# Hoofdmenu
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	outer.add_child(_menu)
	_name_edit = _field(_menu, "Naam", "Speler")
	_ip_edit = _field(_menu, "IP van host", "127.0.0.1")
	_port_edit = _field(_menu, "Poort", str(Net.DEFAULT_PORT))
	_button(_menu, "Singleplayer", _on_single)
	_button(_menu, "Hosten (multiplayer)", _on_host)
	_button(_menu, "Meedoen", _on_join)
	_button(_menu, "Afsluiten", func(): get_tree().quit())

	# Lobby
	_lobby = VBoxContainer.new()
	_lobby.add_theme_constant_override("separation", 8)
	_lobby.visible = false
	outer.add_child(_lobby)
	_lobby_info = Label.new()
	_lobby.add_child(_lobby_info)
	_players_box = VBoxContainer.new()
	_lobby.add_child(_players_box)
	_start_button = _button(_lobby, "Start spel", func(): Net.start_game())
	_button(_lobby, "Lobby verlaten", _on_leave_lobby)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	outer.add_child(_status)


func _field(parent: Control, label: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(e)
	parent.add_child(row)
	return e


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
