const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const { db } = require('../config/database');
const logger = require('../utils/logger');

// Create a customer
const createCustomer = async (userId, email, name) => {
  try {
    const customer = await stripe.customers.create({
      email,
      name,
      metadata: {
        user_id: userId
      }
    });

    // Store customer ID in database
    await db('users')
      .where('id', userId)
      .update({
        stripe_customer_id: customer.id,
        updated_at: db.fn.now()
      });

    logger.info(`Created Stripe customer for user ${userId}`);

    return {
      success: true,
      data: {
        customer_id: customer.id
      }
    };
  } catch (error) {
    logger.error('Error creating Stripe customer:', error);
    return {
      success: false,
      error: 'Failed to create customer'
    };
  }
};

// Create a payment method
const createPaymentMethod = async (userId, paymentMethodData) => {
  try {
    const { type, card, billing_details } = paymentMethodData;

    const paymentMethod = await stripe.paymentMethods.create({
      type,
      card,
      billing_details
    });

    // Attach to customer
    const user = await db('users')
      .where('id', userId)
      .select('stripe_customer_id')
      .first();

    if (user.stripe_customer_id) {
      await stripe.paymentMethods.attach(paymentMethod.id, {
        customer: user.stripe_customer_id,
      });
    }

    // Store payment method in database
    await db('payment_methods').insert({
      user_id: userId,
      stripe_payment_method_id: paymentMethod.id,
      type: paymentMethod.type,
      last4: paymentMethod.card?.last4,
      brand: paymentMethod.card?.brand,
      exp_month: paymentMethod.card?.exp_month,
      exp_year: paymentMethod.card?.exp_year,
      is_default: false
    });

    logger.info(`Created payment method for user ${userId}`);

    return {
      success: true,
      data: {
        payment_method_id: paymentMethod.id
      }
    };
  } catch (error) {
    logger.error('Error creating payment method:', error);
    return {
      success: false,
      error: 'Failed to create payment method'
    };
  }
};

// Set default payment method
const setDefaultPaymentMethod = async (userId, paymentMethodId) => {
  try {
    const user = await db('users')
      .where('id', userId)
      .select('stripe_customer_id')
      .first();

    if (!user.stripe_customer_id) {
      return {
        success: false,
        error: 'No Stripe customer found'
      };
    }

    // Update customer's default payment method
    await stripe.customers.update(user.stripe_customer_id, {
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
    });

    // Update database
    await db('payment_methods')
      .where('user_id', userId)
      .update({ is_default: false });

    await db('payment_methods')
      .where('user_id', userId)
      .where('stripe_payment_method_id', paymentMethodId)
      .update({ is_default: true });

    logger.info(`Set default payment method for user ${userId}`);

    return {
      success: true,
      message: 'Default payment method updated'
    };
  } catch (error) {
    logger.error('Error setting default payment method:', error);
    return {
      success: false,
      error: 'Failed to set default payment method'
    };
  }
};

// Get user's payment methods
const getPaymentMethods = async (userId) => {
  try {
    const paymentMethods = await db('payment_methods')
      .where('user_id', userId)
      .select('*')
      .orderBy('is_default', 'desc')
      .orderBy('created_at', 'desc');

    return {
      success: true,
      data: {
        payment_methods: paymentMethods
      }
    };
  } catch (error) {
    logger.error('Error getting payment methods:', error);
    return {
      success: false,
      error: 'Failed to retrieve payment methods'
    };
  }
};

// Create a payment intent for goal purchase
const createPaymentIntent = async (userId, goalId, amount, description) => {
  try {
    const user = await db('users')
      .where('id', userId)
      .select('stripe_customer_id')
      .first();

    const goal = await db('goals')
      .where('id', goalId)
      .where('user_id', userId)
      .first();

    if (!goal) {
      return {
        success: false,
        error: 'Goal not found'
      };
    }

    if (!user.stripe_customer_id) {
      return {
        success: false,
        error: 'No payment method configured'
      };
    }

    // Get default payment method
    const defaultPaymentMethod = await db('payment_methods')
      .where('user_id', userId)
      .where('is_default', true)
      .first();

    if (!defaultPaymentMethod) {
      return {
        success: false,
        error: 'No default payment method found'
      };
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency: 'usd',
      customer: user.stripe_customer_id,
      payment_method: defaultPaymentMethod.stripe_payment_method_id,
      description: description || `Purchase for goal: ${goal.name}`,
      metadata: {
        user_id: userId,
        goal_id: goalId,
        goal_name: goal.name
      },
      confirm: true,
      return_url: `${process.env.FRONTEND_URL}/goals/${goalId}/purchase-success`
    });

    // Store payment intent in database
    await db('purchases').insert({
      user_id: userId,
      goal_id: goalId,
      stripe_payment_intent_id: paymentIntent.id,
      amount,
      status: paymentIntent.status,
      description: description || `Purchase for goal: ${goal.name}`,
      metadata: {
        goal_name: goal.name,
        goal_category: goal.category
      }
    });

    logger.info(`Created payment intent for goal ${goalId}, amount: $${amount}`);

    return {
      success: true,
      data: {
        payment_intent_id: paymentIntent.id,
        status: paymentIntent.status,
        client_secret: paymentIntent.client_secret
      }
    };
  } catch (error) {
    logger.error('Error creating payment intent:', error);
    return {
      success: false,
      error: 'Failed to create payment intent'
    };
  }
};

