const request = require('supertest');
const app = require('../src/server');
const { db } = require('../config/database');

describe('Goals Endpoints', () => {
  let authToken;
  let testUserId;
  let testGoalId;

  beforeAll(async () => {
    // Create a test user and get auth token
    const userData = {
      email: 'test-goals@example.com',
      password: 'TestPassword123',
      first_name: 'Test',
      last_name: 'User'
    };

    const registerResponse = await request(app)
      .post('/api/auth/register')
      .send(userData);

    authToken = registerResponse.body.data.token;
    testUserId = registerResponse.body.data.user.id;
  });

  afterAll(async () => {
    // Clean up test data
    await db('goals').where('user_id', testUserId).del();
    await db('users').where('id', testUserId).del();
  });

  describe('POST /api/goals', () => {
    it('should create a new goal with valid data', async () => {
      const goalData = {
        name: 'New iPhone',
        description: 'Save for the latest iPhone',
        target_amount: 999.99,
        category: 'electronics',
        round_up_amount: 1.00,
        target_date: '2024-12-31',
        auto_purchase_enabled: false
      };

      const response = await request(app)
        .post('/api/goals')
        .set('Authorization', `Bearer ${authToken}`)
        .send(goalData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goal.name).toBe(goalData.name);
      expect(response.body.data.goal.target_amount).toBe(goalData.target_amount);
      expect(response.body.data.goal.category).toBe(goalData.category);
      expect(response.body.data.goal.progress_percentage).toBe(0);

      testGoalId = response.body.data.goal.id;
    });

    it('should return error for invalid target amount', async () => {
      const goalData = {
        name: 'Invalid Goal',
        target_amount: -100,
        category: 'electronics'
      };

      const response = await request(app)
        .post('/api/goals')
        .set('Authorization', `Bearer ${authToken}`)
        .send(goalData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Target amount must be greater than 0');
    });

    it('should return error for invalid category', async () => {
      const goalData = {
        name: 'Invalid Goal',
        target_amount: 100,
        category: 'invalid_category'
      };

      const response = await request(app)
        .post('/api/goals')
        .set('Authorization', `Bearer ${authToken}`)
        .send(goalData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });
  });

  describe('GET /api/goals', () => {
    it('should get all goals for user', async () => {
      const response = await request(app)
        .get('/api/goals')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goals).toBeInstanceOf(Array);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should filter goals by status', async () => {
      const response = await request(app)
        .get('/api/goals?status=active')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goals.every(goal => goal.is_active && !goal.is_completed)).toBe(true);
    });

    it('should filter goals by category', async () => {
      const response = await request(app)
        .get('/api/goals?category=electronics')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goals.every(goal => goal.category === 'electronics')).toBe(true);
    });
  });

  describe('GET /api/goals/:id', () => {
    it('should get a specific goal', async () => {
      const response = await request(app)
        .get(`/api/goals/${testGoalId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goal.id).toBe(testGoalId);
      expect(response.body.data.goal.name).toBe('New iPhone');
    });

    it('should return 404 for non-existent goal', async () => {
      const fakeId = '123e4567-e89b-12d3-a456-426614174000';
      
      const response = await request(app)
        .get(`/api/goals/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Goal not found');
    });
  });

  describe('PUT /api/goals/:id', () => {
    it('should update a goal', async () => {
      const updateData = {
        name: 'Updated iPhone Goal',
        description: 'Updated description',
        target_amount: 1099.99
      };

      const response = await request(app)
        .put(`/api/goals/${testGoalId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goal.name).toBe(updateData.name);
      expect(response.body.data.goal.description).toBe(updateData.description);
      expect(response.body.data.goal.target_amount).toBe(updateData.target_amount);
    });

    it('should return error for invalid update data', async () => {
      const updateData = {
        target_amount: -50
      };

      const response = await request(app)
        .put(`/api/goals/${testGoalId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Target amount must be greater than 0');
    });
  });

  describe('POST /api/goals/:id/contribute', () => {
    it('should add manual contribution to goal', async () => {
      const contributionData = {
        amount: 50.00,
        description: 'Manual contribution'
      };

      const response = await request(app)
        .post(`/api/goals/${testGoalId}/contribute`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(contributionData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.amount).toBe(contributionData.amount);
    });

    it('should return error for negative contribution amount', async () => {
      const contributionData = {
        amount: -10.00
      };

      const response = await request(app)
        .post(`/api/goals/${testGoalId}/contribute`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(contributionData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Contribution amount must be a positive number');
    });
  });

  describe('POST /api/goals/:id/toggle-status', () => {
    it('should pause a goal', async () => {
      const toggleData = {
        action: 'pause'
      };

      const response = await request(app)
        .post(`/api/goals/${testGoalId}/toggle-status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(toggleData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goal.is_active).toBe(false);
    });

    it('should resume a goal', async () => {
      const toggleData = {
        action: 'resume'
      };

      const response = await request(app)
        .post(`/api/goals/${testGoalId}/toggle-status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(toggleData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.goal.is_active).toBe(true);
    });

    it('should return error for invalid action', async () => {
      const toggleData = {
        action: 'invalid'
      };

      const response = await request(app)
        .post(`/api/goals/${testGoalId}/toggle-status`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(toggleData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Action must be either "pause" or "resume"');
    });
  });

  describe('GET /api/goals/stats', () => {
    it('should get goal statistics', async () => {
      const response = await request(app)
        .get('/api/goals/stats')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.stats).toBeDefined();
      expect(response.body.data.stats.total_goals).toBeGreaterThan(0);
      expect(response.body.data.category_breakdown).toBeInstanceOf(Array);
    });
  });

  describe('DELETE /api/goals/:id', () => {
    it('should delete a goal', async () => {
      const response = await request(app)
        .delete(`/api/goals/${testGoalId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Goal deleted successfully');
    });

    it('should return 404 for non-existent goal', async () => {
      const fakeId = '123e4567-e89b-12d3-a456-426614174000';
      
      const response = await request(app)
        .delete(`/api/goals/${fakeId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Goal not found');
    });
  });
}); 