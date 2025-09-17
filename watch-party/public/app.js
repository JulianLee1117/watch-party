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
