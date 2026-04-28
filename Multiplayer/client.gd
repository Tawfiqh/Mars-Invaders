extends Node

## The URL we will connect to.
var websocket_url: String = "ws://localhost:9080"

signal game_state_update(game_state: Dictionary)

var socket := WebSocketPeer.new()
var _prev_ready_state: int = WebSocketPeer.STATE_CLOSED

var _name: String = ""


func log_message(message: String) -> void:
	var time: String = Time.get_time_string_from_system()
	print(time + " - Client: " + message + "\n")


func _ready() -> void:
	_name = Globals._pick_random_names()
	log_message("Client ready — name: %s" % _name)
	if socket.connect_to_url(websocket_url) != OK:
		log_message("Unable to connect.")
		set_process(false)
		return
	log_message("Connected to server: %s" % websocket_url)


func _process(_delta: float) -> void:
	socket.poll()

	var ready_state: int = socket.get_ready_state()

	if ready_state == WebSocketPeer.STATE_OPEN and _prev_ready_state != WebSocketPeer.STATE_OPEN:
		var message = socket.get_packet().get_string_from_ascii()
		log_message("WebSocket peer connected: %s" % message)
		# websocket_peer_opened.emit(_name)
	_prev_ready_state = ready_state


	if ready_state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var message = socket.get_packet().get_string_from_ascii()
			# print("Client Received message: %s" % message)
			if message.begins_with('{"game_state'):
				var game_state = _parse_json(message)
				if game_state.size() > 0 and game_state.has("game_state"):
					_handle_game_state(game_state["game_state"])
				else:
					log_message("Invalid game state: %s" % message)


func _exit_tree() -> void:
	socket.close()


func send_player_state(player_state: Dictionary) -> void:
	var json_string := JSON.stringify(player_state)
	socket.send_text('{"player_state": %s}' % json_string)


func _parse_json(message: String) -> Dictionary:
	var json_parser = JSON.new()
	if json_parser.parse(message) == OK:
		return json_parser.data
	return {}


func _handle_game_state(game_state: Dictionary) -> void:
	# log_message("Client Handling game state: %s" % game_state)
	game_state_update.emit(game_state)
