const express = require('express');
const { body, validationResult } = require('express-validator');

const router = express.Router();

router.get('/profile', async (req, res) => {
  try {
    res.json({
      success: true,
      data: {
        id: req.userId || 'demo-user-id',
        email: 'user@example.com',
        firstName: 'John',
        lastName: 'Doe',
        phone: '+1234567890',
        isPremium: false,
        createdAt: new Date().toISOString()
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to get user profile',
        code: 'PROFILE_FETCH_ERROR'
      }
    });
  }
});

router.put('/profile', [
  body('firstName').optional().trim().isLength({ min: 1 }),
  body('lastName').optional().trim().isLength({ min: 1 }),
  body('phone').optional().isMobilePhone(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array()
        }
      });
    }

    res.json({
      success: true,
      data: {
        id: req.userId || 'demo-user-id',
        ...req.body,
        updatedAt: new Date().toISOString()
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to update profile',
        code: 'PROFILE_UPDATE_ERROR'
      }
    });
  }
});

module.exports = router;
