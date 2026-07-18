const MessageService = require('../services/messageService');
const LocationService = require('../services/locationService');
const UserService = require('../services/userService');

function setupSocketHandlers(io) {
  const onlineUsers = new Map();

  io.on('connection', (socket) => {
    const token = socket.handshake.auth?.token;
    if (!token) {
      socket.disconnect();
      return;
    }

    // 解析 token 获取用户 ID
    let userId, username;
    try {
      const jwt = require('jsonwebtoken');
      const { SECRET } = require('../middleware/auth');
      const decoded = jwt.verify(token, SECRET);
      userId = decoded.id || decoded.userId;
      username = decoded.username;
    } catch (e) {
      socket.disconnect();
      return;
    }

    onlineUsers.set(socket.id, userId);
    socket.broadcast.emit('user_online', { userId, username });
    socket.emit('online_users', [...onlineUsers.values()].filter((v, i, a) => a.indexOf(v) === i));

    socket.on('disconnect', () => {
      onlineUsers.delete(socket.id);
      // 延迟检查是否还有其他连接
      setTimeout(() => {
        const stillOnline = [...onlineUsers.values()].includes(userId);
        if (!stillOnline) {
          socket.broadcast.emit('user_offline', { userId, username });
        }
      }, 3000);
    });

    socket.on('private_message', async (data) => {
      const message = await MessageService.create({
        senderId: userId,
        senderName: username || userId,
        receiverId: data.to,
        content: data.content,
        type: data.type || 'text',
        attachment: data.attachment || null,
      });

      const targetSockets = [...onlineUsers.entries()]
        .filter(([sid, uid]) => uid === data.to)
        .map(([sid]) => sid);
      targetSockets.forEach(sid => io.to(sid).emit('new_message', message));
      socket.emit('message_sent', message);
    });

    socket.on('typing', (data) => {
      const targetSockets = [...onlineUsers.entries()]
        .filter(([sid, uid]) => uid === data.to)
        .map(([sid]) => sid);
      targetSockets.forEach(sid => io.to(sid).emit('typing', { from: userId, username }));
    });

    socket.on('stop_typing', (data) => {
      const targetSockets = [...onlineUsers.entries()]
        .filter(([sid, uid]) => uid === data.to)
        .map(([sid]) => sid);
      targetSockets.forEach(sid => io.to(sid).emit('stop_typing', { from: userId }));
    });

    socket.on('mark_read', async (data) => {
      const updated = await MessageService.markRead(data.messageId);
      if (updated) {
        const senderSockets = [...onlineUsers.entries()]
          .filter(([sid, uid]) => uid === updated.senderId)
          .map(([sid]) => sid);
        senderSockets.forEach(sid => io.to(sid).emit('message_read', { messageId: data.messageId, readAt: updated.readAt }));
      }
    });

    socket.on('recall_message', async (data) => {
      const updated = await MessageService.recall(data.messageId);
      if (updated) {
        io.emit('message_recalled', { messageId: data.messageId });
      }
    });

    socket.on('location_update', async (data) => {
      await LocationService.record(userId, data.lat, data.lng);
      socket.broadcast.emit('location_update', { userId, lat: data.lat, lng: data.lng });
    });

    // ========== WebRTC 视频通话信令 ==========
    socket.on('call_request', (data) => {
      const targetSockets = [...onlineUsers.entries()]
        .filter(([sid, uid]) => uid === data.to)
        .map(([sid]) => sid);
      targetSockets.forEach(sid => io.to(sid).emit('incoming_call', { from: userId, username, fromSocketId: socket.id }));
    });

    socket.on('call_accept', (data) => {
      io.to(data.toSocketId).emit('call_accepted', { from: userId, username, socketId: socket.id });
    });

    socket.on('call_reject', (data) => {
      io.to(data.toSocketId).emit('call_rejected', { from: userId });
    });

    socket.on('call_end', (data) => {
      if (data.toSocketId) {
        io.to(data.toSocketId).emit('call_ended', { from: userId });
      }
    });

    socket.on('webrtc_offer', (data) => {
      io.to(data.toSocketId).emit('webrtc_offer', { from: userId, offer: data.offer, socketId: socket.id });
    });

    socket.on('webrtc_answer', (data) => {
      io.to(data.toSocketId).emit('webrtc_answer', { from: userId, answer: data.answer, socketId: socket.id });
    });

    socket.on('webrtc_ice_candidate', (data) => {
      io.to(data.toSocketId).emit('webrtc_ice_candidate', { from: userId, candidate: data.candidate, socketId: socket.id });
    });
  });
}

module.exports = setupSocketHandlers;
