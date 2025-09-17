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
