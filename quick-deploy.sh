#!/bin/bash

# Quick Deploy Script for Watch Party App
# Run this to create everything in one go!

echo "🎬 Creating Watch Party App..."

# Create directories
mkdir -p watch-party/public
cd watch-party

# Create server.js
cat > server.js << 'EOF'
const WebSocket = require('ws');
const express = require('express');
const app = express();
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

app.use(express.static('public'));
const rooms = new Map();

wss.on('connection', (ws) => {
  ws.on('message', (msg) => {
    try {
      const data = JSON.parse(msg);
      
      switch(data.type) {
        case 'join':
          if (!rooms.has(data.room)) rooms.set(data.room, new Set());
          rooms.get(data.room).add(ws);
          ws.room = data.room;
          
          if (rooms.get(data.room).size === 2) {
            rooms.get(data.room).forEach(client => {
              client.send(JSON.stringify({ type: 'peer-joined' }));
            });
          }
          break;
          
        case 'signal':
          rooms.get(ws.room)?.forEach(client => {
            if (client !== ws && client.readyState === WebSocket.OPEN) {
              client.send(msg);
            }
          });
          break;
      }
    } catch(e) {
      console.error('Message error:', e);
    }
  });
  
  ws.on('close', () => {
    if (ws.room && rooms.has(ws.room)) {
      rooms.get(ws.room).delete(ws);
      if (rooms.get(ws.room).size === 0) {
        rooms.delete(ws.room);
      } else {
        rooms.get(ws.room).forEach(client => {
          client.send(JSON.stringify({ type: 'peer-left' }));
        });
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

# Create package.json
cat > package.json << 'EOF'
{
  "name": "watch-party",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.14.2"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
EOF

# Create public/index.html
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Watch Party</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div id="app">
    <div id="dropZone" class="drop-zone">
      <p>📺 Drop video file here or click to browse</p>
      <input type="file" id="fileInput" accept="video/*" />
    </div>
    
    <video id="video" controls style="display:none"></video>
    
    <div id="status" class="status" style="display:none"></div>
    
    <div id="controls" class="controls" style="display:none">
      <button id="copyLink">📋 Copy Invite Link</button>
      <span id="linkCopied" style="display:none">✓ Copied!</span>
    </div>
  </div>
  
  <script src="app.js"></script>
</body>
</html>
EOF

# Create public/style.css
cat > public/style.css << 'EOF'
* { 
  margin: 0; 
  padding: 0; 
  box-sizing: border-box; 
}

body { 
  background: #0a0a0a; 
  color: #fff; 
  font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
}

#app {
  width: 100%;
  max-width: 1200px;
  padding: 20px;
}

.drop-zone {
  border: 3px dashed #333;
  border-radius: 20px;
  width: 100%;
  max-width: 600px;
  height: 400px;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.3s;
  background: rgba(255,255,255,0.02);
}

.drop-zone:hover,
.drop-zone.dragover {
  border-color: #0066ff;
  background: rgba(0,102,255,0.05);
  transform: scale(1.02);
}

.drop-zone p {
  font-size: 18px;
  color: #666;
  pointer-events: none;
}

#fileInput {
  display: none;
}

video {
  width: 100%;
  max-width: 100%;
  height: auto;
  border-radius: 10px;
  background: #000;
}

.status {
  position: fixed;
  top: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0,0,0,0.9);
  padding: 12px 24px;
  border-radius: 30px;
  font-size: 14px;
  border: 1px solid #222;
  z-index: 100;
}

.controls {
  position: fixed;
  bottom: 30px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 15px;
  align-items: center;
}

button {
  background: #0066ff;
  color: white;
  border: none;
  padding: 12px 24px;
  border-radius: 30px;
  cursor: pointer;
  font-size: 16px;
  font-weight: 500;
  transition: all 0.2s;
}

button:hover {
  background: #0052cc;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,102,255,0.4);
}

#linkCopied {
  color: #4caf50;
  font-weight: 500;
}

@media (max-width: 768px) {
  .drop-zone {
    height: 300px;
  }
  
  .controls {
    bottom: 20px;
  }
  
  button {
    font-size: 14px;
    padding: 10px 20px;
  }
}
EOF

# Create public/app.js (split into parts due to length)
cat > public/app.js << 'EOF'
class WatchParty {
  constructor() {
    this.roomId = this.getRoomId();
    this.isHost = !this.roomId;
    this.pc = null;
    this.ws = null;
    this.dc = null;
    this.ignoreEvents = false;
    this.init();
  }
  
  getRoomId() {
    const match = window.location.pathname.match(/\/room\/([^\/]+)/);
    return match ? match[1] : null;
  }
  
  init() {
    if (this.isHost) {
      this.setupHost();
    } else {
      this.setupViewer();
    }
  }
  
  setupHost() {
    this.roomId = Math.random().toString(36).substring(2, 8);
    history.pushState(null, '', `/room/${this.roomId}`);
    
    this.setupFileDrop();
    this.connectWebSocket();
    
    document.getElementById('controls').style.display = 'block';
    document.getElementById('copyLink').onclick = () => {
      navigator.clipboard.writeText(window.location.href);
      document.getElementById('linkCopied').style.display = 'inline';
      setTimeout(() => {
        document.getElementById('linkCopied').style.display = 'none';
      }, 2000);
    };
  }
  
  setupFileDrop() {
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const video = document.getElementById('video');
    
    dropZone.onclick = () => fileInput.click();
    
    dropZone.ondrop = (e) => {
      e.preventDefault();
      dropZone.classList.remove('dragover');
      const file = e.dataTransfer.files[0];
      if (file && file.type.startsWith('video/')) {
        this.loadVideo(file);
      }
    };
    
    dropZone.ondragover = (e) => {
      e.preventDefault();
      dropZone.classList.add('dragover');
    };
    
    dropZone.ondragleave = () => {
      dropZone.classList.remove('dragover');
    };
    
    fileInput.onchange = (e) => {
      const file = e.target.files[0];
      if (file) this.loadVideo(file);
    };
    
    video.onplay = () => {
      if (!this.ignoreEvents) this.sendSync('play', video.currentTime);
    };
    
    video.onpause = () => {
      if (!this.ignoreEvents) this.sendSync('pause', video.currentTime);
    };
    
    video.onseeked = () => {
      if (!this.ignoreEvents) this.sendSync('seek', video.currentTime);
    };
  }
  
  loadVideo(file) {
    const video = document.getElementById('video');
    const dropZone = document.getElementById('dropZone');
    
    dropZone.style.display = 'none';
    video.style.display = 'block';
    
    const url = URL.createObjectURL(file);
    video.src = url;
    
    if (this.pc && this.pc.connectionState === 'connected') {
      setTimeout(() => this.replaceStream(), 100);
    }
  }
  
  async replaceStream() {
    const video = document.getElementById('video');
    const stream = video.captureStream(30);
    
    const senders = this.pc.getSenders();
    const videoTrack = stream.getVideoTracks()[0];
    const audioTrack = stream.getAudioTracks()[0];
    
    if (videoTrack) {
      const videoSender = senders.find(s => s.track && s.track.kind === 'video');
      if (videoSender) {
        videoSender.replaceTrack(videoTrack);
      } else {
        this.pc.addTrack(videoTrack, stream);
      }
    }
    
    if (audioTrack) {
      const audioSender = senders.find(s => s.track && s.track.kind === 'audio');
      if (audioSender) {
        audioSender.replaceTrack(audioTrack);
      } else {
        this.pc.addTrack(audioTrack, stream);
      }
    }
    
    this.sendSync('reload', 0);
  }
  
  connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    this.ws = new WebSocket(`${protocol}//${window.location.host}`);
    
    this.ws.onopen = () => {
      this.ws.send(JSON.stringify({
        type: 'join',
        room: this.roomId
      }));
      
      if (!this.isHost) {
        document.getElementById('status').textContent = 'Connecting to host...';
        document.getElementById('status').style.display = 'block';
      }
    };
    
    this.ws.onmessage = async (event) => {
      const data = JSON.parse(event.data);
      
      if (data.type === 'peer-joined' && this.isHost) {
        await this.createOffer();
        document.getElementById('status').textContent = '✓ Viewer connected';
        document.getElementById('status').style.display = 'block';
      } else if (data.type === 'signal') {
        await this.handleSignal(data.signal);
      } else if (data.type === 'peer-left') {
        document.getElementById('status').textContent = 'Viewer disconnected';
        if (this.pc) {
          this.pc.close();
          this.pc = null;
        }
      }
    };
    
    this.ws.onerror = () => {
      document.getElementById('status').textContent = 'Connection error - refresh page';
      document.getElementById('status').style.display = 'block';
    };
  }
  
  async createOffer() {
    this.pc = new RTCPeerConnection({
      iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
    });
    
    this.dc = this.pc.createDataChannel('sync');
    this.dc.onopen = () => console.log('Data channel open');
    
    const video = document.getElementById('video');
    if (video.src) {
      const stream = video.captureStream(30);
      stream.getTracks().forEach(track => {
        this.pc.addTrack(track, stream);
      });
    }
    
    const offer = await this.pc.createOffer();
    await this.pc.setLocalDescription(offer);
    
    this.ws.send(JSON.stringify({
      type: 'signal',
      signal: { type: 'offer', sdp: offer }
    }));
    
    this.pc.onicecandidate = (e) => {
      if (e.candidate) {
        this.ws.send(JSON.stringify({
          type: 'signal',
          signal: { type: 'ice', candidate: e.candidate }
        }));
      }
    };
  }
  
  setupViewer() {
    document.getElementById('dropZone').style.display = 'none';
    document.getElementById('video').style.display = 'block';
    this.connectWebSocket();
  }
  
  async handleSignal(signal) {
    if (signal.type === 'offer' && !this.isHost) {
      this.pc = new RTCPeerConnection({
        iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
      });
      
      this.pc.ontrack = (event) => {
        const video = document.getElementById('video');
        if (video.srcObject !== event.streams[0]) {
          video.srcObject = event.streams[0];
          document.getElementById('status').style.display = 'none';
        }
      };
      
      this.pc.ondatachannel = (event) => {
        this.dc = event.channel;
        this.dc.onmessage = (e) => {
          const sync = JSON.parse(e.data);
          this.handleSync(sync);
        };
      };
      
      this.pc.onicecandidate = (e) => {
        if (e.candidate) {
          this.ws.send(JSON.stringify({
            type: 'signal',
            signal: { type: 'ice', candidate: e.candidate }
          }));
        }
      };
      
      await this.pc.setRemoteDescription(signal.sdp);
      const answer = await this.pc.createAnswer();
      await this.pc.setLocalDescription(answer);
      
      this.ws.send(JSON.stringify({
        type: 'signal',
        signal: { type: 'answer', sdp: answer }
      }));
      
    } else if (signal.type === 'answer' && this.isHost) {
      await this.pc.setRemoteDescription(signal.sdp);
      
    } else if (signal.type === 'ice') {
      if (this.pc) await this.pc.addIceCandidate(signal.candidate);
    }
  }
  
  sendSync(action, time) {
    if (this.dc && this.dc.readyState === 'open') {
      this.dc.send(JSON.stringify({ action, time }));
    }
  }
  
  handleSync(sync) {
    const video = document.getElementById('video');
    this.ignoreEvents = true;
    
    switch(sync.action) {
      case 'play':
        video.currentTime = sync.time;
        video.play();
        break;
      case 'pause':
        video.currentTime = sync.time;
        video.pause();
        break;
      case 'seek':
        video.currentTime = sync.time;
        break;
      case 'reload':
        video.load();
        break;
    }
    
    setTimeout(() => { this.ignoreEvents = false; }, 100);
  }
}

new WatchParty();
EOF

echo "✅ Files created!"
echo ""
echo "📦 Installing dependencies..."
npm install

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Test locally: npm start"
echo "2. Open browser: http://localhost:3000"
echo "3. Deploy to Render.com (see SETUP.md)"
echo ""
echo "To deploy:"
echo "  git init"
echo "  git add ."
echo "  git commit -m 'Initial commit'"
echo "  git remote add origin YOUR_GITHUB_REPO"
echo "  git push -u origin main"