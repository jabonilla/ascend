const express = require('express');
const { body, param, query } = require('express-validator');
const {
  getTransactions,
  getTransaction,
  processTransactionRoundUps,
  processBatchRoundUps,
  getTransactionStats,
  getRoundUpStats,
  getGoalRoundUps
} = require('../controllers/transactionsController');

const router = express.Router();

// Validation middleware
const transactionIdValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid transaction ID')
];

const processRoundUpsValidation = [
  param('transaction_id')
    .isUUID()
    .withMessage('Invalid transaction ID')
];

const batchRoundUpsValidation = [
  body('transaction_ids')
    .isArray({ min: 1 })
    .withMessage('Transaction IDs must be a non-empty array'),
  body('transaction_ids.*')
    .isUUID()
    .withMessage('Each transaction ID must be a valid UUID')
];

const getTransactionsValidation = [
  query('start_date')
    .optional()
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('Start date must be in YYYY-MM-DD format'),
  query('end_date')
    .optional()
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('End date must be in YYYY-MM-DD format'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer'),
  query('min_amount')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Min amount must be a positive number'),
  query('max_amount')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Max amount must be a positive number')
];

const getStatsValidation = [
  query('start_date')
    .optional()
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('Start date must be in YYYY-MM-DD format'),
  query('end_date')
    .optional()
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('End date must be in YYYY-MM-DD format')
];

const goalRoundUpsValidation = [
  param('goal_id')
    .isUUID()
    .withMessage('Invalid goal ID'),
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
router.get('/', getTransactionsValidation, getTransactions);
router.get('/stats', getStatsValidation, getTransactionStats);
router.get('/roundups/stats', getStatsValidation, getRoundUpStats);
router.get('/:id', transactionIdValidation, getTransaction);
router.post('/:transaction_id/process-roundups', processRoundUpsValidation, processTransactionRoundUps);
router.post('/process-batch-roundups', batchRoundUpsValidation, processBatchRoundUps);
router.get('/goals/:goal_id/roundups', goalRoundUpsValidation, getGoalRoundUps);

module.exports = router; 