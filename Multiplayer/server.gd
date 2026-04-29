extends Node

## The port the server will listen on.
const PORT = 9080

signal client_player_update(rotation: float, color: Color, name: String)

var tcp_server := TCPServer.new()
var socket := WebSocketPeer.new()
var _name: String = ""
var _prev_ready_state: int = WebSocketPeer.STATE_CLOSED

func log_message(message: String) -> void:
	var time: String = Time.get_time_string_from_system()
	print(time + " - Server: " + message + "\n")


func _ready() -> void:
	_name = Globals._pick_random_names()
	log_message("Server ready — name: %s" % _name)
	if tcp_server.listen(PORT) != OK:
		log_message("Unable to start server.")
		set_process(false)
		return
	log_message("Server started on port: %s" % PORT)


func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		assert(conn != null)
		socket.accept_stream(conn)

	socket.poll()

	var ready_state: int = socket.get_ready_state()
	if ready_state == WebSocketPeer.STATE_OPEN and _prev_ready_state != WebSocketPeer.STATE_OPEN:
		var message = socket.get_packet().get_string_from_ascii()
		log_message("WebSocket peer connected: %s" % message)
	_prev_ready_state = ready_state

	if ready_state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var message = socket.get_packet().get_string_from_ascii()
			# log_message("Server Received message: %s" % message)
			if message.begins_with('{"player_state'):
				var player_state = parse_JSON(message)
				if player_state.size() > 0 and player_state.has("player_state"):
					handle_player_state(player_state["player_state"])
				else:
					log_message("Invalid game state: %s" % message)


func parse_JSON(message: String) -> Dictionary:
	var json_parser = JSON.new()
	var error = json_parser.parse(message)
	if error == OK:
		var data_received = json_parser.data
		return data_received
	return {}


# TBC - renmae to serevr handling player update
func handle_player_state(player_state: Dictionary) -> void:
	# print("SERVER - Handling player state: %s" % player_state)
	client_player_update.emit(player_state)


func _exit_tree() -> void:
	socket.close()
	tcp_server.stop()

func send_game_state(game_state: Dictionary) -> void:
	var json_string := JSON.stringify(game_state)
	var ready_state = socket.get_ready_state()
	# log_message("ready_state: %s" % ready_state)
	if ready_state == WebSocketPeer.STATE_OPEN:
		socket.send_text('{"game_state": %s}' % json_string)
