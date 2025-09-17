## Watch Party

A minimal self-hosted watch party. Drag-and-drop a local video, share a link, and watch in sync with a friend. Peer-to-peer WebRTC stream with play/pause/seek synchronization. No uploads; the file stays on the host’s machine.

### Features
- **Drag & drop video**: Load any local `video/*` file in your browser.
- **Shareable room link**: Host auto-generates a `/room/{id}` URL you can send.
- **One host + one viewer**: Simple, low-latency session for two people.
- **In-sync controls**: Play, pause, seek stay synchronized via a data channel.
- **P2P streaming**: Server is only for signaling; media flows peer-to-peer.

### Tech Stack
- **Backend**: Node.js, Express, `ws` (WebSocket) for signaling
- **Frontend**: Vanilla JS + WebRTC (`RTCPeerConnection`, `DataChannel`)
- **STUN**: `stun:stun.l.google.com:19302`

### Repository Structure
```text
watch-party/
  └─ watch-party/
     ├─ server.js        # Express + WebSocket signaling + static hosting
     ├─ package.json     # start script: node server.js
     └─ public/
        ├─ index.html
        ├─ app.js        # WebRTC, room logic, sync
        └─ style.css

quick-deploy.sh          # Optional bootstrap script to scaffold and install
```

### Requirements
- Node.js ≥ 14
- Modern browser with `HTMLVideoElement.captureStream()` (Chrome/Edge/Firefox recommended)

### Quick Start (Local)
```bash
cd watch-party/watch-party
npm install
npm start
# Open http://localhost:3000
```

### How It Works (User Flow)
- **Host**: Open the app, drop a video, copy the link, share it. A room URL like `/room/abcd12` is created.
- **Viewer**: Open the shared URL to join and watch the host’s stream.
- **Sync**: Host actions (play/pause/seek) are sent over a data channel; the viewer mirrors them.

### Notes & Limitations
- Designed for **one-to-one** sessions (one host, one viewer).
- Rooms are kept **in-memory** on the server and cleared when peers disconnect.
- In production behind HTTPS, signaling will use **WSS** automatically.
- P2P may fail on very restrictive NATs/firewalls; consider TURN for broader reach (not included).
- Files never leave the host: the server does not receive or store media.

### Deployment
Any Node host works. Example on Render or similar platforms:
- **Root directory**: `watch-party`
- **Build command**: `npm install`
- **Start command**: `npm start`
- **Port**: `3000` (or set `PORT` env var). The client auto-selects `ws://` or `wss://` based on page protocol.

### Troubleshooting
- **Viewer sees black video**: Ensure the host loaded a file and pressed play once. Some browsers need initial user interaction for autoplay.
- **Cannot connect**: Check that your host is reachable over the internet, service uses HTTPS/WSS in production, and corporate/VPN firewalls aren’t blocking WebRTC.
- **High latency or stutter**: Try a smaller file, wired connection, or closer geographic proximity.

### Security & Privacy
- Media is streamed P2P between browsers; the signaling server only relays SDP/ICE messages.
