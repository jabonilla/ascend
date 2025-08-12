const { db } = require('../config/database');
const logger = require('../utils/logger');
const emailService = require('./emailService');

// Initialize OneSignal for push notifications
const OneSignal = require('onesignal-node');
const oneSignalClient = new OneSignal.Client(
  process.env.ONESIGNAL_APP_ID,
  process.env.ONESIGNAL_REST_API_KEY
);

// Initialize Twilio for SMS
const twilio = require('twilio');
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID,
  process.env.TWILIO_AUTH_TOKEN
);

// Create a notification
const createNotification = async (userId, type, title, message, data = {}, channels = ['in_app']) => {
  try {
    const user = await db('users')
      .where('id', userId)
      .select('*')
      .first();

    if (!user) {
      return {
        success: false,
        error: 'User not found'
      };
    }

    const notifications = [];

    // Create notification records for each channel
    for (const channel of channels) {
      const notification = {
        user_id: userId,
        type,
        title,
        message,
        data,
        channel,
        status: 'unread'
      };

      const [createdNotification] = await db('notifications')
        .insert(notification)
        .returning('*');

      notifications.push(createdNotification);
    }

    // Send notifications through appropriate channels
    await Promise.all(
      channels.map(async (channel) => {
        switch (channel) {
          case 'push':
            await sendPushNotification(userId, title, message, data);
            break;
          case 'email':
            await sendEmailNotification(user.email, title, message, data);
            break;
          case 'sms':
            await sendSMSNotification(user.phone, message);
            break;
          case 'in_app':
            // In-app notifications are already stored in database
            break;
        }
      })
    );

    logger.info(`Created ${notifications.length} notifications for user ${userId}, type: ${type}`);

    return {
      success: true,
      data: {
        notifications
      }
    };
  } catch (error) {
    logger.error('Error creating notification:', error);
    return {
      success: false,
      error: 'Failed to create notification'
    };
  }
};

// Send push notification
const sendPushNotification = async (userId, title, message, data = {}) => {
  try {
    const user = await db('users')
      .where('id', userId)
      .where('push_notifications_enabled', true)
      .select('push_token')
      .first();

    if (!user || !user.push_token) {
      return {
        success: false,
        error: 'No push token found or notifications disabled'
      };
    }

    const notification = {
      app_id: process.env.ONESIGNAL_APP_ID,
      include_player_ids: [user.push_token],
      headings: { en: title },
      contents: { en: message },
      data: data,
      android_channel_id: 'roundup-savings',
      ios_badgeType: 'Increase',
      ios_badgeCount: 1
    };

    const response = await oneSignalClient.createNotification(notification);

    // Update notification status
    await db('notifications')
      .where('user_id', userId)
      .where('type', data.type || 'push')
      .where('channel', 'push')
      .where('is_sent', false)
      .update({
        is_sent: true,
        sent_at: db.fn.now()
      });

    logger.info(`Push notification sent to user ${userId}`);

    return {
      success: true,
      data: response
    };
  } catch (error) {
    logger.error('Error sending push notification:', error);
    return {
      success: false,
      error: 'Failed to send push notification'
    };
  }
};

// Send email notification
const sendEmailNotification = async (email, title, message, data = {}) => {
  try {
    const emailData = {
      to: email,
      subject: title,
      text: message,
      html: generateEmailHTML(title, message, data)
    };

    await emailService.sendNotificationEmail(emailData);

    // Update notification status
    await db('notifications')
      .where('channel', 'email')
      .where('is_sent', false)
      .update({
        is_sent: true,
        sent_at: db.fn.now()
      });

    logger.info(`Email notification sent to ${email}`);

    return {
      success: true
    };
  } catch (error) {
    logger.error('Error sending email notification:', error);
    return {
      success: false,
      error: 'Failed to send email notification'
    };
  }
};

