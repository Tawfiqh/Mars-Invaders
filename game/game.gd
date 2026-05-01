extends Node2D


const GAME_OVER_SCENE = preload("res://ui/game_over/game_over.tscn")
const PLANET_SCENE = preload("res://elements/planet/planet.tscn")
const ENEMY_GROUP_SCENE = preload("res://elements/enemy_group/enemy_group.tscn")
const PLAYER_SHIP_SCENE = preload("res://elements/player_space_ship/player_space_ship.tscn")
const LEVEL_CLEAR_DELAY := 1.0

var _level_ending := false
var _remote_players: Dictionary = {}

@onready var _planet: Node2D = $Planet
@onready var _enemy_group: Node2D = $EnemyGroup
@onready var _local_player = $"Player SpaceShip"
@onready var _create_server_button: Button = $HUD/MultiplayerControls/MarginContainer/VBoxContainer/CreateServerButton
@onready var _join_server_button: Button = $HUD/MultiplayerControls/MarginContainer/VBoxContainer/JoinServerButton
@onready var _room_code_input: LineEdit = $HUD/MultiplayerControls/MarginContainer/VBoxContainer/RoomCodeInput
@onready var _connection_status_label: Label = $HUD/MultiplayerControls/MarginContainer/VBoxContainer/ConnectionStatusLabel

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Process and send current game state to server / client
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

func get_player_game_state() -> Dictionary:
	var player_name = my_name()

	var player_state: Dictionary = _local_player.serialize_state()
	player_state["name"] = player_name
	return player_state

func get_whole_game_state() -> Dictionary:
	var players_serialized = []
	for player_id in _remote_players:
		var player = _remote_players[player_id]
		players_serialized.append(player.serialize_state())

	var local_player = get_player_game_state()
	players_serialized.append(local_player)

	var serialized_enemy_group = _enemy_group.serialize_state() if is_instance_valid(_enemy_group) else {}
	var serialized_planet = _planet.serialize_state() if is_instance_valid(_planet) else {}

	return {
		"players": players_serialized,
		"enemy_group": serialized_enemy_group,
		"planet": serialized_planet,
		"score": Globals.points,
		"lives": Globals.lives,
	}


var time_since_last_update = 0.0
func _process(delta: float):
	# Cooldown to prevent spamming the server with updates
	if time_since_last_update < 0.1:
		time_since_last_update += delta
		return
	time_since_last_update = 0.0

	if Network.is_host():
		Network.send_game_state(get_whole_game_state())


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Update state from server / client
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func my_name() -> String:
	return _local_player.player_name


func _on_local_player_state_changed() -> void:
	if Network.is_connected_to_session():
		if Network.is_host():
			Network.send_game_state(get_whole_game_state())
		else:
			Network.send_player_state(get_player_game_state())

func _spawn_remote_player_ship(remote_player_name: String) -> void:
	if remote_player_name == my_name():
		return

	print("MY NAME: %s - Spawning remote player ship: %s" % [my_name(), remote_player_name])
	if _remote_players.has(remote_player_name):
		return
	var inst = PLAYER_SHIP_SCENE.instantiate()
	inst.name = remote_player_name
	inst.position = Vector2(128, 135.0)
	inst.is_remote = true
	inst.tree_exited.connect(_on_remote_player_tree_exited.bind(remote_player_name))
	add_child(inst)
	_remote_players[remote_player_name] = inst

func _on_remote_player_tree_exited(player_name: String) -> void:
	_remote_players.erase(player_name)


func _update_remote_player(player_state: Dictionary) -> void:
	var playerName = player_state["name"]
	if playerName == my_name(): # dont update own player
		return

	if not _remote_players.has(playerName) and playerName != "":
		print("GAME.GD: Spawning remote player: %s (not found atm)" % playerName)
		_spawn_remote_player_ship(playerName)
	if _remote_players.has(playerName):
		var player = _remote_players[playerName]
		player.deserialize_and_update_state(player_state)

