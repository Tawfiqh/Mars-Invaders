extends Node

## The port the server will listen on.
const PORT = 9080

signal websocket_peer_opened(name: String)
signal remote_player_update(rotation: float, color: Color, name: String)

var tcp_server := TCPServer.new()
var socket := WebSocketPeer.new()
var _name: String = ""
var _prev_ready_state: int = WebSocketPeer.STATE_CLOSED

func log_message(message: String) -> void:
	var time: String = Time.get_time_string_from_system()
	print(time + message + "\n")


func _ready() -> void:
	_name = Globals._pick_random_names()
	log_message("Server ready — name: %s" % _name)
	if tcp_server.listen(PORT) != OK:
		log_message("Unable to start server.")
		set_process(false)


func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		assert(conn != null)
		socket.accept_stream(conn)

	socket.poll()

	var ready_state: int = socket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN and _prev_ready_state != WebSocketPeer.STATE_OPEN:
		log_message("WebSocket peer connected.")
		var message = socket.get_packet().get_string_from_ascii()
		log_message("WebSocket peer connected: %s" % message)
		websocket_peer_opened.emit(_name)
	_prev_ready_state = ready_state

	if ready_state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var message = socket.get_packet().get_string_from_ascii()
			print("Received message: %s" % message)
			if message.begins_with('{"game_state'):
				var game_state = parse_JSON(message)
				if game_state.size() > 0 and game_state.has("game_state"):
					handle_game_state(game_state["game_state"])
				else:
					log_message("Invalid game state: %s" % message)
			elif message.begins_with('{"join":'):
				var json = parse_JSON(message)
				var join_name = json["join"] as String
				log_message("Player joined: %s" % join_name)
				websocket_peer_opened.emit(join_name)


func parse_JSON(message: String) -> Dictionary:
	var json_parser = JSON.new()
	var error = json_parser.parse(message)
	if error == OK:
		var data_received = json_parser.data
		return data_received
	return {}


func handle_game_state(game_state: Dictionary) -> void:
	var player_rotation = game_state["player"]["rotation"]
	var player_color = Color(game_state["player"]["color"])
	var name = game_state["player"]["name"]
	remote_player_update.emit(player_rotation, player_color, name)


func _exit_tree() -> void:
	socket.close()
	tcp_server.stop()


func pong() -> void:
	socket.send_text("Pong [from %s]" % _name)
