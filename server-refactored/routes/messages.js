const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const MessageService = require('../services/messageService');
const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const messages = await MessageService.getAll(page, limit);
    res.json({ messages });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/chat/:userId', authenticateToken, async (req, res) => {
  try {
    const otherId = req.params.userId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const messages = await MessageService.getChatBetween(req.user.id, otherId, page, limit);
    res.json({ messages });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/read', authenticateToken, async (req, res) => {
  try {
    const { messageId } = req.body;
    await MessageService.markRead(messageId);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
