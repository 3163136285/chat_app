const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const Database = require('../config/database');
const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const stickers = await Database.read('stickers');
    res.json({ stickers });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  try {
    const { url, name } = req.body;
    const sticker = { id: `sticker_${Date.now()}`, url, name, createdAt: Date.now() };
    await Database.insert('stickers', sticker);
    res.json({ sticker });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
