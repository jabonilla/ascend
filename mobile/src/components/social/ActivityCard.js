import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const ActivityCard = ({ activity }) => {
  const { colors } = useTheme();

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = now - date;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor(diffTime / (1000 * 60 * 60));
    const diffMinutes = Math.floor(diffTime / (1000 * 60));

    if (diffDays > 0) {
      return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
    } else if (diffHours > 0) {
      return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
    } else if (diffMinutes > 0) {
      return `${diffMinutes} minute${diffMinutes !== 1 ? 's' : ''} ago`;
    } else {
      return 'Just now';
    }
  };

  const getActivityIcon = (type) => {
    switch (type) {
      case 'goal_completed':
        return 'flag';
      case 'goal_created':
        return 'add-circle';
      case 'contribution':
        return 'account-balance-wallet';
      case 'roundup':
        return 'trending-up';
      case 'group_goal_joined':
        return 'group-add';
      case 'achievement':
        return 'emoji-events';
      case 'friend_added':
        return 'person-add';
      default:
        return 'info';
    }
  };

  const getActivityColor = (type) => {
    switch (type) {
      case 'goal_completed':
        return colors.success;
      case 'goal_created':
        return colors.primary;
      case 'contribution':
        return colors.warning;
      case 'roundup':
        return colors.primary;
      case 'group_goal_joined':
        return colors.primary;
      case 'achievement':
        return colors.warning;
      case 'friend_added':
        return colors.success;
      default:
        return colors.textSecondary;
    }
  };

  const getActivityMessage = () => {
    const { type, user_name, goal_name, amount, achievement_name } = activity;

    switch (type) {
      case 'goal_completed':
        return `${user_name} completed their goal "${goal_name}"! 🎉`;
      case 'goal_created':
        return `${user_name} created a new goal "${goal_name}"`;
      case 'contribution':
        return `${user_name} contributed $${amount?.toFixed(2)} to "${goal_name}"`;
      case 'roundup':
        return `${user_name} saved $${amount?.toFixed(2)} from a roundup`;
      case 'group_goal_joined':
        return `${user_name} joined the group goal "${goal_name}"`;
      case 'achievement':
        return `${user_name} earned the "${achievement_name}" achievement! 🏆`;
      case 'friend_added':
        return `${user_name} added a new friend`;
      default:
        return activity.message || 'Activity';
    }
  };

  const renderAmount = () => {
    if (!activity.amount) return null;

    return (
      <View style={[styles.amountContainer, { backgroundColor: getActivityColor(activity.type) + '20' }]}>
        <Text style={[styles.amountText, { color: getActivityColor(activity.type) }]}>
          ${activity.amount.toFixed(2)}
        </Text>
      </View>
    );
  };

  const renderGoalInfo = () => {
    if (!activity.goal_name) return null;

    return (
      <View style={[styles.goalContainer, { backgroundColor: colors.border }]}>
        <Icon name="flag" size={16} color={colors.textSecondary} />
        <Text style={[styles.goalText, { color: colors.textSecondary }]} numberOfLines={1}>
          {activity.goal_name}
        </Text>
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.card }]}>
      <View style={styles.mainContent}>
        <View style={styles.leftSection}>
          <View style={[styles.iconContainer, { backgroundColor: getActivityColor(activity.type) + '20' }]}>
            <Icon 
              name={getActivityIcon(activity.type)} 
              size={20} 
              color={getActivityColor(activity.type)} 
            />
          </View>
          
          <View style={styles.activityInfo}>
            <Text style={[styles.activityMessage, { color: colors.text }]}>
              {getActivityMessage()}
            </Text>
            
            <View style={styles.activityMeta}>
              <Text style={[styles.timestamp, { color: colors.textSecondary }]}>
                {formatDate(activity.created_at)}
              </Text>
              {activity.location && (
                <Text style={[styles.location, { color: colors.textSecondary }]}>
                  • {activity.location}
                </Text>
              )}
            </View>

            {renderGoalInfo()}
          </View>
        </View>
        
        {renderAmount()}
      </View>

      {activity.likes_count > 0 && (
        <View style={styles.footer}>
          <View style={styles.likesContainer}>
            <Icon name="favorite" size={14} color={colors.error} />
            <Text style={[styles.likesText, { color: colors.textSecondary }]}>
              {activity.likes_count} like{activity.likes_count !== 1 ? 's' : ''}
            </Text>
          </View>
          {activity.comments_count > 0 && (
            <Text style={[styles.commentsText, { color: colors.textSecondary }]}>
              {activity.comments_count} comment{activity.comments_count !== 1 ? 's' : ''}
            </Text>
          )}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 12,
    borderRadius: 12,
    padding: 16,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  mainContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  leftSection: {
    flex: 1,
    flexDirection: 'row',
    marginRight: 12,
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  activityInfo: {
    flex: 1,
  },
  activityMessage: {
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 4,
  },
  activityMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  timestamp: {
    fontSize: 12,
  },
  location: {
    fontSize: 12,
    marginLeft: 4,
  },
  goalContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    alignSelf: 'flex-start',
  },
  goalText: {
    fontSize: 11,
    marginLeft: 4,
    fontWeight: '500',
  },
  amountContainer: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  amountText: {
    fontSize: 14,
    fontWeight: 'bold',
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#f0f0f0',
  },
  likesContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  likesText: {
    fontSize: 12,
    marginLeft: 4,
  },
  commentsText: {
    fontSize: 12,
  },
});

export default ActivityCard; 