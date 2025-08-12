const request = require('supertest');
const app = require('../src/server');
const { db } = require('../src/config/database');

describe('Notification System', () => {
  let testUser, testUser2, authToken, authToken2;
  let testNotificationId;

  beforeAll(async () => {
    // Create test users
    const userResponse = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'notificationtest@example.com',
        password: 'TestPassword123!',
        first_name: 'Notification',
        last_name: 'Test'
      });

    testUser = userResponse.body.data.user;
    authToken = userResponse.body.data.token;

    const userResponse2 = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'notificationtest2@example.com',
        password: 'TestPassword123!',
        first_name: 'Notification2',
        last_name: 'Test'
      });

    testUser2 = userResponse2.body.data.user;
    authToken2 = userResponse2.body.data.token;
  });

  afterAll(async () => {
    // Clean up test data
    await db('notifications').where('user_id', testUser.id).del();
    await db('notifications').where('user_id', testUser2.id).del();
    await db('users').where('id', testUser.id).del();
    await db('users').where('id', testUser2.id).del();
  });

  describe('GET /api/notifications', () => {
    it('should get user notifications', async () => {
      const response = await request(app)
        .get('/api/notifications')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('notifications');
      expect(response.body.data).toHaveProperty('pagination');
    });

    it('should get notifications with status filter', async () => {
      const response = await request(app)
        .get('/api/notifications?status=unread')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    it('should get notifications with pagination', async () => {
      const response = await request(app)
        .get('/api/notifications?limit=10&offset=0')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.pagination.limit).toBe(10);
    });
  });

  describe('GET /api/notifications/stats', () => {
    it('should get notification statistics', async () => {
      const response = await request(app)
        .get('/api/notifications/stats')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('total_notifications');
      expect(response.body.data).toHaveProperty('unread_notifications');
      expect(response.body.data).toHaveProperty('today_notifications');
    });
  });

  describe('POST /api/notifications/preferences', () => {
    it('should update notification preferences', async () => {
      const preferences = {
        push_notifications_enabled: true,
        email_notifications_enabled: false,
        sms_notifications_enabled: true,
        notification_preferences: {
          goal_completed: true,
          friend_request: true,
          round_up: false
        }
      };

      const response = await request(app)
        .post('/api/notifications/preferences')
        .set('Authorization', `Bearer ${authToken}`)
        .send(preferences);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.push_notifications_enabled).toBe(true);
      expect(response.body.data.email_notifications_enabled).toBe(false);
      expect(response.body.data.sms_notifications_enabled).toBe(true);
    });

    it('should validate notification preferences', async () => {
      const response = await request(app)
        .post('/api/notifications/preferences')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          push_notifications_enabled: 'invalid'
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/notifications/push-token', () => {
    it('should update push token', async () => {
      const pushToken = 'test-push-token-123456789';

      const response = await request(app)
        .post('/api/notifications/push-token')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ push_token: pushToken });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    it('should validate push token', async () => {
      const response = await request(app)
        .post('/api/notifications/push-token')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ push_token: 'short' });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/notifications/:notification_id/read', () => {
    beforeEach(async () => {
      // Create a test notification
      const notification = await db('notifications').insert({
        user_id: testUser.id,
        type: 'test_notification',
        title: 'Test Notification',
        message: 'This is a test notification',
        channel: 'in_app',
        status: 'unread'
      }).returning('*');

      testNotificationId = notification[0].id;
    });

    it('should mark notification as read', async () => {
      const response = await request(app)
        .post(`/api/notifications/${testNotificationId}/read`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.status).toBe('read');
    });

    it('should not mark notification as read for wrong user', async () => {
      const response = await request(app)
        .post(`/api/notifications/${testNotificationId}/read`)
        .set('Authorization', `Bearer ${authToken2}`);

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });

    it('should validate notification ID', async () => {
      const response = await request(app)
        .post('/api/notifications/invalid-id/read')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/notifications/mark-all-read', () => {
    beforeEach(async () => {
      // Create multiple unread notifications
      await db('notifications').insert([
        {
          user_id: testUser.id,
          type: 'test_notification_1',
          title: 'Test Notification 1',
          message: 'This is test notification 1',
          channel: 'in_app',
          status: 'unread'
        },
        {
          user_id: testUser.id,
          type: 'test_notification_2',
          title: 'Test Notification 2',
          message: 'This is test notification 2',
          channel: 'in_app',
          status: 'unread'
        }
      ]);
    });

    it('should mark all notifications as read', async () => {
      const response = await request(app)
        .post('/api/notifications/mark-all-read')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.updated_count).toBeGreaterThan(0);
    });
  });

  describe('POST /api/notifications/create', () => {
    it('should create a notification', async () => {
      const notificationData = {
        user_id: testUser.id,
        type: 'goal_completed',
        title: 'Goal Completed!',
        message: 'Congratulations! You have completed your savings goal.',
        data: {
          goal_id: 'test-goal-id',
          goal_name: 'Test Goal'
        },
        channels: ['in_app', 'push']
      };

      const response = await request(app)
        .post('/api/notifications/create')
        .set('Authorization', `Bearer ${authToken}`)
        .send(notificationData);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.notifications).toHaveLength(2); // in_app and push
    });

    it('should validate notification data', async () => {
      const response = await request(app)
        .post('/api/notifications/create')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          user_id: 'invalid-uuid',
          type: '',
          title: '',
          message: ''
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('POST /api/notifications/batch', () => {
    it('should create batch notifications', async () => {
      const batchData = {
        batch_type: 'weekly_summary',
        recipients: [testUser.id, testUser2.id],
        template_data: {
          type: 'weekly_summary',
          title: 'Your Weekly Summary',
          message: 'Here is your weekly savings summary.',
          data: {
            total_saved: 150.00,
            goals_completed: 1
          },
          channels: ['in_app', 'email']
        }
      };

      const response = await request(app)
        .post('/api/notifications/batch')
        .set('Authorization', `Bearer ${authToken}`)
        .send(batchData);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.total_recipients).toBe(2);
    });

    it('should validate batch notification data', async () => {
      const response = await request(app)
        .post('/api/notifications/batch')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          batch_type: '',
          recipients: [],
          template_data: {}
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/notifications/templates', () => {
    it('should get notification templates', async () => {
      const response = await request(app)
        .get('/api/notifications/templates')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('templates');
    });
  });

  describe('POST /api/notifications/templates', () => {
    it('should create notification template', async () => {
      const templateData = {
        type: 'goal_reminder',
        name: 'Goal Reminder Template',
        title_template: 'Don\'t forget about your goal: {{goal_name}}',
        message_template: 'You\'re {{progress_percentage}}% of the way to your goal. Keep it up!',
        variables: ['goal_name', 'progress_percentage']
      };

      const response = await request(app)
        .post('/api/notifications/templates')
        .set('Authorization', `Bearer ${authToken}`)
        .send(templateData);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.type).toBe('goal_reminder');
    });

    it('should validate template data', async () => {
      const response = await request(app)
        .post('/api/notifications/templates')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          type: '',
          name: '',
          title_template: '',
          message_template: ''
        });

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('GET /api/notifications/batch/:batch_id/status', () => {
    let batchId;

    beforeEach(async () => {
      // Create a test batch
      const batch = await db('notification_batches').insert({
        batch_type: 'test_batch',
        recipients: [testUser.id],
        total_count: 1,
        status: 'pending'
      }).returning('*');

      batchId = batch[0].id;
    });

    it('should get batch notification status', async () => {
      const response = await request(app)
        .get(`/api/notifications/batch/${batchId}/status`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.data.id).toBe(batchId);
    });

    it('should return 404 for non-existent batch', async () => {
      const response = await request(app)
        .get('/api/notifications/batch/00000000-0000-0000-0000-000000000000/status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(404);
      expect(response.body.success).toBe(false);
    });

    it('should validate batch ID', async () => {
      const response = await request(app)
        .get('/api/notifications/batch/invalid-id/status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(response.status).toBe(400);
      expect(response.body.success).toBe(false);
    });
  });

  describe('Error handling', () => {
    it('should handle unauthorized access', async () => {
      const response = await request(app)
        .get('/api/notifications');

      expect(response.status).toBe(401);
    });

    it('should handle invalid token', async () => {
      const response = await request(app)
        .get('/api/notifications')
        .set('Authorization', 'Bearer invalid-token');

      expect(response.status).toBe(401);
    });
  });
}); 