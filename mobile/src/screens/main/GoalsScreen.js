import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

// Components
import GoalCard from '../../components/goals/GoalCard';
import EmptyState from '../../components/common/EmptyState';
import LoadingSpinner from '../../components/common/LoadingSpinner';

// Actions
import { fetchGoals, createGoal } from '../../store/actions/goalsActions';

const GoalsScreen = () => {
  const navigation = useNavigation();
  const { colors } = useTheme();
  const dispatch = useDispatch();
  
  const { goals, loading, error } = useSelector(state => state.goals);
  const { user } = useSelector(state => state.auth);
  
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadGoals();
  }, []);

  const loadGoals = async () => {
    try {
      await dispatch(fetchGoals());
    } catch (error) {
      console.error('Error loading goals:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadGoals();
    setRefreshing(false);
  };

  const handleCreateGoal = () => {
    navigation.navigate('CreateGoal');
  };

  const handleGoalPress = (goal) => {
    navigation.navigate('GoalDetail', { goalId: goal.id });
  };

  const handleQuickContribute = (goal) => {
    Alert.prompt(
      'Quick Contribution',
      `How much would you like to contribute to "${goal.name}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Contribute',
          onPress: (amount) => {
            if (amount && !isNaN(amount)) {
              // TODO: Implement quick contribution
              console.log(`Contributing $${amount} to goal ${goal.id}`);
            }
          }
        }
      ],
      'plain-text',
      '',
      'numeric'
    );
  };

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={[styles.title, { color: colors.text }]}>My Goals</Text>
      <TouchableOpacity
        style={[styles.addButton, { backgroundColor: colors.primary }]}
        onPress={handleCreateGoal}
      >
        <Icon name="add" size={24} color="white" />
      </TouchableOpacity>
    </View>
  );

  const renderStats = () => {
    const activeGoals = goals.filter(goal => goal.status === 'active');
    const totalSaved = goals.reduce((sum, goal) => sum + goal.saved_amount, 0);
    const totalTarget = goals.reduce((sum, goal) => sum + goal.target_amount, 0);

    return (
      <View style={styles.statsContainer}>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {activeGoals.length}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Active Goals
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            ${totalSaved.toFixed(2)}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Total Saved
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {totalTarget > 0 ? ((totalSaved / totalTarget) * 100).toFixed(1) : 0}%
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Progress
          </Text>
        </View>
      </View>
    );
  };

  const renderGoalsList = () => {
    if (loading && !refreshing) {
      return <LoadingSpinner />;
    }

    if (goals.length === 0) {
      return (
        <EmptyState
          icon="flag"
          title="No Goals Yet"
          subtitle="Create your first savings goal to start building your future"
          actionText="Create Goal"
          onAction={handleCreateGoal}
        />
      );
    }

    return (
      <View style={styles.goalsList}>
        {goals.map((goal) => (
          <GoalCard
            key={goal.id}
            goal={goal}
            onPress={() => handleGoalPress(goal)}
            onQuickContribute={() => handleQuickContribute(goal)}
          />
        ))}
      </View>
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {renderHeader()}
      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        showsVerticalScrollIndicator={false}
      >
        {renderStats()}
        {renderGoalsList()}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 60,
    paddingBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  addButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollView: {
    flex: 1,
  },
  statsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  statCard: {
    flex: 1,
    marginHorizontal: 5,
    padding: 15,
    borderRadius: 12,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    textAlign: 'center',
  },
  goalsList: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
});

export default GoalsScreen; 