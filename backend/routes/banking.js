const express = require('express');
const { body, param, query } = require('express-validator');
const {
  createLinkToken,
  exchangePublicToken,
  getAccounts,
  setPrimaryAccount,
  removeAccount,
  getBalance,
  syncTransactions,
  getTransactions
} = require('../controllers/bankingController');

const router = express.Router();

// Validation middleware
const exchangeTokenValidation = [
  body('public_token')
    .notEmpty()
    .withMessage('Public token is required'),
  body('institution_name')
    .optional()
    .trim()
    .isLength({ max: 100 })
    .withMessage('Institution name must be less than 100 characters')
];

const setPrimaryAccountValidation = [
  body('account_id')
    .notEmpty()
    .withMessage('Account ID is required')
];

const removeAccountValidation = [
  param('account_id')
    .notEmpty()
    .withMessage('Account ID is required')
];

const getTransactionsValidation = [
  query('start_date')
    .notEmpty()
    .withMessage('Start date is required')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('Start date must be in YYYY-MM-DD format'),
  query('end_date')
    .notEmpty()
    .withMessage('End date is required')
    .matches(/^\d{4}-\d{2}-\d{2}$/)
    .withMessage('End date must be in YYYY-MM-DD format'),
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
router.post('/link-token', createLinkToken);
router.post('/connect', exchangeTokenValidation, exchangePublicToken);
router.get('/accounts', getAccounts);
router.post('/set-primary', setPrimaryAccountValidation, setPrimaryAccount);
router.delete('/accounts/:account_id', removeAccountValidation, removeAccount);
router.get('/balance', getBalance);
router.post('/sync', syncTransactions);
router.get('/transactions', getTransactionsValidation, getTransactions);

module.exports = router; 