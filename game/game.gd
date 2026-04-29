extends Node2D


const SERVER = preload("res://Multiplayer/Server.tscn")
const CLIENT = preload("res://Multiplayer/Client.tscn")
var currentServer = null
var currentClient = null

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

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Process and send current game state to server / client
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

func get_player_game_state() -> Dictionary:
	var name = my_name()

	var player_state: Dictionary = _local_player.serialize_state()
	player_state["name"] = name
	return player_state

func get_whole_game_state() -> Dictionary:
	var players_serialized = []
	for player_id in _remote_players:
		var player = _remote_players[player_id]
		players_serialized.append(player.serialize_state())

	var local_player = get_player_game_state()
	players_serialized.append(local_player)

	var serialized_enemy_group = _enemy_group.serialize_state()
	var serialized_planet = _planet.serialize_state()

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

	if currentServer != null:
		currentServer.send_game_state(get_whole_game_state())


# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Update state from server / client
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func my_name() -> String:
	return _local_player.player_name


func _on_local_player_state_changed() -> void:
	if currentClient != null:
		currentClient.send_player_state(get_player_game_state())
	if currentServer != null:
		currentServer.send_game_state(get_whole_game_state())

func _spawn_remote_player_ship(name: String) -> void:
	if name == my_name():
		return

	print("MY NAME: %s - Spawning remote player ship: %s" % [my_name(), name])
	if _remote_players.has(name):
		return
	var inst = PLAYER_SHIP_SCENE.instantiate()
	inst.name = name
	inst.position = Vector2(128, 135.0)
	inst.is_remote = true
	add_child(inst)
	_remote_players[name] = inst


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
# Setup server / client
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func _start_server() -> void:
	if currentClient != null:
		print("STOPPING CLIENT")
		currentClient.queue_free()

	print("STARTING SERVER")
	currentServer = SERVER.instantiate()
	currentServer.client_player_update.connect(_update_remote_player)
	add_child(currentServer)


func _start_client() -> void:
	if currentServer != null:
		print("STOPPING SERVER")
		currentServer.queue_free()

	print("JOINING SERVER = Starting client")
	currentClient = CLIENT.instantiate()
	currentClient.game_state_update.connect(_update_game_state)
	add_child(currentClient)
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# OLD Non refactored bits
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
func _ready():
	Events.lives_changed.connect(func(_lives): _check_game_state())
	Events.enemy_died.connect(_check_game_state)
	_local_player.player_state_changed.connect(_on_local_player_state_changed)


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