func _update_game_state(game_state: Dictionary) -> void:
	# print("CLIENT - GAME.GD: Updating game state: %s" % game_state)
	for player_state in game_state["players"]:
		_update_remote_player(player_state)

	if game_state.has("enemy_group"):
		_enemy_group.deserialize_and_update_state(game_state["enemy_group"])
	if game_state.has("planet"):
		_planet.deserialize_and_update_state(game_state["planet"])
	if game_state.has("score"):
		var score = int(game_state["score"])
		if score != Globals.points:
			Globals.points = score
			Events.points_changed.emit(Globals.points)
	if game_state.has("lives"):
		var lives = int(game_state["lives"])
		if lives != Globals.lives:
			Globals.lives = lives
			Events.lives_changed.emit(Globals.lives)


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Setup server / client (WebRTC P2P via Network singleton)
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func _start_server() -> void:
	_connection_status_label.text = "Connecting…"
	_set_multiplayer_controls_visible(false)
	Network.host_room()


func _start_client() -> void:
	var room_code := _room_code_input.text.strip_edges()
	if room_code.is_empty():
		_connection_status_label.text = "Enter a room code"
		return
	_connection_status_label.text = "Connecting…"
	_set_multiplayer_controls_visible(false)
	Network.join_room(room_code)


func _on_lobby_created(room_code: String) -> void:
	_connection_status_label.text = "Room: %s" % room_code


func _on_session_started(as_host: bool) -> void:
	if as_host:
		# Lobby code already shown by _on_lobby_created.
		return
	_connection_status_label.text = "Connected"


func _on_session_ended(reason: String) -> void:
	_connection_status_label.text = "Disconnected: %s" % reason
	_set_multiplayer_controls_visible(true)


func _set_multiplayer_controls_visible(visible: bool) -> void:
	_create_server_button.visible = visible
	_join_server_button.visible = visible
	_room_code_input.visible = visible


func _on_peer_disconnected_from_session(peer_id: int) -> void:
	# We don't yet map peer_id -> player_name, so we can't free their ship here.
	# Stale ship will linger until the next level reload.
	print("Peer %d disconnected from WebRTC session" % peer_id)
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# OLD Non refactored bits
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func _ready():
	Events.lives_changed.connect(func(_lives): _check_game_state())
	Events.enemy_died.connect(_check_game_state)
	_local_player.player_state_changed.connect(_on_local_player_state_changed)
	_room_code_input.text = ""
	_connection_status_label.text = ""
	_set_multiplayer_controls_visible(true)
	Network.lobby_created.connect(_on_lobby_created)
	Network.session_started.connect(_on_session_started)
	Network.session_ended.connect(_on_session_ended)
	Network.peer_player_update.connect(_update_remote_player)
	Network.game_state_update.connect(_update_game_state)
	Network.peer_disconnected_from_session.connect(_on_peer_disconnected_from_session)


func _check_game_state():
	if _level_ending:
		return

	if Globals.lives <= 0:
		_level_ending = true
		add_child(GAME_OVER_SCENE.instantiate())
		return

	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.size() <= 1:
		_level_ending = true
		Events.level_cleared.emit()
		await get_tree().create_timer(LEVEL_CLEAR_DELAY).timeout
		_start_next_level()


func _start_next_level():
	if Network.is_connected_to_session() and not Network.is_host():
		print("CLIENT - GAME.GD: Not starting next level as this is a client -- waiting for server to start next level")
		return
	var planet_pos := _planet.position
	var group_pos := _enemy_group.position

	_planet.queue_free()
	_enemy_group.queue_free()
	await get_tree().process_frame

	_planet = PLANET_SCENE.instantiate()
	_planet.position = planet_pos
	add_child(_planet)

	_enemy_group = ENEMY_GROUP_SCENE.instantiate()
	_enemy_group.position = group_pos
	add_child(_enemy_group)

	_level_ending = false
