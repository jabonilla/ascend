const { validationResult } = require('express-validator');
const notificationService = require('../services/notificationService');
const logger = require('../utils/logger');

// Get user notifications
const getUserNotifications = async (req, res) => {
  try {
    const { user } = req;
    const { status, limit = 20, offset = 0 } = req.query;

    const result = await notificationService.getUserNotifications(user.id, status, limit, offset);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved notifications for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting user notifications:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve notifications'
    });
  }
};

// Mark notification as read
const markNotificationAsRead = async (req, res) => {
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
    const { notification_id } = req.params;

    const result = await notificationService.markNotificationAsRead(user.id, notification_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Marked notification ${notification_id} as read for user ${user.id}`);

    res.json({
      success: true,
      message: 'Notification marked as read',
      data: result.data
    });
  } catch (error) {
    logger.error('Error marking notification as read:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to mark notification as read'
    });
  }
};

// Mark all notifications as read
const markAllNotificationsAsRead = async (req, res) => {
  try {
    const { user } = req;

    const result = await notificationService.markAllNotificationsAsRead(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Marked all notifications as read for user ${user.id}`);

    res.json({
      success: true,
      message: 'All notifications marked as read',
      data: result.data
    });
  } catch (error) {
    logger.error('Error marking all notifications as read:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to mark notifications as read'
    });
  }
};

// Get notification statistics
const getNotificationStats = async (req, res) => {
  try {
    const { user } = req;

    const result = await notificationService.getNotificationStats(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved notification stats for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting notification stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve notification statistics'
    });
  }
};

// Update notification preferences
const updateNotificationPreferences = async (req, res) => {
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
    const {
      push_notifications_enabled,
      email_notifications_enabled,
      sms_notifications_enabled,
      notification_preferences
    } = req.body;

    const result = await notificationService.updateNotificationPreferences(user.id, {
      push_notifications_enabled,
      email_notifications_enabled,
      sms_notifications_enabled,
      notification_preferences
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Updated notification preferences for user ${user.id}`);

    res.json({
      success: true,
      message: 'Notification preferences updated successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error updating notification preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update notification preferences'
    });
  }
};

// Update push token
const updatePushToken = async (req, res) => {
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
    const { push_token } = req.body;

    const result = await notificationService.updatePushToken(user.id, push_token);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Updated push token for user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error updating push token:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update push token'
    });
  }
};

// Create a notification (admin/internal use)
const createNotification = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user_id, type, title, message, data, channels } = req.body;

    const result = await notificationService.createNotification(
      user_id,
      type,
      title,
      message,
      data,
      channels
    );

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created notification for user ${user_id}, type: ${type}`);

    res.json({
      success: true,
      message: 'Notification created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating notification:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create notification'
    });
  }
};

// Send batch notifications (admin use)
const sendBatchNotifications = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { batch_type, recipients, template_data } = req.body;

    const result = await notificationService.sendBatchNotifications(
      batch_type,
      recipients,
      template_data
    );

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created batch notification ${result.data.batch_id} for ${result.data.total_recipients} recipients`);

    res.json({
      success: true,
      message: 'Batch notification created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating batch notification:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create batch notification'
    });
  }
};

// Get notification templates (admin use)
const getNotificationTemplates = async (req, res) => {
  try {
    const templates = await db('notification_templates')
      .where('is_active', true)
      .select('*')
      .orderBy('type', 'asc');

    logger.info('Retrieved notification templates');

    res.json({
      success: true,
      data: {
        templates
      }
    });
  } catch (error) {
    logger.error('Error getting notification templates:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve notification templates'
    });
  }
};

// Create notification template (admin use)
const createNotificationTemplate = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const {
      type,
      name,
      title_template,
      message_template,
      variables
    } = req.body;

    const result = await notificationService.createNotificationTemplate({
      type,
      name,
      title_template,
      message_template,
      variables: variables || []
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created notification template: ${type}`);

    res.json({
      success: true,
      message: 'Notification template created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating notification template:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create notification template'
    });
  }
};

// Get batch notification status (admin use)
const getBatchNotificationStatus = async (req, res) => {
  try {
    const { batch_id } = req.params;

    const batch = await db('notification_batches')
      .where('id', batch_id)
      .first();

    if (!batch) {
      return res.status(404).json({
        success: false,
        error: 'Batch notification not found'
      });
    }

    logger.info(`Retrieved batch notification status for ${batch_id}`);

    res.json({
      success: true,
      data: batch
    });
  } catch (error) {
    logger.error('Error getting batch notification status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve batch notification status'
    });
  }
};

module.exports = {
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
}; 