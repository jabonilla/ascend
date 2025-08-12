import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const GroupGoalCard = ({ groupGoal, onPress }) => {
  const { colors } = useTheme();

  const getProgressPercentage = () => {
    if (!groupGoal.target_amount || groupGoal.target_amount <= 0) return 0;
    return Math.min((groupGoal.saved_amount / groupGoal.target_amount) * 100, 100);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getDaysRemaining = () => {
    if (!groupGoal.target_date) return null;
    const targetDate = new Date(groupGoal.target_date);
    const today = new Date();
    const diffTime = targetDate - today;
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
  };

  const renderMembers = () => {
    if (!groupGoal.members || groupGoal.members.length === 0) return null;

    const maxMembersToShow = 3;
    const membersToShow = groupGoal.members.slice(0, maxMembersToShow);
    const remainingMembers = groupGoal.members.length - maxMembersToShow;

    return (
      <View style={styles.membersContainer}>
        <Text style={[styles.membersLabel, { color: colors.textSecondary }]}>
          Members:
        </Text>
        <View style={styles.membersList}>
          {membersToShow.map((member, index) => (
            <View key={member.id} style={styles.memberAvatar}>
              <View style={[styles.avatar, { backgroundColor: colors.primary }]}>
                <Text style={styles.avatarText}>
                  {member.first_name?.charAt(0) || member.email?.charAt(0) || 'M'}
                </Text>
              </View>
            </View>
          ))}
          {remainingMembers > 0 && (
            <View style={[styles.remainingMembers, { backgroundColor: colors.border }]}>
              <Text style={[styles.remainingText, { color: colors.textSecondary }]}>
                +{remainingMembers}
              </Text>
            </View>
          )}
        </View>
      </View>
    );
  };

  const renderProgress = () => {
    const progressPercentage = getProgressPercentage();
    const daysRemaining = getDaysRemaining();

    return (
      <View style={styles.progressContainer}>
        <View style={styles.progressHeader}>
          <Text style={[styles.progressText, { color: colors.textSecondary }]}>
            Progress
          </Text>
          <Text style={[styles.progressPercentage, { color: colors.primary }]}>
            {progressPercentage.toFixed(1)}%
          </Text>
        </View>
        <View style={[styles.progressBar, { backgroundColor: colors.border }]}>
          <View 
            style={[
              styles.progressFill, 
              { 
                backgroundColor: colors.primary,
                width: `${progressPercentage}%`
              }
            ]} 
          />
        </View>
        <View style={styles.progressDetails}>
          <Text style={[styles.savedAmount, { color: colors.primary }]}>
            ${groupGoal.saved_amount?.toFixed(2) || '0.00'}
          </Text>
          <Text style={[styles.targetAmount, { color: colors.textSecondary }]}>
            of ${groupGoal.target_amount?.toFixed(2) || '0.00'}
          </Text>
        </View>
        {daysRemaining !== null && (
          <Text style={[styles.daysRemaining, { color: colors.textSecondary }]}>
            {daysRemaining > 0 ? `${daysRemaining} days left` : 'Target date reached'}
          </Text>
        )}
      </View>
    );
  };

  return (
    <TouchableOpacity
      style={[styles.container, { backgroundColor: colors.card }]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.header}>
        <View style={styles.leftHeader}>
          <Icon name="group" size={20} color={colors.primary} />
          <Text style={[styles.goalName, { color: colors.text }]} numberOfLines={1}>
            {groupGoal.name}
          </Text>
        </View>
        <View style={[styles.statusBadge, { backgroundColor: colors.primary + '20' }]}>
          <Text style={[styles.statusText, { color: colors.primary }]}>
            {groupGoal.status || 'Active'}
          </Text>
        </View>
      </View>

      <Text style={[styles.goalDescription, { color: colors.textSecondary }]} numberOfLines={2}>
        {groupGoal.description || 'No description available'}
      </Text>

      {renderMembers()}
      {renderProgress()}

      <View style={styles.footer}>
        <Text style={[styles.createdDate, { color: colors.textSecondary }]}>
          Created {formatDate(groupGoal.created_at)}
        </Text>
        {groupGoal.target_date && (
          <Text style={[styles.targetDate, { color: colors.textSecondary }]}>
            Target: {formatDate(groupGoal.target_date)}
          </Text>
        )}
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
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  leftHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  goalName: {
    fontSize: 18,
    fontWeight: 'bold',
    marginLeft: 8,
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 10,
    fontWeight: '600',
  },
  goalDescription: {
    fontSize: 14,
    marginBottom: 12,
    lineHeight: 20,
  },
  membersContainer: {
    marginBottom: 16,
  },
  membersLabel: {
    fontSize: 12,
    marginBottom: 8,
  },
  membersList: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  memberAvatar: {
    marginRight: 8,
  },
  avatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: 'white',
  },
  remainingMembers: {
    width: 32,
    height: 32,
    borderRadius: 16,
    justifyContent: 'center',
    alignItems: 'center',
  },
  remainingText: {
    fontSize: 10,
    fontWeight: '600',
  },
  progressContainer: {
    marginBottom: 12,
  },
  progressHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  progressText: {
    fontSize: 12,
  },
  progressPercentage: {
    fontSize: 12,
    fontWeight: '600',
  },
  progressBar: {
    height: 6,
    borderRadius: 3,
    marginBottom: 8,
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  progressDetails: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  savedAmount: {
    fontSize: 16,
    fontWeight: 'bold',
  },
  targetAmount: {
    fontSize: 14,
    marginLeft: 4,
  },
  daysRemaining: {
    fontSize: 11,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  createdDate: {
    fontSize: 10,
  },
  targetDate: {
    fontSize: 10,
  },
});

export default GroupGoalCard; 