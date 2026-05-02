extends Node
##
## Multiplayer transport for godot-invaders.
##
## Combines a WebSocket signalling client with WebRTCMultiplayerPeer (star topology:
## peer id 1 is host, 2..N are clients). After the handshake completes, all game
## traffic flows directly browser-to-browser over WebRTC data channels — the
## signalling server only carries SDP offers/answers and ICE candidates.
##
## Adapted from Godot's official `networking/webrtc_signaling` demo.

## Default signalling URL. Point at your Railway deployment for production
## (e.g. wss://godot-invaders-signalling.up.railway.app); ws://localhost:9080
## works for local testing.
const DEFAULT_SIGNALLING_URL := "ws://localhost:9080"

## Public STUN server. Helps NAT traversal for non-LAN players; harmless on LAN.
const ICE_SERVERS := [{"urls": ["stun:stun.l.google.com:19302"]}]

## Signalling protocol message types — must match server.js CMD enum.
enum Msg {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
}

signal connecting
signal lobby_created(room_code: String)
signal session_started(as_host: bool)
signal session_ended(reason: String)
signal peer_player_update(player_state: Dictionary)
signal game_state_update(game_state: Dictionary)
signal peer_disconnected_from_session(peer_id: int)

var _ws := WebSocketPeer.new()
var _rtc := WebRTCMultiplayerPeer.new()
var _ws_old_state := WebSocketPeer.STATE_CLOSED
var _is_host_flag := false
var _is_connected := false
var _pending_room_code := ""


func _ready() -> void:
	set_process(true)


func is_host() -> bool:
	return _is_host_flag


func is_connected_to_session() -> bool:
	return _is_connected


## Create a new lobby. The signalling server picks the room code and sends it
## back via `lobby_created`.
func host_room(signalling_url: String = DEFAULT_SIGNALLING_URL) -> void:
	_pending_room_code = ""
	_connect_signalling(signalling_url)


## Join an existing lobby by room code (the long string the host shared).
func join_room(room_code: String, signalling_url: String = DEFAULT_SIGNALLING_URL) -> void:
	_pending_room_code = room_code
	_connect_signalling(signalling_url)


func leave() -> void:
	_teardown("Left session")


func send_player_state(state: Dictionary) -> void:
	if not _is_connected or _is_host_flag:
		return
	_receive_player_state.rpc_id(1, state)


func send_game_state(state: Dictionary) -> void:
	if not _is_connected or not _is_host_flag:
		return
	_receive_game_state.rpc(state)


# --- Signalling state machine -------------------------------------------------

func _connect_signalling(url: String) -> void:
	_teardown("")
	connecting.emit()
	var err := _ws.connect_to_url(url)
	if err != OK:
		session_ended.emit("Signalling connect failed: %s" % err)


func _process(_delta: float) -> void:
	_poll_signalling()


func _poll_signalling() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED and _ws_old_state == WebSocketPeer.STATE_CLOSED:
		return
	_ws.poll()
	var state := _ws.get_ready_state()

	if state != _ws_old_state and state == WebSocketPeer.STATE_OPEN:
		# WebSocket open — issue JOIN. Star topology (id=1 means "non-mesh").
		_send_signalling(Msg.JOIN, 1, _pending_room_code)

	while state == WebSocketPeer.STATE_OPEN and _ws.get_available_packet_count():
		_handle_signalling_packet()

	if state != _ws_old_state and state == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		var reason := _ws.get_close_reason()
		if not _is_connected:
			# Closed before WebRTC came up — unrecoverable.
			session_ended.emit("Signalling closed (%d): %s" % [code, reason])
		# After WebRTC is up, the signalling channel is no longer needed.

	_ws_old_state = state


