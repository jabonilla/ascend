import { createSlice } from '@reduxjs/toolkit';

const initialState = {
  goals: [
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
  ],
  loading: false,
  error: null
};

const goalsSlice = createSlice({
  name: 'goals',
  initialState,
  reducers: {
    fetchGoalsStart: (state) => {
      state.loading = true;
      state.error = null;
    },
    fetchGoalsSuccess: (state, action) => {
      state.loading = false;
      state.goals = action.payload;
    },
    fetchGoalsFailure: (state, action) => {
      state.loading = false;
      state.error = action.payload;
    },
    createGoal: (state, action) => {
      state.goals.push(action.payload);
    },
    updateGoal: (state, action) => {
      const index = state.goals.findIndex(goal => goal.id === action.payload.id);
      if (index !== -1) {
        state.goals[index] = action.payload;
      }
    },
    deleteGoal: (state, action) => {
      state.goals = state.goals.filter(goal => goal.id !== action.payload);
    }
  }
});

export const {
  fetchGoalsStart,
  fetchGoalsSuccess,
  fetchGoalsFailure,
  createGoal,
  updateGoal,
  deleteGoal
} = goalsSlice.actions;

export default goalsSlice.reducer; 