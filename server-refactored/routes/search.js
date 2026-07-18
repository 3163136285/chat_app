const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const MessageService = require('../services/messageService');
const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const keyword = req.query.q || '';
    if (!keyword) {
      return res.json({ messages: [] });
    }
    const messages = await MessageService.search(keyword);
    res.json({ messages });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
