const request = require('supertest');
const app = require('../src/server');

describe('Payment Endpoints', () => {
  let authToken;
  let testUserId;
  let testGoalId;
  let paymentMethodId;

  beforeAll(async () => {
    // Create a test user and get auth token
    const userData = {
      email: 'test-payment@example.com',
      password: 'TestPassword123',
      first_name: 'Test',
      last_name: 'User'
    };

    const registerResponse = await request(app)
      .post('/api/auth/register')
      .send(userData);

    authToken = registerResponse.body.data.token;
    testUserId = registerResponse.body.data.user.id;

    // Create a test goal
    const goalData = {
      name: 'Test Goal for Payment',
      description: 'Testing payment integration',
      target_amount: 100.00,
      category: 'electronics',
      auto_purchase_enabled: true
    };

    const goalResponse = await request(app)
      .post('/api/goals')
      .set('Authorization', `Bearer ${authToken}`)
      .send(goalData);

    testGoalId = goalResponse.body.data.goal.id;
  });

  describe('Payment Setup', () => {
    it('should create Stripe customer', async () => {
      const customerData = {
        email: 'test-payment@example.com',
        name: 'Test User'
      };

      const response = await request(app)
        .post('/api/payment/customer')
        .set('Authorization', `Bearer ${authToken}`)
        .send(customerData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Customer created successfully');
      expect(response.body.data.customer_id).toBeDefined();
    });

    it('should get payment setup status', async () => {
      const response = await request(app)
        .get('/api/payment/setup-status')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toBeDefined();
      expect(response.body.data.has_customer).toBe(true);
      expect(response.body.data.has_payment_methods).toBe(false);
      expect(response.body.data.is_setup_complete).toBe(false);
    });

    it('should create payment method', async () => {
      const paymentMethodData = {
        type: 'card',
        card: {
          number: '4242424242424242', // Test card number
          exp_month: 12,
          exp_year: 2025,
          cvc: '123'
        },
        billing_details: {
          name: 'Test User',
          email: 'test-payment@example.com'
        }
      };

      const response = await request(app)
        .post('/api/payment/payment-methods')
        .set('Authorization', `Bearer ${authToken}`)
        .send(paymentMethodData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Payment method created successfully');
      expect(response.body.data.payment_method_id).toBeDefined();

      paymentMethodId = response.body.data.payment_method_id;
    });

    it('should get payment methods', async () => {
      const response = await request(app)
        .get('/api/payment/payment-methods')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.payment_methods).toBeInstanceOf(Array);
      expect(response.body.data.payment_methods.length).toBeGreaterThan(0);
    });

    it('should set default payment method', async () => {
      const response = await request(app)
        .post('/api/payment/payment-methods/default')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ payment_method_id: paymentMethodId })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Default payment method updated');
    });

    it('should update setup status after payment method', async () => {
      const response = await request(app)
        .get('/api/payment/setup-status')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.has_payment_methods).toBe(true);
      expect(response.body.data.is_setup_complete).toBe(true);
    });
  });

  describe('Payment Processing', () => {
    it('should create payment intent', async () => {
      const paymentIntentData = {
        goal_id: testGoalId,
        amount: 50.00,
        description: 'Test payment for goal'
      };

      const response = await request(app)
        .post('/api/payment/payment-intent')
        .set('Authorization', `Bearer ${authToken}`)
        .send(paymentIntentData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Payment intent created successfully');
      expect(response.body.data.payment_intent_id).toBeDefined();
      expect(response.body.data.status).toBeDefined();
    });

    it('should return error for invalid goal ID', async () => {
      const paymentIntentData = {
        goal_id: 'invalid-uuid',
        amount: 50.00
      };

      const response = await request(app)
        .post('/api/payment/payment-intent')
        .set('Authorization', `Bearer ${authToken}`)
        .send(paymentIntentData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return error for negative amount', async () => {
      const paymentIntentData = {
        goal_id: testGoalId,
        amount: -50.00
      };

      const response = await request(app)
        .post('/api/payment/payment-intent')
        .set('Authorization', `Bearer ${authToken}`)
        .send(paymentIntentData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('Purchase History', () => {
    it('should get purchase history', async () => {
      const response = await request(app)
        .get('/api/payment/purchases')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.purchases).toBeInstanceOf(Array);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should get purchase history with pagination', async () => {
      const response = await request(app)
        .get('/api/payment/purchases?limit=10&offset=0')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.purchases).toBeInstanceOf(Array);
      expect(response.body.data.pagination.limit).toBe(10);
      expect(response.body.data.pagination.offset).toBe(0);
    });
  });

  describe('Automated Purchases', () => {
    it('should process automated purchase for completed goal', async () => {
      // First, complete the goal by adding contribution
      const contributionData = {
        amount: 100.00,
        description: 'Complete goal for automated purchase test'
      };

      await request(app)
        .post(`/api/goals/${testGoalId}/contribute`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(contributionData)
        .expect(200);

      // Now test automated purchase
      const response = await request(app)
        .post(`/api/payment/goals/${testGoalId}/automated-purchase`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Automated purchase processed successfully');
      expect(response.body.data).toBeDefined();
    });

    it('should return error for non-existent goal', async () => {
      const fakeGoalId = '123e4567-e89b-12d3-a456-426614174000';

      const response = await request(app)
        .post(`/api/payment/goals/${fakeGoalId}/automated-purchase`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Goal not found or auto-purchase not enabled');
    });
  });

  describe('Payment Method Management', () => {
    it('should remove payment method', async () => {
      const response = await request(app)
        .delete(`/api/payment/payment-methods/${paymentMethodId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Payment method removed successfully');
    });

    it('should return error for non-existent payment method', async () => {
      const fakePaymentMethodId = '123e4567-e89b-12d3-a456-426614174000';

      const response = await request(app)
        .delete(`/api/payment/payment-methods/${fakePaymentMethodId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Payment method not found');
    });
  });

  describe('Error Handling', () => {
    it('should return error for invalid customer data', async () => {
      const invalidData = {
        email: 'invalid-email',
        name: ''
      };

      const response = await request(app)
        .post('/api/payment/customer')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return error for invalid payment method data', async () => {
      const invalidData = {
        type: 'invalid_type',
        card: {
          number: '123',
          exp_month: 13,
          exp_year: 2020,
          cvc: '12'
        }
      };

      const response = await request(app)
        .post('/api/payment/payment-methods')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return error for invalid payment intent data', async () => {
      const invalidData = {
        goal_id: 'invalid-uuid',
        amount: -10
      };

      const response = await request(app)
        .post('/api/payment/payment-intent')
        .set('Authorization', `Bearer ${authToken}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('Webhook Handling', () => {
    it('should handle webhook events', async () => {
      const webhookData = {
        id: 'evt_test',
        type: 'payment_intent.succeeded',
        data: {
          object: {
            id: 'pi_test',
            status: 'succeeded'
          }
        }
      };

      const response = await request(app)
        .post('/api/payment/webhook')
        .set('stripe-signature', 'test_signature')
        .send(webhookData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Webhook processed successfully');
    });
  });
}); 