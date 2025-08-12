const { validationResult } = require('express-validator');
const stripeService = require('../services/stripeService');
const logger = require('../utils/logger');

// Create Stripe customer
const createCustomer = async (req, res) => {
  try {
    const { user } = req;
    const { email, name } = req.body;

    const result = await stripeService.createCustomer(user.id, email, name);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created Stripe customer for user ${user.id}`);

    res.json({
      success: true,
      message: 'Customer created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating customer:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create customer'
    });
  }
};

// Create payment method
const createPaymentMethod = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { type, card, billing_details } = req.body;

    const result = await stripeService.createPaymentMethod(user.id, {
      type,
      card,
      billing_details
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created payment method for user ${user.id}`);

    res.json({
      success: true,
      message: 'Payment method created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating payment method:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create payment method'
    });
  }
};

// Set default payment method
const setDefaultPaymentMethod = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { payment_method_id } = req.body;

    const result = await stripeService.setDefaultPaymentMethod(user.id, payment_method_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Set default payment method for user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error setting default payment method:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to set default payment method'
    });
  }
};

// Get payment methods
const getPaymentMethods = async (req, res) => {
  try {
    const { user } = req;

    const result = await stripeService.getPaymentMethods(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved payment methods for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting payment methods:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve payment methods'
    });
  }
};

// Create payment intent for goal purchase
const createPaymentIntent = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { goal_id, amount, description } = req.body;

    const result = await stripeService.createPaymentIntent(user.id, goal_id, amount, description);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created payment intent for goal ${goal_id} by user ${user.id}`);

    res.json({
      success: true,
      message: 'Payment intent created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating payment intent:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create payment intent'
    });
  }
};

// Process automated purchase
const processAutomatedPurchase = async (req, res) => {
  try {
    const { user } = req;
    const { goal_id } = req.params;

    const result = await stripeService.processAutomatedPurchase(user.id, goal_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Processed automated purchase for goal ${goal_id} by user ${user.id}`);

    res.json({
      success: true,
      message: result.message,
      data: result.data
    });
  } catch (error) {
    logger.error('Error processing automated purchase:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process automated purchase'
    });
  }
};

// Get purchase history
const getPurchaseHistory = async (req, res) => {
  try {
    const { user } = req;
    const { limit = 20, offset = 0 } = req.query;

    const result = await stripeService.getPurchaseHistory(user.id, limit, offset);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved purchase history for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting purchase history:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve purchase history'
    });
  }
};

// Handle Stripe webhook
const handleWebhook = async (req, res) => {
  try {
    const sig = req.headers['stripe-signature'];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

    let event;

    try {
      event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      logger.error('Webhook signature verification failed:', err.message);
      return res.status(400).json({
        success: false,
        error: 'Webhook signature verification failed'
      });
    }

    const result = await stripeService.handleWebhook(event);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Processed webhook event: ${event.type}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error handling webhook:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process webhook'
    });
  }
};

// Get payment setup status
const getPaymentSetupStatus = async (req, res) => {
  try {
    const { user } = req;

    // Check if user has Stripe customer
    const userData = await db('users')
      .where('id', user.id)
      .select('stripe_customer_id')
      .first();

    // Check if user has payment methods
    const paymentMethods = await db('payment_methods')
      .where('user_id', user.id)
      .where('is_active', true)
      .count('* as count');

    const hasCustomer = !!userData.stripe_customer_id;
    const hasPaymentMethods = parseInt(paymentMethods[0].count) > 0;

    logger.info(`Retrieved payment setup status for user ${user.id}`);

    res.json({
      success: true,
      data: {
        has_customer: hasCustomer,
        has_payment_methods: hasPaymentMethods,
        is_setup_complete: hasCustomer && hasPaymentMethods
      }
    });
  } catch (error) {
    logger.error('Error getting payment setup status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve payment setup status'
    });
  }
};

// Remove payment method
const removePaymentMethod = async (req, res) => {
  try {
    const { user } = req;
    const { payment_method_id } = req.params;

    // Check if payment method belongs to user
    const paymentMethod = await db('payment_methods')
      .where('id', payment_method_id)
      .where('user_id', user.id)
      .first();

    if (!paymentMethod) {
      return res.status(404).json({
        success: false,
        error: 'Payment method not found'
      });
    }

    // Detach from Stripe
    try {
      await stripe.paymentMethods.detach(paymentMethod.stripe_payment_method_id);
    } catch (error) {
      logger.error('Error detaching payment method from Stripe:', error);
    }

    // Remove from database
    await db('payment_methods')
      .where('id', payment_method_id)
      .update({
        is_active: false,
        updated_at: db.fn.now()
      });

    logger.info(`Removed payment method ${payment_method_id} for user ${user.id}`);

    res.json({
      success: true,
      message: 'Payment method removed successfully'
    });
  } catch (error) {
    logger.error('Error removing payment method:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to remove payment method'
    });
  }
};

module.exports = {
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
}; 