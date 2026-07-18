const express = require('express');
const UserService = require('../services/userService');
const router = express.Router();

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    const user = await UserService.findByUsername(username);
    if (!user || !(await UserService.validatePassword(user, password))) {
      return res.status(401).json({ error: '用户名或密码错误' });
    }
    const token = UserService.generateToken(user);
    res.json({ token, user: { id: user.id, username: user.username, displayName: user.displayName } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
