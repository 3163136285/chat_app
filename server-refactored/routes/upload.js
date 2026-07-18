const express = require('express');
const multer = require('multer');
const { authenticateToken } = require('../middleware/auth');
const ossClient = require('../config/oss');
const router = express.Router();

const upload = multer({ dest: 'uploads/' });

router.post('/', authenticateToken, upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '未上传文件' });
    }
    const fileName = `chat/${Date.now()}_${req.file.originalname}`;
    const result = await ossClient.put(fileName, req.file.path);
    res.json({ url: result.url });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
