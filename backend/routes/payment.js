const express = require('express');
const { body, param, query } = require('express-validator');
const {
  createCustomer,
  createPaymentMethod,
  setDefaultPaymentMethod,
  getPaymentMethods,
  createPaymentIntent,
  processAutomatedPurchase,
  getPurchaseHistory,
  handleWebhook,
  getPaymentSetupStatus,
  removePaymentMethod
} = require('../controllers/paymentController');

const router = express.Router();

// Validation middleware
const createCustomerValidation = [
  body('email')
    .isEmail()
    .withMessage('Valid email is required'),
  body('name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Name is required and must be less than 100 characters')
];

const createPaymentMethodValidation = [
  body('type')
    .isIn(['card'])
    .withMessage('Payment method type must be "card"'),
  body('card')
    .isObject()
    .withMessage('Card details are required'),
  body('card.number')
    .isCreditCard()
    .withMessage('Valid card number is required'),
  body('card.exp_month')
    .isInt({ min: 1, max: 12 })
    .withMessage('Valid expiration month is required'),
  body('card.exp_year')
    .isInt({ min: new Date().getFullYear() })
    .withMessage('Valid expiration year is required'),
  body('card.cvc')
    .isLength({ min: 3, max: 4 })
    .withMessage('Valid CVC is required'),
  body('billing_details')
    .optional()
    .isObject()
    .withMessage('Billing details must be an object'),
  body('billing_details.name')
    .optional()
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Billing name must be less than 100 characters'),
  body('billing_details.email')
    .optional()
    .isEmail()
    .withMessage('Valid billing email is required')
];

const setDefaultPaymentMethodValidation = [
  body('payment_method_id')
    .isUUID()
    .withMessage('Valid payment method ID is required')
];

const createPaymentIntentValidation = [
  body('goal_id')
    .isUUID()
    .withMessage('Valid goal ID is required'),
  body('amount')
    .isFloat({ min: 0.01 })
    .withMessage('Amount must be a positive number'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Description must be less than 200 characters')
];

const goalIdValidation = [
  param('goal_id')
    .isUUID()
    .withMessage('Valid goal ID is required')
];

const paymentMethodIdValidation = [
  param('payment_method_id')
    .isUUID()
    .withMessage('Valid payment method ID is required')
];

const getPurchaseHistoryValidation = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer')
];

// Payment setup routes
router.post('/customer', createCustomerValidation, createCustomer);
router.post('/payment-methods', createPaymentMethodValidation, createPaymentMethod);
router.post('/payment-methods/default', setDefaultPaymentMethodValidation, setDefaultPaymentMethod);
router.get('/payment-methods', getPaymentMethods);
router.delete('/payment-methods/:payment_method_id', paymentMethodIdValidation, removePaymentMethod);
router.get('/setup-status', getPaymentSetupStatus);

// Payment processing routes
router.post('/payment-intent', createPaymentIntentValidation, createPaymentIntent);
router.post('/goals/:goal_id/automated-purchase', goalIdValidation, processAutomatedPurchase);
router.get('/purchases', getPurchaseHistoryValidation, getPurchaseHistory);

// Webhook route (no auth required)
router.post('/webhook', handleWebhook);

module.exports = router; 