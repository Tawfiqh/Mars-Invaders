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


func _ready():
	Events.lives_changed.connect(func(_lives): _check_game_state())
	Events.enemy_died.connect(_check_game_state)

func get_current_client_game_state() -> Dictionary:
	var player = $"Player SpaceShip/Pivot"
	return {
		"player": {
			"name": currentClient._name,
			"rotation": player.rotation,
			"color": player.color.to_html(),
		}
	}


func _spawn_remote_player_ship(name: String) -> void:
	print("Spawning remote player ship: %s" % name)
	if _remote_players.has(name):
		return
	var inst = PLAYER_SHIP_SCENE.instantiate()
	inst.name = name
	inst.position = Vector2(128, 135.0)
	add_child(inst)
	_remote_players[name] = inst


func _update_remote_player(newRotation: float, newColor: Color, playerName: String) -> void:
	print("Updating remote player: %s" % playerName)
	if _remote_players.has(playerName):
		var player = _remote_players[playerName]
		var pivot = player.get_node("Pivot")
		pivot.set_player_color(newColor)
		player.rotation = newRotation

var time_since_last_update = 0.0

func _process(delta: float):
	if time_since_last_update < 0.3:
		time_since_last_update += delta
		return ;

	time_since_last_update = 0.0

	# if currentServer != null:
	# 	currentServer.pong()

	if currentClient != null:
		currentClient.send_game_state(get_current_client_game_state())

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


func _start_server() -> void:
	print("STARTING SERVER")
	currentServer = SERVER.instantiate()
	currentServer.websocket_peer_opened.connect(_spawn_remote_player_ship)
	currentServer.remote_player_update.connect(_update_remote_player)
	add_child(currentServer)


func _start_client() -> void:
	print("JOINING SERVER = Starting client")
	# ip_address = $IPAddress.text
	currentClient = CLIENT.instantiate()
	add_child(currentClient)