// Process automated purchase when goal is completed
const processAutomatedPurchase = async (userId, goalId) => {
  try {
    const goal = await db('goals')
      .where('id', goalId)
      .where('user_id', userId)
      .where('is_completed', true)
      .where('auto_purchase_enabled', true)
      .first();

    if (!goal) {
      return {
        success: false,
        error: 'Goal not found or auto-purchase not enabled'
      };
    }

    // Check if purchase already exists
    const existingPurchase = await db('purchases')
      .where('goal_id', goalId)
      .where('status', 'succeeded')
      .first();

    if (existingPurchase) {
      return {
        success: false,
        error: 'Purchase already completed for this goal'
      };
    }

    // Create payment intent
    const result = await createPaymentIntent(
      userId,
      goalId,
      goal.target_amount,
      `Automated purchase for goal: ${goal.name}`
    );

    if (!result.success) {
      return result;
    }

    // Update goal status
    await db('goals')
      .where('id', goalId)
      .update({
        purchase_completed: true,
        purchase_completed_at: db.fn.now()
      });

    logger.info(`Automated purchase processed for goal ${goalId}`);

    return {
      success: true,
      message: 'Automated purchase processed successfully',
      data: result.data
    };
  } catch (error) {
    logger.error('Error processing automated purchase:', error);
    return {
      success: false,
      error: 'Failed to process automated purchase'
    };
  }
};

// Get purchase history
const getPurchaseHistory = async (userId, limit = 20, offset = 0) => {
  try {
    const purchases = await db('purchases')
      .join('goals', 'purchases.goal_id', 'goals.id')
      .where('purchases.user_id', userId)
      .select(
        'purchases.*',
        'goals.name as goal_name',
        'goals.category as goal_category'
      )
      .orderBy('purchases.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Get total count
    const [{ count }] = await db('purchases')
      .where('user_id', userId)
      .count('* as count');

    return {
      success: true,
      data: {
        purchases,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + purchases.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error getting purchase history:', error);
    return {
      success: false,
      error: 'Failed to retrieve purchase history'
    };
  }
};

// Handle webhook events
const handleWebhook = async (event) => {
  try {
    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object);
        break;
      case 'payment_intent.payment_failed':
        await handlePaymentFailure(event.data.object);
        break;
      case 'payment_method.attached':
        await handlePaymentMethodAttached(event.data.object);
        break;
      default:
        logger.info(`Unhandled webhook event: ${event.type}`);
    }

    return {
      success: true,
      message: 'Webhook processed successfully'
    };
  } catch (error) {
    logger.error('Error handling webhook:', error);
    return {
      success: false,
      error: 'Failed to process webhook'
    };
  }
};

// Handle successful payment
const handlePaymentSuccess = async (paymentIntent) => {
  try {
    await db('purchases')
      .where('stripe_payment_intent_id', paymentIntent.id)
      .update({
        status: 'succeeded',
        updated_at: db.fn.now()
      });

    logger.info(`Payment succeeded for intent: ${paymentIntent.id}`);
  } catch (error) {
    logger.error('Error handling payment success:', error);
  }
};

// Handle failed payment
const handlePaymentFailure = async (paymentIntent) => {
  try {
    await db('purchases')
      .where('stripe_payment_intent_id', paymentIntent.id)
      .update({
        status: 'failed',
        updated_at: db.fn.now()
      });

    logger.info(`Payment failed for intent: ${paymentIntent.id}`);
  } catch (error) {
    logger.error('Error handling payment failure:', error);
  }
};

// Handle payment method attached
const handlePaymentMethodAttached = async (paymentMethod) => {
  try {
    logger.info(`Payment method attached: ${paymentMethod.id}`);
  } catch (error) {
    logger.error('Error handling payment method attached:', error);
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
  handleWebhook
}; 