import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Image,
  Alert,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

// Components
import LoadingSpinner from '../../components/common/LoadingSpinner';

// Actions
import { logout, fetchUserProfile } from '../../store/actions/authActions';

const ProfileScreen = () => {
  const navigation = useNavigation();
  const { colors } = useTheme();
  const dispatch = useDispatch();
  
  const { user, loading } = useSelector(state => state.auth);
  
  useEffect(() => {
    if (user) {
      dispatch(fetchUserProfile());
    }
  }, [user]);

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', style: 'destructive', onPress: () => dispatch(logout()) },
      ]
    );
  };

  const handleSettingsPress = (screen) => {
    navigation.navigate(screen);
  };

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={[styles.title, { color: colors.text }]}>Profile</Text>
    </View>
  );

  const renderUserInfo = () => (
    <View style={[styles.userCard, { backgroundColor: colors.card }]}>
      <View style={styles.userInfo}>
        <View style={[styles.avatar, { backgroundColor: colors.primary }]}>
          <Text style={styles.avatarText}>
            {user?.first_name?.charAt(0) || user?.email?.charAt(0) || 'U'}
          </Text>
        </View>
        <View style={styles.userDetails}>
          <Text style={[styles.userName, { color: colors.text }]}>
            {user?.first_name && user?.last_name 
              ? `${user.first_name} ${user.last_name}`
              : user?.email || 'User'
            }
          </Text>
          <Text style={[styles.userEmail, { color: colors.textSecondary }]}>
            {user?.email}
          </Text>
          <Text style={[styles.memberSince, { color: colors.textSecondary }]}>
            Member since {user?.created_at ? new Date(user.created_at).toLocaleDateString() : 'N/A'}
          </Text>
        </View>
      </View>
    </View>
  );

  const renderStats = () => {
    // TODO: Get actual stats from user profile
    const stats = {
      totalSaved: user?.total_saved || 0,
      goalsCompleted: user?.goals_completed || 0,
      daysActive: user?.days_active || 0,
    };

    return (
      <View style={styles.statsContainer}>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            ${stats.totalSaved.toFixed(2)}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Total Saved
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {stats.goalsCompleted}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Goals Completed
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {stats.daysActive}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Days Active
          </Text>
        </View>
      </View>
    );
  };

  const renderMenuSection = (title, items) => (
    <View style={styles.menuSection}>
      <Text style={[styles.sectionTitle, { color: colors.text }]}>{title}</Text>
      <View style={[styles.menuContainer, { backgroundColor: colors.card }]}>
        {items.map((item, index) => (
          <TouchableOpacity
            key={item.key}
            style={[
              styles.menuItem,
              index < items.length - 1 && { borderBottomWidth: 1, borderBottomColor: colors.border }
            ]}
            onPress={item.onPress}
          >
            <View style={styles.menuItemLeft}>
              <Icon name={item.icon} size={24} color={colors.textSecondary} />
              <Text style={[styles.menuItemText, { color: colors.text }]}>
                {item.title}
              </Text>
            </View>
            <Icon name="chevron-right" size={24} color={colors.textSecondary} />
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );

  const renderAccountMenu = () => {
    const accountItems = [
      {
        key: 'banking',
        title: 'Banking',
        icon: 'account-balance',
        onPress: () => navigation.navigate('BankAccounts'),
      },
      {
        key: 'payment',
        title: 'Payment Methods',
        icon: 'credit-card',
        onPress: () => navigation.navigate('PaymentMethods'),
      },
      {
        key: 'notifications',
        title: 'Notifications',
        icon: 'notifications',
        onPress: () => handleSettingsPress('NotificationSettings'),
      },
    ];

    return renderMenuSection('Account', accountItems);
  };

  const renderSettingsMenu = () => {
    const settingsItems = [
      {
        key: 'privacy',
        title: 'Privacy',
        icon: 'security',
        onPress: () => handleSettingsPress('PrivacySettings'),
      },
      {
        key: 'security',
        title: 'Security',
        icon: 'lock',
        onPress: () => handleSettingsPress('SecuritySettings'),
      },
      {
        key: 'settings',
        title: 'Settings',
        icon: 'settings',
        onPress: () => handleSettingsPress('Settings'),
      },
    ];

    return renderMenuSection('Settings', settingsItems);
  };

  const renderSupportMenu = () => {
    const supportItems = [
      {
        key: 'help',
        title: 'Help & Support',
        icon: 'help',
        onPress: () => {
          // TODO: Implement help/support
          console.log('Help & Support');
        },
      },
      {
        key: 'feedback',
        title: 'Send Feedback',
        icon: 'feedback',
        onPress: () => {
          // TODO: Implement feedback
          console.log('Send Feedback');
        },
      },
      {
        key: 'about',
        title: 'About',
        icon: 'info',
        onPress: () => {
          // TODO: Implement about
          console.log('About');
        },
      },
    ];

    return renderMenuSection('Support', supportItems);
  };

  const renderLogoutButton = () => (
    <TouchableOpacity
      style={[styles.logoutButton, { backgroundColor: colors.error }]}
      onPress={handleLogout}
    >
      <Icon name="logout" size={20} color="white" />
      <Text style={styles.logoutText}>Logout</Text>
    </TouchableOpacity>
  );

  if (loading) {
    return <LoadingSpinner />;
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {renderHeader()}
      <ScrollView
        style={styles.scrollView}
        showsVerticalScrollIndicator={false}
      >
        {renderUserInfo()}
        {renderStats()}
        {renderAccountMenu()}
        {renderSettingsMenu()}
        {renderSupportMenu()}
        {renderLogoutButton()}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 60,
    paddingBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  scrollView: {
    flex: 1,
  },
  userCard: {
    marginHorizontal: 20,
    marginBottom: 20,
    padding: 20,
    borderRadius: 12,
  },
  userInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  avatar: {
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 15,
  },
  avatarText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: 'white',
  },
  userDetails: {
    flex: 1,
  },
  userName: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  userEmail: {
    fontSize: 14,
    marginBottom: 4,
  },
  memberSince: {
    fontSize: 12,
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
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    textAlign: 'center',
  },
  menuSection: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 10,
    paddingHorizontal: 20,
  },
  menuContainer: {
    marginHorizontal: 20,
    borderRadius: 12,
    overflow: 'hidden',
  },
  menuItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  menuItemLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  menuItemText: {
    fontSize: 16,
    marginLeft: 12,
  },
  logoutButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 20,
    marginBottom: 30,
    paddingVertical: 16,
    borderRadius: 12,
  },
  logoutText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
    marginLeft: 8,
  },
});

export default ProfileScreen; 