// Send SMS notification
const sendSMSNotification = async (phone, message) => {
  try {
    if (!phone) {
      return {
        success: false,
        error: 'No phone number found'
      };
    }

    const response = await twilioClient.messages.create({
      body: message,
      from: process.env.TWILIO_PHONE_NUMBER,
      to: phone
    });

    // Update notification status
    await db('notifications')
      .where('channel', 'sms')
      .where('is_sent', false)
      .update({
        is_sent: true,
        sent_at: db.fn.now()
      });

    logger.info(`SMS notification sent to ${phone}`);

    return {
      success: true,
      data: response
    };
  } catch (error) {
    logger.error('Error sending SMS notification:', error);
    return {
      success: false,
      error: 'Failed to send SMS notification'
    };
  }
};

// Get user notifications
const getUserNotifications = async (userId, status = null, limit = 20, offset = 0) => {
  try {
    let query = db('notifications')
      .where('user_id', userId)
      .orderBy('created_at', 'desc');

    if (status) {
      query = query.where('status', status);
    }

    // Get total count
    const totalQuery = query.clone();
    const [{ count }] = await totalQuery.count('* as count');

    // Get notifications with pagination
    const notifications = await query
      .limit(limit)
      .offset(offset)
      .select('*');

    return {
      success: true,
      data: {
        notifications,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + notifications.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error getting user notifications:', error);
    return {
      success: false,
      error: 'Failed to retrieve notifications'
    };
  }
};

// Mark notification as read
const markNotificationAsRead = async (userId, notificationId) => {
  try {
    const [notification] = await db('notifications')
      .where('id', notificationId)
      .where('user_id', userId)
      .update({
        status: 'read',
        read_at: db.fn.now(),
        updated_at: db.fn.now()
      })
      .returning('*');

    if (!notification) {
      return {
        success: false,
        error: 'Notification not found'
      };
    }

    logger.info(`Marked notification ${notificationId} as read for user ${userId}`);

    return {
      success: true,
      data: notification
    };
  } catch (error) {
    logger.error('Error marking notification as read:', error);
    return {
      success: false,
      error: 'Failed to mark notification as read'
    };
  }
};

// Mark all notifications as read
const markAllNotificationsAsRead = async (userId) => {
  try {
    const result = await db('notifications')
      .where('user_id', userId)
      .where('status', 'unread')
      .update({
        status: 'read',
        read_at: db.fn.now(),
        updated_at: db.fn.now()
      });

    logger.info(`Marked ${result} notifications as read for user ${userId}`);

    return {
      success: true,
      data: {
        updated_count: result
      }
    };
  } catch (error) {
    logger.error('Error marking all notifications as read:', error);
    return {
      success: false,
      error: 'Failed to mark notifications as read'
    };
  }
};

// Update user notification preferences
const updateNotificationPreferences = async (userId, preferences) => {
  try {
    const allowedPreferences = [
      'push_notifications_enabled',
      'email_notifications_enabled',
      'sms_notifications_enabled',
      'notification_preferences'
    ];

    const updateData = {};
    allowedPreferences.forEach(pref => {
      if (preferences[pref] !== undefined) {
        updateData[pref] = preferences[pref];
      }
    });

    if (Object.keys(updateData).length === 0) {
      return {
        success: false,
        error: 'No valid preferences provided'
      };
    }

    updateData.updated_at = db.fn.now();

    const [user] = await db('users')
      .where('id', userId)
      .update(updateData)
      .returning('*');

    logger.info(`Updated notification preferences for user ${userId}`);

    return {
      success: true,
      data: {
        notification_preferences: user.notification_preferences,
        push_notifications_enabled: user.push_notifications_enabled,
        email_notifications_enabled: user.email_notifications_enabled,
        sms_notifications_enabled: user.sms_notifications_enabled
      }
    };
  } catch (error) {
    logger.error('Error updating notification preferences:', error);
    return {
      success: false,
      error: 'Failed to update notification preferences'
    };
  }
};

// Update push token
const updatePushToken = async (userId, pushToken) => {
  try {
    await db('users')
      .where('id', userId)
      .update({
        push_token: pushToken,
        updated_at: db.fn.now()
      });

    logger.info(`Updated push token for user ${userId}`);

    return {
      success: true,
      message: 'Push token updated successfully'
    };
  } catch (error) {
    logger.error('Error updating push token:', error);
    return {
      success: false,
      error: 'Failed to update push token'
    };
  }
};

// Get notification statistics
const getNotificationStats = async (userId) => {
  try {
    const [totalCount] = await db('notifications')
      .where('user_id', userId)
      .count('* as count');

    const [unreadCount] = await db('notifications')
      .where('user_id', userId)
      .where('status', 'unread')
      .count('* as count');

    const [todayCount] = await db('notifications')
      .where('user_id', userId)
      .where('created_at', '>=', db.raw('CURRENT_DATE'))
      .count('* as count');

    return {
      success: true,
      data: {
        total_notifications: parseInt(totalCount.count),
        unread_notifications: parseInt(unreadCount.count),
        today_notifications: parseInt(todayCount.count)
      }
    };
  } catch (error) {
    logger.error('Error getting notification stats:', error);
    return {
      success: false,
      error: 'Failed to retrieve notification statistics'
    };
  }
};

// Create notification template
const createNotificationTemplate = async (templateData) => {
  try {
    const [template] = await db('notification_templates')
      .insert(templateData)
      .returning('*');

    logger.info(`Created notification template: ${template.type}`);

    return {
      success: true,
      data: template
    };
  } catch (error) {
    logger.error('Error creating notification template:', error);
    return {
      success: false,
      error: 'Failed to create notification template'
    };
  }
};

// Send batch notifications
const sendBatchNotifications = async (batchType, recipients, templateData) => {
  try {
    // Create batch record
    const [batch] = await db('notification_batches').insert({
      batch_type: batchType,
      recipients: recipients,
      total_count: recipients.length,
      status: 'pending'
    }).returning('*');

    // Process notifications in background
    processBatchNotifications(batch.id, recipients, templateData);

    logger.info(`Created batch notification ${batch.id} for ${recipients.length} recipients`);

    return {
      success: true,
      data: {
        batch_id: batch.id,
        total_recipients: recipients.length
      }
    };
  } catch (error) {
    logger.error('Error creating batch notification:', error);
    return {
      success: false,
      error: 'Failed to create batch notification'
    };
  }
};

// Process batch notifications (background job)
const processBatchNotifications = async (batchId, recipients, templateData) => {
  try {
    await db('notification_batches')
      .where('id', batchId)
      .update({
        status: 'processing',
        started_at: db.fn.now()
      });

    let sentCount = 0;
    let failedCount = 0;

    for (const userId of recipients) {
      try {
        const result = await createNotification(
          userId,
          templateData.type,
          templateData.title,
          templateData.message,
          templateData.data,
          templateData.channels || ['in_app']
        );

        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
        }
      } catch (error) {
        failedCount++;
        logger.error(`Error sending notification to user ${userId}:`, error);
      }
    }

    // Update batch status
    await db('notification_batches')
      .where('id', batchId)
      .update({
        status: 'completed',
        sent_count: sentCount,
        failed_count: failedCount,
        completed_at: db.fn.now()
      });

    logger.info(`Completed batch notification ${batchId}: ${sentCount} sent, ${failedCount} failed`);
  } catch (error) {
    logger.error('Error processing batch notifications:', error);
    
    await db('notification_batches')
      .where('id', batchId)
      .update({
        status: 'failed',
        completed_at: db.fn.now()
      });
  }
};

// Generate email HTML
const generateEmailHTML = (title, message, data = {}) => {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>${title}</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #4CAF50; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>RoundUp Savings</h1>
        </div>
        <div class="content">
          <h2>${title}</h2>
          <p>${message}</p>
          ${data.action_url ? `<p><a href="${data.action_url}" style="background: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">View Details</a></p>` : ''}
        </div>
        <div class="footer">
          <p>© 2024 RoundUp Savings. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;
};

module.exports = {
  createNotification,
  sendPushNotification,
  sendEmailNotification,
  sendSMSNotification,
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  updateNotificationPreferences,
  updatePushToken,
  getNotificationStats,
  createNotificationTemplate,
  sendBatchNotifications
}; 