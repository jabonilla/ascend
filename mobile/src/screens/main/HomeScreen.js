import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Dimensions,
} from 'react-native';
import LinearGradient from 'react-native-linear-gradient';
import { useTheme } from '../../theme/ThemeContext';
import { useAuth } from '../../contexts/AuthContext';

const { width } = Dimensions.get('window');

const HomeScreen = ({ navigation }) => {
  const { theme } = useTheme();
  const { user } = useAuth();
  const [refreshing, setRefreshing] = useState(false);
  const [stats, setStats] = useState({
    totalSaved: 0,
    monthlySaved: 0,
    activeGoals: 0,
    completedGoals: 0,
  });

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    // TODO: Load actual data from API
    setStats({
      totalSaved: 1250.75,
      monthlySaved: 245.50,
      activeGoals: 3,
      completedGoals: 2,
    });
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadDashboardData();
    setRefreshing(false);
  };

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
    }).format(amount);
  };

  const renderHeader = () => (
    <LinearGradient
      colors={[theme.colors.primary, theme.colors.primaryDark]}
      style={styles.header}
    >
      <View style={styles.headerContent}>
        <View>
          <Text style={[styles.greeting, { color: theme.colors.textInverse }]}>
            Good morning, {user?.first_name || 'User'}! 👋
          </Text>
          <Text style={[styles.subtitle, { color: theme.colors.textInverse }]}>
            Let's check your savings progress
          </Text>
        </View>
        <TouchableOpacity
          style={styles.profileButton}
          onPress={() => navigation.navigate('Profile')}
        >
          <Text style={styles.profileIcon}>👤</Text>
        </TouchableOpacity>
      </View>
    </LinearGradient>
  );

  const renderTotalSaved = () => (
    <View style={[styles.totalSavedCard, { backgroundColor: theme.colors.background }]}>
      <Text style={[styles.cardTitle, { color: theme.colors.textPrimary }]}>
        Total Saved
      </Text>
      <Text style={[styles.totalAmount, { color: theme.colors.primary }]}>
        {formatCurrency(stats.totalSaved)}
      </Text>
      <Text style={[styles.monthlySaved, { color: theme.colors.textSecondary }]}>
        +{formatCurrency(stats.monthlySaved)} this month
      </Text>
    </View>
  );

  const renderQuickActions = () => (
    <View style={styles.quickActionsContainer}>
      <Text style={[styles.sectionTitle, { color: theme.colors.textPrimary }]}>
        Quick Actions
      </Text>
      <View style={styles.quickActionsGrid}>
        <TouchableOpacity
          style={[styles.quickAction, { backgroundColor: theme.colors.background }]}
          onPress={() => navigation.navigate('Goals')}
        >
          <Text style={styles.actionIcon}>🎯</Text>
          <Text style={[styles.actionText, { color: theme.colors.textPrimary }]}>
            Add Goal
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.quickAction, { backgroundColor: theme.colors.background }]}
          onPress={() => navigation.navigate('Transactions')}
        >
          <Text style={styles.actionIcon}>💳</Text>
          <Text style={[styles.actionText, { color: theme.colors.textPrimary }]}>
            View Transactions
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.quickAction, { backgroundColor: theme.colors.background }]}
          onPress={() => navigation.navigate('Social')}
        >
          <Text style={styles.actionIcon}>👥</Text>
          <Text style={[styles.actionText, { color: theme.colors.textPrimary }]}>
            Social
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.quickAction, { backgroundColor: theme.colors.background }]}
          onPress={() => {/* TODO: Add manual contribution */}}
        >
          <Text style={styles.actionIcon}>💰</Text>
          <Text style={[styles.actionText, { color: theme.colors.textPrimary }]}>
            Add Money
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  const renderGoalsOverview = () => (
    <View style={styles.goalsOverviewContainer}>
      <View style={styles.goalsHeader}>
        <Text style={[styles.sectionTitle, { color: theme.colors.textPrimary }]}>
          Your Goals
        </Text>
        <TouchableOpacity onPress={() => navigation.navigate('Goals')}>
          <Text style={[styles.viewAllText, { color: theme.colors.primary }]}>
            View All
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.goalsStats}>
        <View style={[styles.goalStat, { backgroundColor: theme.colors.background }]}>
          <Text style={styles.goalStatIcon}>🎯</Text>
          <Text style={[styles.goalStatNumber, { color: theme.colors.primary }]}>
            {stats.activeGoals}
          </Text>
          <Text style={[styles.goalStatLabel, { color: theme.colors.textSecondary }]}>
            Active Goals
          </Text>
        </View>

        <View style={[styles.goalStat, { backgroundColor: theme.colors.background }]}>
          <Text style={styles.goalStatIcon}>✅</Text>
          <Text style={[styles.goalStatNumber, { color: theme.colors.success }]}>
            {stats.completedGoals}
          </Text>
          <Text style={[styles.goalStatLabel, { color: theme.colors.textSecondary }]}>
            Completed
          </Text>
        </View>
      </View>
    </View>
  );

  const renderRecentActivity = () => (
    <View style={styles.recentActivityContainer}>
      <View style={styles.activityHeader}>
        <Text style={[styles.sectionTitle, { color: theme.colors.textPrimary }]}>
          Recent Activity
        </Text>
        <TouchableOpacity onPress={() => navigation.navigate('Transactions')}>
          <Text style={[styles.viewAllText, { color: theme.colors.primary }]}>
            View All
          </Text>
        </TouchableOpacity>
      </View>

      <View style={[styles.activityCard, { backgroundColor: theme.colors.background }]}>
        <View style={styles.activityItem}>
          <Text style={styles.activityIcon}>💳</Text>
          <View style={styles.activityContent}>
            <Text style={[styles.activityTitle, { color: theme.colors.textPrimary }]}>
              Round-up from Starbucks
            </Text>
            <Text style={[styles.activitySubtitle, { color: theme.colors.textSecondary }]}>
              $4.25 → $5.00
            </Text>
          </View>
          <Text style={[styles.activityAmount, { color: theme.colors.primary }]}>
            +$0.75
          </Text>
        </View>

        <View style={styles.activityItem}>
          <Text style={styles.activityIcon}>🎯</Text>
          <View style={styles.activityContent}>
            <Text style={[styles.activityTitle, { color: theme.colors.textPrimary }]}>
              Progress on iPhone Goal
            </Text>
            <Text style={[styles.activitySubtitle, { color: theme.colors.textSecondary }]}>
              75% complete
            </Text>
          </View>
          <Text style={[styles.activityAmount, { color: theme.colors.success }]}>
            $750/$1000
          </Text>
        </View>
      </View>
    </View>
  );

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.backgroundSecondary }]}>
      {renderHeader()}
      
      <ScrollView
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        showsVerticalScrollIndicator={false}
      >
        {renderTotalSaved()}
        {renderQuickActions()}
        {renderGoalsOverview()}
        {renderRecentActivity()}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingTop: 60,
    paddingBottom: 30,
    paddingHorizontal: 20,
  },
  headerContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  greeting: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  subtitle: {
    fontSize: 16,
    opacity: 0.9,
  },
  profileButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  profileIcon: {
    fontSize: 20,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 20,
  },
  totalSavedCard: {
    borderRadius: 20,
    padding: 25,
    marginBottom: 25,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 3.84,
    elevation: 5,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 10,
  },
  totalAmount: {
    fontSize: 36,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  monthlySaved: {
    fontSize: 14,
    fontWeight: '500',
  },
  quickActionsContainer: {
    marginBottom: 25,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 15,
  },
  quickActionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  quickAction: {
    width: (width - 60) / 2,
    borderRadius: 15,
    padding: 20,
    alignItems: 'center',
    marginBottom: 15,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  actionIcon: {
    fontSize: 30,
    marginBottom: 10,
  },
  actionText: {
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
  goalsOverviewContainer: {
    marginBottom: 25,
  },
  goalsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  viewAllText: {
    fontSize: 14,
    fontWeight: '600',
  },
  goalsStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  goalStat: {
    flex: 1,
    borderRadius: 15,
    padding: 20,
    alignItems: 'center',
    marginHorizontal: 5,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  goalStatIcon: {
    fontSize: 24,
    marginBottom: 10,
  },
  goalStatNumber: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 5,
  },
  goalStatLabel: {
    fontSize: 12,
    fontWeight: '500',
  },
  recentActivityContainer: {
    marginBottom: 25,
  },
  activityHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 15,
  },
  activityCard: {
    borderRadius: 15,
    padding: 20,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  activityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 15,
  },
  activityIcon: {
    fontSize: 20,
    marginRight: 15,
  },
  activityContent: {
    flex: 1,
  },
  activityTitle: {
    fontSize: 14,
    fontWeight: '600',
    marginBottom: 2,
  },
  activitySubtitle: {
    fontSize: 12,
  },
  activityAmount: {
    fontSize: 14,
    fontWeight: '600',
  },
});

export default HomeScreen; 