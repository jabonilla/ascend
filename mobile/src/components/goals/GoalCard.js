import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useTheme } from '../../theme/ThemeContext';

const GoalCard = ({ goal, onPress, showProgress = true }) => {
  const { theme } = useTheme();
  
  const getStatusColor = (status) => {
    switch (status) {
      case 'active':
        return theme.colors.success;
      case 'paused':
        return theme.colors.warning;
      case 'completed':
        return theme.colors.info;
      default:
        return theme.colors.textTertiary;
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'active':
        return 'play-circle-outline';
      case 'paused':
        return 'pause-circle-outline';
      case 'completed':
        return 'check-circle';
      default:
        return 'help-outline';
    }
  };

  const formatCurrency = (amount) => {
    return `$${parseFloat(amount).toFixed(2)}`;
  };

  const progressPercentage = goal.target_amount > 0 
    ? Math.min((goal.current_amount / goal.target_amount) * 100, 100)
    : 0;

  return (
    <TouchableOpacity
      style={[
        styles.container,
        { 
          backgroundColor: theme.colors.background,
          borderColor: theme.colors.border,
        }
      ]}
      onPress={onPress}
      activeOpacity={0.8}
    >
      <View style={styles.header}>
        <View style={styles.titleContainer}>
          <Text style={[styles.title, { color: theme.colors.textPrimary }]}>
            {goal.name}
          </Text>
          <View style={styles.statusContainer}>
            <Icon 
              name={getStatusIcon(goal.status)} 
              size={16} 
              color={getStatusColor(goal.status)} 
            />
            <Text style={[styles.status, { color: getStatusColor(goal.status) }]}>
              {goal.status}
            </Text>
          </View>
        </View>
        <Icon 
          name="chevron-right" 
          size={20} 
          color={theme.colors.textTertiary} 
        />
      </View>

      <Text style={[styles.description, { color: theme.colors.textSecondary }]}>
        {goal.description}
      </Text>

      <View style={styles.amountContainer}>
        <View style={styles.amountItem}>
          <Text style={[styles.amountLabel, { color: theme.colors.textTertiary }]}>
            Saved
          </Text>
          <Text style={[styles.amountValue, { color: theme.colors.textPrimary }]}>
            {formatCurrency(goal.current_amount)}
          </Text>
        </View>
        <View style={styles.amountItem}>
          <Text style={[styles.amountLabel, { color: theme.colors.textTertiary }]}>
            Target
          </Text>
          <Text style={[styles.amountValue, { color: theme.colors.textPrimary }]}>
            {formatCurrency(goal.target_amount)}
          </Text>
        </View>
      </View>

      {showProgress && (
        <View style={styles.progressContainer}>
          <View style={styles.progressHeader}>
            <Text style={[styles.progressText, { color: theme.colors.textSecondary }]}>
              Progress
            </Text>
            <Text style={[styles.progressPercentage, { color: theme.colors.primary }]}>
              {progressPercentage.toFixed(1)}%
            </Text>
          </View>
          <View style={[styles.progressBar, { backgroundColor: theme.colors.borderLight }]}>
            <View 
              style={[
                styles.progressFill, 
                { 
                  backgroundColor: theme.colors.primary,
                  width: `${progressPercentage}%`,
                }
              ]} 
            />
          </View>
        </View>
      )}

      {goal.deadline && (
        <View style={styles.deadlineContainer}>
          <Icon 
            name="event" 
            size={16} 
            color={theme.colors.textTertiary} 
          />
          <Text style={[styles.deadlineText, { color: theme.colors.textTertiary }]}>
            Due {new Date(goal.deadline).toLocaleDateString()}
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: 8,
  },
  titleContainer: {
    flex: 1,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  status: {
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 4,
    textTransform: 'capitalize',
  },
  description: {
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 16,
  },
  amountContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  amountItem: {
    flex: 1,
  },
  amountLabel: {
    fontSize: 12,
    marginBottom: 4,
  },
  amountValue: {
    fontSize: 16,
    fontWeight: 'bold',
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
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  deadlineContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  deadlineText: {
    fontSize: 12,
    marginLeft: 4,
  },
});

export default GoalCard; 