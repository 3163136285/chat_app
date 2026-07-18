const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

app.use(cors());
app.use(express.json());

// 静态资源（网页版）
app.use(express.static(path.join(__dirname, 'public')));

// 健康检查
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// 路由注册
app.use('/api/login', require('./routes/auth'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/chat', require('./routes/messages'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/location', require('./routes/location'));
app.use('/api/location-sharing', require('./routes/location'));
app.use('/api/messages/search', require('./routes/search'));
app.use('/api/stickers', require('./routes/stickers'));

// Socket.io 处理器
require('./socket/handlers')(io);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
