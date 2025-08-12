import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  FlatList,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

// Components
import FriendCard from '../../components/social/FriendCard';
import GroupGoalCard from '../../components/social/GroupGoalCard';
import ActivityCard from '../../components/social/ActivityCard';
import EmptyState from '../../components/common/EmptyState';
import LoadingSpinner from '../../components/common/LoadingSpinner';

// Actions
import { 
  fetchFriends, 
  fetchGroupGoals, 
  fetchSocialFeed,
  fetchSocialStats 
} from '../../store/actions/socialActions';

const SocialScreen = () => {
  const navigation = useNavigation();
  const { colors } = useTheme();
  const dispatch = useDispatch();
  
  const { friends, groupGoals, socialFeed, socialStats, loading } = useSelector(state => state.social);
  
  const [refreshing, setRefreshing] = useState(false);
  const [activeTab, setActiveTab] = useState('feed');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      await Promise.all([
        dispatch(fetchFriends()),
        dispatch(fetchGroupGoals()),
        dispatch(fetchSocialFeed()),
        dispatch(fetchSocialStats())
      ]);
    } catch (error) {
      console.error('Error loading social data:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const handleFriendPress = (friend) => {
    navigation.navigate('FriendProfile', { userId: friend.id });
  };

  const handleGroupGoalPress = (groupGoal) => {
    navigation.navigate('GroupGoalDetail', { groupGoalId: groupGoal.id });
  };

  const handleCreateGroupGoal = () => {
    navigation.navigate('CreateGroupGoal');
  };

  const handleSearchUsers = () => {
    // TODO: Implement user search
    console.log('Search users');
  };

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={[styles.title, { color: colors.text }]}>Social</Text>
      <TouchableOpacity
        style={[styles.searchButton, { backgroundColor: colors.primary }]}
        onPress={handleSearchUsers}
      >
        <Icon name="search" size={20} color="white" />
      </TouchableOpacity>
    </View>
  );

  const renderStats = () => {
    if (!socialStats) return null;

    return (
      <View style={styles.statsContainer}>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {socialStats.friendsCount || 0}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Friends
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {socialStats.groupGoalsCount || 0}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Group Goals
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            ${socialStats.totalGroupSavings?.toFixed(2) || '0.00'}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Group Savings
          </Text>
        </View>
      </View>
    );
  };

  const renderTabs = () => (
    <View style={styles.tabsContainer}>
      {[
        { key: 'feed', label: 'Feed', icon: 'rss-feed' },
        { key: 'friends', label: 'Friends', icon: 'people' },
        { key: 'groups', label: 'Groups', icon: 'group' },
      ].map((tab) => (
        <TouchableOpacity
          key={tab.key}
          style={[
            styles.tabButton,
            {
              backgroundColor: activeTab === tab.key ? colors.primary : 'transparent',
            },
          ]}
          onPress={() => setActiveTab(tab.key)}
        >
          <Icon
            name={tab.icon}
            size={20}
            color={activeTab === tab.key ? 'white' : colors.textSecondary}
          />
          <Text
            style={[
              styles.tabText,
              {
                color: activeTab === tab.key ? 'white' : colors.textSecondary,
              },
            ]}
          >
            {tab.label}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );

  const renderFeed = () => {
    if (socialFeed.length === 0) {
      return (
        <EmptyState
          icon="rss-feed"
          title="No Activity Yet"
          subtitle="Connect with friends to see their savings activities"
          actionText="Find Friends"
          onAction={handleSearchUsers}
        />
      );
    }

    return (
      <FlatList
        data={socialFeed}
        keyExtractor={(item) => item.id.toString()}
        renderItem={({ item }) => (
          <ActivityCard activity={item} />
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.feedList}
      />
    );
  };

  const renderFriends = () => {
    if (friends.length === 0) {
      return (
        <EmptyState
          icon="people"
          title="No Friends Yet"
          subtitle="Connect with friends to share your savings journey"
          actionText="Find Friends"
          onAction={handleSearchUsers}
        />
      );
    }

    return (
      <FlatList
        data={friends}
        keyExtractor={(item) => item.id.toString()}
        renderItem={({ item }) => (
          <FriendCard
            friend={item}
            onPress={() => handleFriendPress(item)}
          />
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.friendsList}
      />
    );
  };

  const renderGroups = () => {
    return (
      <View style={styles.groupsContainer}>
        <View style={styles.groupsHeader}>
          <Text style={[styles.sectionTitle, { color: colors.text }]}>
            Group Goals
          </Text>
          <TouchableOpacity
            style={[styles.createButton, { backgroundColor: colors.primary }]}
            onPress={handleCreateGroupGoal}
          >
            <Icon name="add" size={20} color="white" />
          </TouchableOpacity>
        </View>

        {groupGoals.length === 0 ? (
          <EmptyState
            icon="group"
            title="No Group Goals"
            subtitle="Create a group goal to save together with friends"
            actionText="Create Group Goal"
            onAction={handleCreateGroupGoal}
          />
        ) : (
          <FlatList
            data={groupGoals}
            keyExtractor={(item) => item.id.toString()}
            renderItem={({ item }) => (
              <GroupGoalCard
                groupGoal={item}
                onPress={() => handleGroupGoalPress(item)}
              />
            )}
            showsVerticalScrollIndicator={false}
            contentContainerStyle={styles.groupsList}
          />
        )}
      </View>
    );
  };

  const renderContent = () => {
    switch (activeTab) {
      case 'feed':
        return renderFeed();
      case 'friends':
        return renderFriends();
      case 'groups':
        return renderGroups();
      default:
        return renderFeed();
    }
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
        {renderTabs()}
        {loading && !refreshing ? <LoadingSpinner /> : renderContent()}
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
  searchButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
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
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    textAlign: 'center',
  },
  tabsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  tabButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    marginHorizontal: 5,
    borderRadius: 8,
  },
  tabText: {
    fontSize: 14,
    fontWeight: '500',
    marginLeft: 6,
  },
  feedList: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  friendsList: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  groupsContainer: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  groupsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold',
  },
  createButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
  },
  groupsList: {
    paddingBottom: 20,
  },
});

export default SocialScreen; 