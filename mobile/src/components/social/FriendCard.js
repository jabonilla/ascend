import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const FriendCard = ({ friend, onPress }) => {
  const { colors } = useTheme();

  const getProgressPercentage = () => {
    if (!friend.active_goals || friend.active_goals.length === 0) return 0;
    
    const totalProgress = friend.active_goals.reduce((sum, goal) => {
      return sum + (goal.saved_amount / goal.target_amount) * 100;
    }, 0);
    
    return Math.round(totalProgress / friend.active_goals.length);
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'online':
        return colors.success;
      case 'offline':
        return colors.textSecondary;
      case 'away':
        return colors.warning;
      default:
        return colors.textSecondary;
    }
  };

  return (
    <TouchableOpacity
      style={[styles.container, { backgroundColor: colors.card }]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.mainContent}>
        <View style={styles.leftSection}>
          <View style={styles.avatarContainer}>
            <View style={[styles.avatar, { backgroundColor: colors.primary }]}>
              <Text style={styles.avatarText}>
                {friend.first_name?.charAt(0) || friend.email?.charAt(0) || 'F'}
              </Text>
            </View>
            <View style={[styles.statusIndicator, { backgroundColor: getStatusColor(friend.status) }]} />
          </View>
          
          <View style={styles.friendInfo}>
            <Text style={[styles.friendName, { color: colors.text }]} numberOfLines={1}>
              {friend.first_name && friend.last_name 
                ? `${friend.first_name} ${friend.last_name}`
                : friend.email || 'Friend'
              }
            </Text>
            <Text style={[styles.friendEmail, { color: colors.textSecondary }]} numberOfLines={1}>
              {friend.email}
            </Text>
            
            {friend.active_goals && friend.active_goals.length > 0 && (
              <View style={styles.goalsInfo}>
                <Icon name="flag" size={12} color={colors.textSecondary} />
                <Text style={[styles.goalsText, { color: colors.textSecondary }]}>
                  {friend.active_goals.length} active goal{friend.active_goals.length !== 1 ? 's' : ''}
                </Text>
              </View>
            )}
          </View>
        </View>
        
        <View style={styles.rightSection}>
          <View style={styles.statsContainer}>
            <Text style={[styles.savedAmount, { color: colors.primary }]}>
              ${friend.total_saved?.toFixed(2) || '0.00'}
            </Text>
            <Text style={[styles.savedLabel, { color: colors.textSecondary }]}>
              Total Saved
            </Text>
          </View>
          
          {friend.active_goals && friend.active_goals.length > 0 && (
            <View style={styles.progressContainer}>
              <View style={[styles.progressBar, { backgroundColor: colors.border }]}>
                <View 
                  style={[
                    styles.progressFill, 
                    { 
                      backgroundColor: colors.primary,
                      width: `${getProgressPercentage()}%`
                    }
                  ]} 
                />
              </View>
              <Text style={[styles.progressText, { color: colors.textSecondary }]}>
                {getProgressPercentage()}% avg progress
              </Text>
            </View>
          )}
        </View>
      </View>
    </TouchableOpacity>
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
  avatarContainer: {
    position: 'relative',
    marginRight: 12,
  },
  avatar: {
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: 'white',
  },
  statusIndicator: {
    position: 'absolute',
    bottom: 2,
    right: 2,
    width: 12,
    height: 12,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: 'white',
  },
  friendInfo: {
    flex: 1,
  },
  friendName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  friendEmail: {
    fontSize: 12,
    marginBottom: 4,
  },
  goalsInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 2,
  },
  goalsText: {
    fontSize: 11,
    marginLeft: 4,
  },
  rightSection: {
    alignItems: 'flex-end',
  },
  statsContainer: {
    alignItems: 'flex-end',
    marginBottom: 8,
  },
  savedAmount: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 2,
  },
  savedLabel: {
    fontSize: 10,
    textAlign: 'right',
  },
  progressContainer: {
    alignItems: 'flex-end',
  },
  progressBar: {
    width: 80,
    height: 4,
    borderRadius: 2,
    marginBottom: 4,
  },
  progressFill: {
    height: '100%',
    borderRadius: 2,
  },
  progressText: {
    fontSize: 10,
    textAlign: 'right',
  },
});

export default FriendCard; 