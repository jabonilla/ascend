import React, { createContext, useContext, useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import PushNotification from 'react-native-push-notification';
import OneSignal from 'react-native-onesignal';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
  const [pushToken, setPushToken] = useState(null);
  const [notificationSettings, setNotificationSettings] = useState({
    push: true,
    email: true,
    sms: false,
  });
  const { user } = useSelector((state) => state.auth);

  // Initialize push notifications
  useEffect(() => {
    if (user) {
      initializePushNotifications();
    }
  }, [user]);

  // Initialize push notifications
  const initializePushNotifications = async () => {
    try {
      // Configure OneSignal
      OneSignal.setAppId(process.env.ONESIGNAL_APP_ID);
      
      // Request notification permissions
      OneSignal.promptForPushNotificationsWithUserResponse((response) => {
        console.log('Prompt response:', response);
      });

      // Set up notification handlers
      OneSignal.setNotificationWillShowInForegroundHandler((notificationReceivedEvent) => {
        console.log('OneSignal: notification will show in foreground:', notificationReceivedEvent);
        // You can prevent the notification from showing by calling:
        // notificationReceivedEvent.preventDefault();
      });

      OneSignal.setNotificationOpenedHandler((notification) => {
        console.log('OneSignal: notification opened:', notification);
        handleNotificationOpened(notification);
      });

      // Get push token
      OneSignal.getDeviceState((deviceState) => {
        if (deviceState && deviceState.userId) {
          setPushToken(deviceState.userId);
          updatePushTokenOnServer(deviceState.userId);
        }
      });

      // Load notification settings
      loadNotificationSettings();
    } catch (error) {
      console.error('Error initializing push notifications:', error);
    }
  };

  // Update push token on server
  const updatePushTokenOnServer = async (token) => {
    try {
      // This would typically be done through your API
      // await api.post('/notifications/push-token', { push_token: token });
      console.log('Push token updated:', token);
    } catch (error) {
      console.error('Error updating push token:', error);
    }
  };

  // Load notification settings from storage
  const loadNotificationSettings = async () => {
    try {
      const settings = await AsyncStorage.getItem('notificationSettings');
      if (settings) {
        setNotificationSettings(JSON.parse(settings));
      }
    } catch (error) {
      console.error('Error loading notification settings:', error);
    }
  };

  // Save notification settings
  const saveNotificationSettings = async (settings) => {
    try {
      await AsyncStorage.setItem('notificationSettings', JSON.stringify(settings));
      setNotificationSettings(settings);
    } catch (error) {
      console.error('Error saving notification settings:', error);
    }
  };

  // Handle notification opened
  const handleNotificationOpened = (notification) => {
    const { data } = notification.notification;
    
    // Navigate based on notification type
    switch (data?.type) {
      case 'goal_completed':
        // Navigate to goal details
        break;
      case 'friend_request':
        // Navigate to friend requests
        break;
      case 'round_up':
        // Navigate to transactions
        break;
      default:
        // Default navigation
        break;
    }
  };

  // Send local notification
  const sendLocalNotification = (title, message, data = {}) => {
    PushNotification.localNotification({
      title,
      message,
      data,
      channelId: 'roundup-savings',
      playSound: true,
      soundName: 'default',
      importance: 'high',
      priority: 'high',
    });
  };

  // Schedule local notification
  const scheduleLocalNotification = (title, message, date, data = {}) => {
    PushNotification.localNotificationSchedule({
      title,
      message,
      date,
      data,
      channelId: 'roundup-savings',
      playSound: true,
      soundName: 'default',
      importance: 'high',
      priority: 'high',
    });
  };

  // Cancel all notifications
  const cancelAllNotifications = () => {
    PushNotification.cancelAllLocalNotifications();
  };

  // Cancel specific notification
  const cancelNotification = (id) => {
    PushNotification.cancelLocalNotification(id);
  };

  // Update notification preferences
  const updateNotificationPreferences = async (preferences) => {
    try {
      const newSettings = { ...notificationSettings, ...preferences };
      await saveNotificationSettings(newSettings);
      
      // Update on server
      // await api.post('/notifications/preferences', newSettings);
    } catch (error) {
      console.error('Error updating notification preferences:', error);
    }
  };

  // Check if notifications are enabled
  const areNotificationsEnabled = () => {
    return notificationSettings.push || notificationSettings.email || notificationSettings.sms;
  };

  // Request notification permissions
  const requestNotificationPermissions = async () => {
    try {
      if (Platform.OS === 'ios') {
        const authStatus = await PushNotification.requestPermissions();
        return authStatus;
      }
      return true;
    } catch (error) {
      console.error('Error requesting notification permissions:', error);
      return false;
    }
  };

  // Configure notification channels (Android)
  const configureNotificationChannels = () => {
    if (Platform.OS === 'android') {
      PushNotification.createChannel(
        {
          channelId: 'roundup-savings',
          channelName: 'RoundUp Savings',
          channelDescription: 'Notifications for RoundUp Savings app',
          playSound: true,
          soundName: 'default',
          importance: 4,
          vibrate: true,
        },
        (created) => console.log(`Channel created: ${created}`)
      );
    }
  };

  const value = {
    pushToken,
    notificationSettings,
    sendLocalNotification,
    scheduleLocalNotification,
    cancelAllNotifications,
    cancelNotification,
    updateNotificationPreferences,
    areNotificationsEnabled,
    requestNotificationPermissions,
    configureNotificationChannels,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
};

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotifications must be used within a NotificationProvider');
  }
  return context;
}; 