const express = require('express');
const { body, param, query } = require('express-validator');
const {
  getGoals,
  getGoal,
  createGoal,
  updateGoal,
  deleteGoal,
  toggleGoalStatus,
  contributeToGoal,
  getGoalStats
} = require('../controllers/goalsController');

const router = express.Router();

// Validation middleware
const createGoalValidation = [
  body('name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Goal name is required and must be less than 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description must be less than 500 characters'),
  body('target_amount')
    .isFloat({ min: 0.01 })
    .withMessage('Target amount must be a positive number'),
  body('category')
    .isIn(['fashion', 'electronics', 'travel', 'entertainment', 'food', 'custom'])
    .withMessage('Category must be one of: fashion, electronics, travel, entertainment, food, custom'),
  body('image_url')
    .optional()
    .isURL()
    .withMessage('Image URL must be a valid URL'),
  body('product_url')
    .optional()
    .isURL()
    .withMessage('Product URL must be a valid URL'),
  body('round_up_amount')
    .optional()
    .isFloat({ min: 0.50, max: 10.00 })
    .withMessage('Round-up amount must be between $0.50 and $10.00'),
  body('target_date')
    .optional()
    .isISO8601()
    .withMessage('Target date must be a valid date'),
  body('auto_purchase_enabled')
    .optional()
    .isBoolean()
    .withMessage('Auto purchase enabled must be a boolean')
];

const updateGoalValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid goal ID'),
  body('name')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Goal name must be less than 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description must be less than 500 characters'),
  body('target_amount')
    .optional()
    .isFloat({ min: 0.01 })
    .withMessage('Target amount must be a positive number'),
  body('category')
    .optional()
    .isIn(['fashion', 'electronics', 'travel', 'entertainment', 'food', 'custom'])
    .withMessage('Category must be one of: fashion, electronics, travel, entertainment, food, custom'),
  body('image_url')
    .optional()
    .isURL()
    .withMessage('Image URL must be a valid URL'),
  body('product_url')
    .optional()
    .isURL()
    .withMessage('Product URL must be a valid URL'),
  body('round_up_amount')
    .optional()
    .isFloat({ min: 0.50, max: 10.00 })
    .withMessage('Round-up amount must be between $0.50 and $10.00'),
  body('target_date')
    .optional()
    .isISO8601()
    .withMessage('Target date must be a valid date'),
  body('auto_purchase_enabled')
    .optional()
    .isBoolean()
    .withMessage('Auto purchase enabled must be a boolean')
];

const goalIdValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid goal ID')
];

const contributeValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid goal ID'),
  body('amount')
    .isFloat({ min: 0.01 })
    .withMessage('Contribution amount must be a positive number'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Description must be less than 200 characters')
];

const toggleStatusValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid goal ID'),
  body('action')
    .isIn(['pause', 'resume'])
    .withMessage('Action must be either "pause" or "resume"')
];

const queryValidation = [
  query('status')
    .optional()
    .isIn(['active', 'completed', 'paused'])
    .withMessage('Status must be one of: active, completed, paused'),
  query('category')
    .optional()
    .isIn(['fashion', 'electronics', 'travel', 'entertainment', 'food', 'custom'])
    .withMessage('Category must be one of: fashion, electronics, travel, entertainment, food, custom'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer')
];

// Routes
router.get('/', queryValidation, getGoals);
router.get('/stats', getGoalStats);
router.get('/:id', goalIdValidation, getGoal);
router.post('/', createGoalValidation, createGoal);
router.put('/:id', updateGoalValidation, updateGoal);
router.delete('/:id', goalIdValidation, deleteGoal);
router.post('/:id/toggle-status', toggleStatusValidation, toggleGoalStatus);
router.post('/:id/contribute', contributeValidation, contributeToGoal);

module.exports = router; 