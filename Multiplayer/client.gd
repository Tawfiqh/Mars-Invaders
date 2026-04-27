extends Node

## The URL we will connect to.
var websocket_url: String = "ws://localhost:9080"

signal remote_player_update(rotation: float, color: Color, name: String)

var socket := WebSocketPeer.new()
var _name: String = ""
var _has_sent_join: bool = false


func log_message(message: String) -> void:
	var time: String = Time.get_time_string_from_system()
	print(time + message + "\n")


func _ready() -> void:
	_name = Globals._pick_random_names()
	log_message("Client ready — name: %s" % _name)
	if socket.connect_to_url(websocket_url) != OK:
		log_message("Unable to connect.")
		set_process(false)
		return
	# send_player_join()


func _process(_delta: float) -> void:
	socket.poll()

	var state: int = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _has_sent_join:
			_has_sent_join = true
			print("Sending player join")
			send_player_join()
		while socket.get_available_packet_count():
			var message = socket.get_packet().get_string_from_ascii()
			# print("Client Received message: %s" % message)
			if message.begins_with('{"game_state'):
				var game_state = _parse_json(message)
				if game_state.size() > 0 and game_state.has("game_state"):
					_handle_game_state(game_state["game_state"])
				else:
					log_message("Invalid game state: %s" % message)
			else:
				log_message(message)
	elif state == WebSocketPeer.STATE_CLOSED:
		_has_sent_join = false


func _exit_tree() -> void:
	socket.close()


func ping() -> void:
	socket.send_text("Ping [from %s]" % _name)

func send_game_state(game_state: Dictionary) -> void:
	var json_string := JSON.stringify(game_state)
	socket.send_text('{"game_state": %s}' % json_string)


func send_player_join() -> void:
	socket.send_text('{"join": "%s"}' % _name)


func _parse_json(message: String) -> Dictionary:
	var json_parser = JSON.new()
	if json_parser.parse(message) == OK:
		return json_parser.data
	return {}


func _handle_game_state(game_state: Dictionary) -> void:
	var player_data = game_state["player"]
	var player_rotation: float = player_data["rotation"]
	var player_color := Color(player_data["color"])
	var player_name: String = player_data["name"]
	remote_player_update.emit(player_rotation, player_color, player_name)
