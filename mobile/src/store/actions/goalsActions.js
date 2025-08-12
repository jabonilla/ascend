import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchGoalsStart, fetchGoalsSuccess, fetchGoalsFailure } from '../reducers/goalsReducer';

// Mock API call
const mockFetchGoals = async () => {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  return [
    {
      id: 1,
      name: 'Vacation to Hawaii',
      description: 'Saving for a dream vacation to Hawaii',
      target_amount: 5000,
      saved_amount: 1250,
      status: 'active',
      category: 'travel',
      target_date: '2024-12-31',
      created_at: '2024-01-15',
      updated_at: '2024-08-04'
    },
    {
      id: 2,
      name: 'New Laptop',
      description: 'MacBook Pro for work and development',
      target_amount: 2500,
      saved_amount: 1800,
      status: 'active',
      category: 'technology',
      target_date: '2024-10-15',
      created_at: '2024-02-01',
      updated_at: '2024-08-04'
    },
    {
      id: 3,
      name: 'Emergency Fund',
      description: 'Building a 6-month emergency fund',
      target_amount: 15000,
      saved_amount: 8500,
      status: 'active',
      category: 'emergency',
      target_date: '2025-06-30',
      created_at: '2024-01-01',
      updated_at: '2024-08-04'
    }
  ];
};

export const fetchGoals = createAsyncThunk(
  'goals/fetchGoals',
  async (_, { dispatch }) => {
    try {
      dispatch(fetchGoalsStart());
      const goals = await mockFetchGoals();
      dispatch(fetchGoalsSuccess(goals));
      return goals;
    } catch (error) {
      dispatch(fetchGoalsFailure(error.message));
      throw error;
    }
  }
);

export const createGoal = createAsyncThunk(
  'goals/createGoal',
  async (goalData, { dispatch }) => {
    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 500));
      
      const newGoal = {
        id: Date.now(),
        ...goalData,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };
      
      return newGoal;
    } catch (error) {
      throw error;
    }
  }
); 