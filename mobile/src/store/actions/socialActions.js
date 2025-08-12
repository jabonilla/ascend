import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchFriendsStart, fetchFriendsSuccess, fetchFriendsFailure, fetchGroupGoalsSuccess, fetchSocialFeedSuccess, fetchSocialStatsSuccess } from '../reducers/socialReducer';

// Mock API calls
const mockFetchFriends = async () => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  return [
    {
      id: 1,
      first_name: 'Sarah',
      last_name: 'Johnson',
      email: 'sarah.j@email.com',
      status: 'online',
      total_saved: 3200.50,
      active_goals: [
        { id: 1, name: 'Europe Trip', saved_amount: 2000, target_amount: 5000 }
      ]
    },
    {
      id: 2,
      first_name: 'Mike',
      last_name: 'Chen',
      email: 'mike.chen@email.com',
      status: 'away',
      total_saved: 1850.75,
      active_goals: [
        { id: 2, name: 'New Car', saved_amount: 8000, target_amount: 25000 }
      ]
    },
    {
      id: 3,
      first_name: 'Emma',
      last_name: 'Davis',
      email: 'emma.d@email.com',
      status: 'offline',
      total_saved: 4200.00,
      active_goals: [
        { id: 3, name: 'Wedding Fund', saved_amount: 15000, target_amount: 30000 },
        { id: 4, name: 'House Down Payment', saved_amount: 8000, target_amount: 50000 }
      ]
    }
  ];
};

const mockFetchGroupGoals = async () => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 800));
  
  return [
    {
      id: 1,
      name: 'Group Vacation Fund',
      description: 'Saving together for a group trip to Mexico',
      target_amount: 8000,
      saved_amount: 3200,
      status: 'active',
      target_date: '2024-12-15',
      created_at: '2024-06-01',
      members: [
        { id: 1, first_name: 'Sarah', last_name: 'Johnson', email: 'sarah.j@email.com' },
        { id: 2, first_name: 'Mike', last_name: 'Chen', email: 'mike.chen@email.com' },
        { id: 3, first_name: 'Emma', last_name: 'Davis', email: 'emma.d@email.com' }
      ]
    },
    {
      id: 2,
      name: 'Charity Fundraiser',
      description: 'Collecting donations for local animal shelter',
      target_amount: 5000,
      saved_amount: 1800,
      status: 'active',
      target_date: '2024-10-31',
      created_at: '2024-07-15',
      members: [
        { id: 1, first_name: 'Sarah', last_name: 'Johnson', email: 'sarah.j@email.com' },
        { id: 3, first_name: 'Emma', last_name: 'Davis', email: 'emma.d@email.com' }
      ]
    }
  ];
};

const mockFetchSocialFeed = async () => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 600));
  
  return [
    {
      id: 1,
      type: 'goal_completed',
      user_name: 'Sarah Johnson',
      goal_name: 'Emergency Fund',
      amount: 5000,
      created_at: '2024-08-04T14:30:00Z',
      likes_count: 5,
      comments_count: 2
    },
    {
      id: 2,
      type: 'contribution',
      user_name: 'Mike Chen',
      goal_name: 'New Car',
      amount: 500,
      created_at: '2024-08-04T12:15:00Z',
      likes_count: 3,
      comments_count: 1
    },
    {
      id: 3,
      type: 'roundup',
      user_name: 'Emma Davis',
      amount: 0.75,
      created_at: '2024-08-04T10:45:00Z',
      likes_count: 2,
      comments_count: 0
    },
    {
      id: 4,
      type: 'group_goal_joined',
      user_name: 'Sarah Johnson',
      goal_name: 'Charity Fundraiser',
      created_at: '2024-08-03T16:20:00Z',
      likes_count: 4,
      comments_count: 3
    },
    {
      id: 5,
      type: 'achievement',
      user_name: 'Mike Chen',
      achievement_name: 'Savings Streak',
      created_at: '2024-08-03T09:30:00Z',
      likes_count: 7,
      comments_count: 5
    }
  ];
};

const mockFetchSocialStats = async () => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 400));
  
  return {
    friendsCount: 3,
    groupGoalsCount: 2,
    totalGroupSavings: 5000
  };
};

export const fetchFriends = createAsyncThunk(
  'social/fetchFriends',
  async (_, { dispatch }) => {
    try {
      dispatch(fetchFriendsStart());
      const friends = await mockFetchFriends();
      dispatch(fetchFriendsSuccess(friends));
      return friends;
    } catch (error) {
      dispatch(fetchFriendsFailure(error.message));
      throw error;
    }
  }
);

export const fetchGroupGoals = createAsyncThunk(
  'social/fetchGroupGoals',
  async (_, { dispatch }) => {
    try {
      const groupGoals = await mockFetchGroupGoals();
      dispatch(fetchGroupGoalsSuccess(groupGoals));
      return groupGoals;
    } catch (error) {
      throw error;
    }
  }
);

export const fetchSocialFeed = createAsyncThunk(
  'social/fetchSocialFeed',
  async (_, { dispatch }) => {
    try {
      const socialFeed = await mockFetchSocialFeed();
      dispatch(fetchSocialFeedSuccess(socialFeed));
      return socialFeed;
    } catch (error) {
      throw error;
    }
  }
);

export const fetchSocialStats = createAsyncThunk(
  'social/fetchSocialStats',
  async (_, { dispatch }) => {
    try {
      const stats = await mockFetchSocialStats();
      dispatch(fetchSocialStatsSuccess(stats));
      return stats;
    } catch (error) {
      throw error;
    }
  }
); 