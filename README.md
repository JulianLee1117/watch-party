## Watch Party

A minimal self-hosted watch party. Drag-and-drop a local video, share a link, and watch in sync with a friend. Peer-to-peer WebRTC stream with play/pause/seek synchronization. No uploads; the file stays on the host’s machine.

### Features
- **Drag & drop video**: Load any local `video/*` file in your browser.
- **Shareable room link**: Host auto-generates a `/room/{id}` URL you can send.
- **One host + one viewer**: Simple, low-latency session for two people.
- **Bidirectional sync**: Play, pause, seek are synchronized from either side via a data channel.
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
        ├─ app.js        # WebRTC, room logic, sync, quality tuning
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
- **Sync**: Actions (play/pause/seek) from host or viewer are sent over a WebRTC data channel; both sides mirror them.

### Deep Linking
- The server serves `public/index.html` for `/room/:id` so direct links work.
- Static assets are referenced with absolute paths (`/app.js`, `/style.css`) so deep links load JS/CSS correctly.

### Autoplay & Permissions
- Browsers often block autoplay with sound. On the viewer, the video starts muted and attempts autoplay.
- If autoplay is blocked, a prompt appears; click the video once to allow playback, then you can unmute.

### Quality Settings
- Host sets `contentHint='motion'` on the video track.
- Adaptive sender params are applied on the host (maintain-resolution, target framerate 30, and higher `maxBitrate` based on source resolution).
- Codec preference (if available): AV1 → VP9 → H264.
- Expect a few seconds for bitrate to ramp up after connection. Verify in `chrome://webrtc-internals`.

### Notes & Limitations
- Designed for **one-to-one** sessions (one host, one viewer).
- Rooms are kept **in-memory** on the server and cleared when peers disconnect.
- In production behind HTTPS, signaling will use **WSS** automatically.
- P2P may fail on very restrictive NATs/firewalls; consider adding a TURN server for broader reach (not included).
- Files never leave the host: the server does not receive or store media.

### Deployment
Any Node host works. Example on Render or similar platforms:
- **Root directory**: `watch-party`
- **Build command**: `npm install`
- **Start command**: `npm start`
- **Port**: `3000` (or set `PORT` env var). The client auto-selects `ws://` or `wss://` based on page protocol.

### Troubleshooting
- **Deep-linked page looks unstyled or JS fails with "Unexpected token '<'"**: Ensure assets are referenced with absolute paths (`/app.js`, `/style.css`).
- **Viewer stuck on "Connecting to host…" with Blob JSON errors**: Ensure the server forwards signaling as JSON (already handled here) and refresh both tabs.
- **Viewer can’t start playback**: Click the video once to satisfy browser autoplay policy, then unmute.
- **Poor quality**: Give it a few seconds to ramp. Check upload bandwidth, try a wired connection, or add TURN for challenging networks.

### Security & Privacy
- Media is streamed P2P between browsers; the signaling server only relays SDP/ICE messages.
