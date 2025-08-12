const request = require('supertest');
const app = require('../src/server');

describe('Social Endpoints', () => {
  let authToken1, authToken2;
  let user1Id, user2Id;
  let friendRequestId;
  let groupGoalId;

  beforeAll(async () => {
    // Create test users
    const user1Data = {
      email: 'test-social1@example.com',
      password: 'TestPassword123',
      first_name: 'Test',
      last_name: 'User1'
    };

    const user2Data = {
      email: 'test-social2@example.com',
      password: 'TestPassword123',
      first_name: 'Test',
      last_name: 'User2'
    };

    const registerResponse1 = await request(app)
      .post('/api/auth/register')
      .send(user1Data);

    const registerResponse2 = await request(app)
      .post('/api/auth/register')
      .send(user2Data);

    authToken1 = registerResponse1.body.data.token;
    authToken2 = registerResponse2.body.data.token;
    user1Id = registerResponse1.body.data.user.id;
    user2Id = registerResponse2.body.data.user.id;
  });

  describe('Friend Management', () => {
    it('should send friend request', async () => {
      const requestData = {
        to_user_id: user2Id,
        message: 'Hey, let\'s be friends!'
      };

      const response = await request(app)
        .post('/api/social/friends/request')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(requestData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Friend request sent successfully');
      expect(response.body.data.request).toBeDefined();
      expect(response.body.data.to_user.id).toBe(user2Id);
    });

    it('should get friend requests', async () => {
      const response = await request(app)
        .get('/api/social/friends/requests')
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.requests).toBeInstanceOf(Array);
      expect(response.body.data.requests.length).toBeGreaterThan(0);

      friendRequestId = response.body.data.requests[0].id;
    });

    it('should accept friend request', async () => {
      const response = await request(app)
        .post(`/api/social/friends/requests/${friendRequestId}/accept`)
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Friend request accepted');
    });

    it('should get friends list', async () => {
      const response = await request(app)
        .get('/api/social/friends')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.friends).toBeInstanceOf(Array);
      expect(response.body.data.friends.length).toBeGreaterThan(0);
    });

    it('should search users', async () => {
      const response = await request(app)
        .get('/api/social/users/search?q=test')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.users).toBeInstanceOf(Array);
    });

    it('should get friend suggestions', async () => {
      const response = await request(app)
        .get('/api/social/users/suggestions')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.suggestions).toBeInstanceOf(Array);
    });
  });

  describe('Group Goals', () => {
    it('should create a group goal', async () => {
      const groupGoalData = {
        name: 'Group Vacation Fund',
        description: 'Saving for a group vacation to Hawaii',
        target_amount: 5000.00,
        category: 'travel',
        max_participants: 5,
        is_public: true
      };

      const response = await request(app)
        .post('/api/social/group-goals')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(groupGoalData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Group goal created successfully');
      expect(response.body.data.group_goal.invite_code).toBeDefined();
    });

    it('should get user group goals', async () => {
      const response = await request(app)
        .get('/api/social/group-goals')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.group_goals).toBeInstanceOf(Array);
      expect(response.body.data.group_goals.length).toBeGreaterThan(0);

      groupGoalId = response.body.data.group_goals[0].id;
    });

    it('should get group goal details', async () => {
      const response = await request(app)
        .get(`/api/social/group-goals/${groupGoalId}`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.group_goal).toBeDefined();
      expect(response.body.data.participants).toBeInstanceOf(Array);
    });

    it('should contribute to group goal', async () => {
      const contributionData = {
        amount: 100.00,
        message: 'First contribution!',
        is_anonymous: false
      };

      const response = await request(app)
        .post(`/api/social/group-goals/${groupGoalId}/contribute`)
        .set('Authorization', `Bearer ${authToken1}`)
        .send(contributionData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe('Contribution added successfully');
      expect(response.body.data.amount).toBe(contributionData.amount);
    });

    it('should get group goal contributions', async () => {
      const response = await request(app)
        .get(`/api/social/group-goals/${groupGoalId}/contributions`)
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.contributions).toBeInstanceOf(Array);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should search public group goals', async () => {
      const response = await request(app)
        .get('/api/social/group-goals/search?q=vacation')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.group_goals).toBeInstanceOf(Array);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should get group goal statistics', async () => {
      const response = await request(app)
        .get('/api/social/group-goals/stats')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toBeDefined();
      expect(response.body.data.active_groups).toBeGreaterThanOrEqual(0);
      expect(response.body.data.completed_groups).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Social Feed', () => {
    it('should get social feed', async () => {
      const response = await request(app)
        .get('/api/social/feed')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.activities).toBeInstanceOf(Array);
      expect(response.body.data.pagination).toBeDefined();
    });

    it('should get user social statistics', async () => {
      const response = await request(app)
        .get('/api/social/stats')
        .set('Authorization', `Bearer ${authToken1}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toBeDefined();
      expect(response.body.data.friends_count).toBeGreaterThanOrEqual(0);
      expect(response.body.data.pending_requests_count).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Error Handling', () => {
    it('should return error for invalid friend request', async () => {
      const invalidData = {
        to_user_id: 'invalid-uuid'
      };

      const response = await request(app)
        .post('/api/social/friends/request')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return error for invalid group goal creation', async () => {
      const invalidData = {
        name: '',
        target_amount: -100
      };

      const response = await request(app)
        .post('/api/social/group-goals')
        .set('Authorization', `Bearer ${authToken1}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Validation failed');
    });

    it('should return error for invalid contribution', async () => {
      const invalidData = {
        amount: -50
      };

      const response = await request(app)
        .post(`/api/social/group-goals/${groupGoalId}/contribute`)
        .set('Authorization', `Bearer ${authToken1}`)
        .send(invalidData)
        .expect(400);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Contribution amount must be a positive number');
    });
  });
}); 