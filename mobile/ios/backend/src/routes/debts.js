const express = require('express');
const router = express.Router();

router.get('/', async (req, res) => {
  res.json({
    success: true,
    data: {
      debts: [],
      pagination: { page: 1, limit: 10, total: 0, totalPages: 0 }
    }
  });
});

module.exports = router;
