const express = require('express');
const { body, param, query } = require('express-validator');
const {
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  getNotificationStats,
  updateNotificationPreferences,
  updatePushToken,
  createNotification,
  sendBatchNotifications,
  getNotificationTemplates,
  createNotificationTemplate,
  getBatchNotificationStatus
} = require('../controllers/notificationController');

const router = express.Router();

// Validation middleware
const notificationIdValidation = [
  param('notification_id')
    .isUUID()
    .withMessage('Invalid notification ID')
];

const updatePreferencesValidation = [
  body('push_notifications_enabled')
    .optional()
    .isBoolean()
    .withMessage('Push notifications enabled must be a boolean'),
  body('email_notifications_enabled')
    .optional()
    .isBoolean()
    .withMessage('Email notifications enabled must be a boolean'),
  body('sms_notifications_enabled')
    .optional()
    .isBoolean()
    .withMessage('SMS notifications enabled must be a boolean'),
  body('notification_preferences')
    .optional()
    .isObject()
    .withMessage('Notification preferences must be an object')
];

const updatePushTokenValidation = [
  body('push_token')
    .notEmpty()
    .withMessage('Push token is required')
    .isLength({ min: 10 })
    .withMessage('Push token must be at least 10 characters')
];

const createNotificationValidation = [
  body('user_id')
    .isUUID()
    .withMessage('Valid user ID is required'),
  body('type')
    .notEmpty()
    .withMessage('Notification type is required')
    .isLength({ max: 50 })
    .withMessage('Notification type must be less than 50 characters'),
  body('title')
    .notEmpty()
    .withMessage('Notification title is required')
    .isLength({ max: 100 })
    .withMessage('Notification title must be less than 100 characters'),
  body('message')
    .notEmpty()
    .withMessage('Notification message is required')
    .isLength({ max: 500 })
    .withMessage('Notification message must be less than 500 characters'),
  body('data')
    .optional()
    .isObject()
    .withMessage('Notification data must be an object'),
  body('channels')
    .optional()
    .isArray()
    .withMessage('Channels must be an array')
];

const sendBatchNotificationsValidation = [
  body('batch_type')
    .notEmpty()
    .withMessage('Batch type is required')
    .isLength({ max: 50 })
    .withMessage('Batch type must be less than 50 characters'),
  body('recipients')
    .isArray({ min: 1 })
    .withMessage('Recipients must be a non-empty array'),
  body('recipients.*')
    .isUUID()
    .withMessage('Each recipient must be a valid UUID'),
  body('template_data')
    .isObject()
    .withMessage('Template data is required')
];

const createTemplateValidation = [
  body('type')
    .notEmpty()
    .withMessage('Template type is required')
    .isLength({ max: 50 })
    .withMessage('Template type must be less than 50 characters'),
  body('name')
    .notEmpty()
    .withMessage('Template name is required')
    .isLength({ max: 100 })
    .withMessage('Template name must be less than 100 characters'),
  body('title_template')
    .notEmpty()
    .withMessage('Title template is required')
    .isLength({ max: 100 })
    .withMessage('Title template must be less than 100 characters'),
  body('message_template')
    .notEmpty()
    .withMessage('Message template is required')
    .isLength({ max: 500 })
    .withMessage('Message template must be less than 500 characters'),
  body('variables')
    .optional()
    .isArray()
    .withMessage('Variables must be an array')
];

const batchIdValidation = [
  param('batch_id')
    .isUUID()
    .withMessage('Invalid batch ID')
];

const getNotificationsValidation = [
  query('status')
    .optional()
    .isIn(['unread', 'read', 'archived'])
    .withMessage('Status must be one of: unread, read, archived'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer')
];

// User notification routes
router.get('/', getNotificationsValidation, getUserNotifications);
router.get('/stats', getNotificationStats);
router.post('/preferences', updatePreferencesValidation, updateNotificationPreferences);
router.post('/push-token', updatePushTokenValidation, updatePushToken);
router.post('/:notification_id/read', notificationIdValidation, markNotificationAsRead);
router.post('/mark-all-read', markAllNotificationsAsRead);

// Admin notification routes
router.post('/create', createNotificationValidation, createNotification);
router.post('/batch', sendBatchNotificationsValidation, sendBatchNotifications);
router.get('/templates', getNotificationTemplates);
router.post('/templates', createTemplateValidation, createNotificationTemplate);
router.get('/batch/:batch_id/status', batchIdValidation, getBatchNotificationStatus);

module.exports = router; 