func _handle_signalling_packet() -> void:
	var raw := _ws.get_packet().get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Bad signalling packet: %s" % raw)
		return
	var msg := parsed as Dictionary
	if not msg.has("type") or not msg.has("id"):
		return
	var type := int(msg.type)
	var src_id := int(msg.id)
	var data: String = msg.get("data", "")

	match type:
		Msg.ID:
			_on_assigned_id(src_id)
		Msg.JOIN:
			lobby_created.emit(data)
		Msg.PEER_CONNECT:
			_on_peer_announced(src_id)
		Msg.PEER_DISCONNECT:
			_on_peer_left(src_id)
		Msg.OFFER:
			_apply_remote_description(src_id, "offer", data)
		Msg.ANSWER:
			_apply_remote_description(src_id, "answer", data)
		Msg.CANDIDATE:
			_apply_remote_candidate(src_id, data)
		Msg.SEAL:
			pass  # Lobby sealed — no joiners after this point. Active game continues.
		_:
			push_warning("Unknown signalling msg type: %d" % type)


func _send_signalling(type: int, id: int, data: String = "") -> void:
	var payload := JSON.stringify({"type": type, "id": id, "data": data})
	_ws.send_text(payload)


# --- WebRTC wiring ------------------------------------------------------------

func _on_assigned_id(my_id: int) -> void:
	_is_host_flag = (my_id == 1)
	if _is_host_flag:
		_rtc.create_server()
	else:
		_rtc.create_client(my_id)
	multiplayer.multiplayer_peer = _rtc
	_is_connected = true
	session_started.emit(_is_host_flag)


func _on_peer_announced(peer_id: int) -> void:
	# A new peer joined the lobby. Allocate a WebRTCPeerConnection for them.
	var peer := WebRTCPeerConnection.new()
	if peer.initialize({"iceServers": ICE_SERVERS}) != OK:
		push_warning("WebRTCPeerConnection.initialize failed for peer %d" % peer_id)
		return
	peer.session_description_created.connect(_on_session_description_created.bind(peer_id))
	peer.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_id))
	_rtc.add_peer(peer, peer_id)
	# Whichever side has the LOWER id creates the offer (so both sides agree).
	if peer_id < _rtc.get_unique_id():
		peer.create_offer()


func _on_peer_left(peer_id: int) -> void:
	if _rtc.has_peer(peer_id):
		_rtc.remove_peer(peer_id)
	peer_disconnected_from_session.emit(peer_id)


func _on_session_description_created(type: String, sdp: String, peer_id: int) -> void:
	if not _rtc.has_peer(peer_id):
		return
	_rtc.get_peer(peer_id).connection.set_local_description(type, sdp)
	if type == "offer":
		_send_signalling(Msg.OFFER, peer_id, sdp)
	else:
		_send_signalling(Msg.ANSWER, peer_id, sdp)


func _on_ice_candidate_created(mid: String, index: int, sdp: String, peer_id: int) -> void:
	_send_signalling(Msg.CANDIDATE, peer_id, "\n%s\n%d\n%s" % [mid, index, sdp])


func _apply_remote_description(peer_id: int, type: String, sdp: String) -> void:
	if _rtc.has_peer(peer_id):
		_rtc.get_peer(peer_id).connection.set_remote_description(type, sdp)


func _apply_remote_candidate(peer_id: int, packed: String) -> void:
	if not _rtc.has_peer(peer_id):
		return
	var parts := packed.split("\n", false)
	if parts.size() != 3 or not parts[1].is_valid_int():
		push_warning("Malformed candidate payload: %s" % packed)
		return
	_rtc.get_peer(peer_id).connection.add_ice_candidate(parts[0], parts[1].to_int(), parts[2])


# --- RPC payload handlers (set on the multiplayer node, transported via WebRTC) ---

@rpc("any_peer", "call_remote", "unreliable")
func _receive_player_state(state: Dictionary) -> void:
	# Runs on the host: a client just sent us their player state.
	if multiplayer.is_server():
		peer_player_update.emit(state)


@rpc("authority", "call_remote", "unreliable")
func _receive_game_state(state: Dictionary) -> void:
	# Runs on clients: host broadcast the world snapshot.
	game_state_update.emit(state)


# --- Cleanup ------------------------------------------------------------------

func _teardown(reason: String) -> void:
	var mp := multiplayer
	if mp != null and mp.multiplayer_peer == _rtc:
		mp.multiplayer_peer = null
	_rtc.close()
	_rtc = WebRTCMultiplayerPeer.new()
	if _ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_ws.close()
	_ws_old_state = WebSocketPeer.STATE_CLOSED
	_is_connected = false
	_is_host_flag = false
	if reason != "":
		session_ended.emit(reason)
