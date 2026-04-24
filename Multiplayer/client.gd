extends Node

## The URL we will connect to.
var websocket_url: String = "ws://localhost:9080"

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
	send_player_join()


func _process(_delta: float) -> void:
	socket.poll()

	var state: int = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _has_sent_join:
			_has_sent_join = true
			print("Sending player join")
			send_player_join()
		while socket.get_available_packet_count():
			log_message(socket.get_packet().get_string_from_ascii())
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
