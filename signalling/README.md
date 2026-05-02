# Signalling server

Tiny WebSocket relay that bootstraps WebRTC connections between game peers. Game traffic itself never flows through here — only the brief handshake.

## Local run

```bash
cd signalling
npm install
npm start
# Signalling server listening on port 9080
```

Point the game's `DEFAULT_SIGNALLING_URL` (in `Multiplayer/network.gd`) at `ws://localhost:9080` for local testing.

## Deploy to Railway

1. Push this repo to GitHub (or wherever Railway pulls from).
2. In Railway: New Project → Deploy from GitHub repo → pick this repo. Set the root directory to `signalling/`.
3. Railway auto-detects Node, runs `npm install`, runs `npm start`. It injects `PORT` automatically.
4. Generate a public domain in Railway's "Settings → Networking → Generate domain" — you'll get `your-app.up.railway.app`.
5. Update `DEFAULT_SIGNALLING_URL` in `Multiplayer/network.gd` to `wss://your-app.up.railway.app` (note: `wss://`, not `ws://`).

## Protocol

JSON-over-WebSocket. Each message: `{type: int, id: int, data: string}`. Type codes:

| # | Name | Direction | Meaning |
| --- | --- | --- | --- |
| 0 | JOIN | C→S / S→C | Client joins a lobby (data=room code, blank to create); server echoes assigned lobby name |
| 1 | ID | S→C | Server tells the client its assigned peer id (1 = host) |
| 2 | PEER_CONNECT | S→C | A new peer joined the lobby |
| 3 | PEER_DISCONNECT | S→C | A peer left |
| 4 | OFFER | relay | WebRTC SDP offer |
| 5 | ANSWER | relay | WebRTC SDP answer |
| 6 | CANDIDATE | relay | WebRTC ICE candidate (data: `\nmid\nindex\nsdp`) |
| 7 | SEAL | C→S | Host closes the lobby to new joiners |

Identical to Godot's official `webrtc_signaling` demo — clients written for that demo will work against this server unmodified.
