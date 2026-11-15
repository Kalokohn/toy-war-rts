extends Node
## Lobby en verbinding. De host is ook de server (peer id 1) en is baas over
## de spelstatus. Clients sturen alleen commando's.

signal players_changed
signal game_started
signal connection_failed(reason: String)
signal server_lost

const DEFAULT_PORT := 7777

## peer_id -> {"name": String, "slot": int, "faction": String}
var players := {}
var local_name := "Speler"
var local_faction := "soldiers"
var in_game := false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int, player_name: String, faction: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, GameData.MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	local_faction = faction
	players = {1: {"name": player_name, "slot": 0, "faction": faction}}
	in_game = false
	players_changed.emit()
	return OK


func join(address: String, port: int, player_name: String, faction: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	local_name = player_name
	local_faction = faction
	players = {}
	in_game = false
	return OK


func start_singleplayer(player_name: String, faction: String) -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	local_name = player_name
	local_faction = faction
	players = {1: {"name": player_name, "slot": 0, "faction": faction}}
	start_game()


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_game = false


## Alleen de host start het spel.
func start_game() -> void:
	if not multiplayer.is_server() or in_game:
		return
	_start_game.rpc()


func get_slot(peer_id: int) -> int:
	if players.has(peer_id):
		return int(players[peer_id]["slot"])
	return -1


func get_faction(slot: int) -> String:
	for p in players.values():
		if int(p["slot"]) == slot:
			return p.get("faction", "soldiers")
	return "soldiers"


func my_slot() -> int:
	return max(get_slot(multiplayer.get_unique_id()), 0)


func is_host() -> bool:
	return multiplayer.is_server()


func _free_slot() -> int:
	var used := []
	for p in players.values():
		used.append(int(p["slot"]))
	for s in GameData.MAX_PLAYERS:
		if not s in used:
			return s
	return -1


func _on_connected_to_server() -> void:
	_register_player.rpc_id(1, local_name, local_faction)


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Kon niet verbinden met de host.")


func _on_server_disconnected() -> void:
	leave()
	server_lost.emit()


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		players.erase(id)
		_sync_players.rpc(players)


@rpc("any_peer", "reliable")
func _register_player(player_name: String, faction: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var slot := _free_slot()
	if in_game or slot < 0:
		# Spel is al bezig of vol: verbinding weigeren.
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var clean := player_name.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Speler %d" % (slot + 1)
	if not GameData.FACTIONS.has(faction):
		faction = "soldiers"
	players[id] = {"name": clean, "slot": slot, "faction": faction}
	_sync_players.rpc(players)


## Faction wisselen in de lobby.
func set_faction(faction: String) -> void:
	local_faction = faction
	if multiplayer.multiplayer_peer and not in_game:
		_request_faction.rpc_id(1, faction)


@rpc("any_peer", "call_local", "reliable")
func _request_faction(faction: String) -> void:
	if not multiplayer.is_server() or in_game or not GameData.FACTIONS.has(faction):
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = multiplayer.get_unique_id()
	if players.has(id):
		players[id]["faction"] = faction
		_sync_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func _sync_players(new_players: Dictionary) -> void:
	players = new_players
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	in_game = true
	game_started.emit()
