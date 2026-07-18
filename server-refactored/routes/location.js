const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const LocationService = require('../services/locationService');
const UserService = require('../services/userService');
const router = express.Router();

router.post('/', authenticateToken, async (req, res) => {
  try {
    const { lat, lng } = req.body;
    await LocationService.record(req.user.id, lat, lng);
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/:userId', authenticateToken, async (req, res) => {
  try {
    const targetId = req.params.userId;
    const enabled = await UserService.getLocationSharing(targetId);
    if (!enabled) {
      return res.status(403).json({ error: '对方未开启位置共享' });
    }
    const locations = await LocationService.getHistory(targetId);
    res.json({ locations });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/sharing', authenticateToken, async (req, res) => {
  try {
    const { enabled } = req.body;
    const result = await UserService.updateLocationSharing(req.user.id, enabled);
    res.json({ enabled: result });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/sharing/:userId', authenticateToken, async (req, res) => {
  try {
    const enabled = await UserService.getLocationSharing(req.params.userId);
    res.json({ enabled });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
