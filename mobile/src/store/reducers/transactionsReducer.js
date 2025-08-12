import { createSlice } from '@reduxjs/toolkit';

const initialState = {
  transactions: [
    {
      id: 1,
      merchant_name: 'Starbucks',
      amount: -4.75,
      roundup_amount: 0.25,
      type: 'purchase',
      category: 'food',
      date: '2024-08-04T10:30:00Z',
      description: 'Coffee and pastry',
      goal_allocations: [
        { goal_name: 'Vacation to Hawaii', amount: 0.25 }
      ]
    },
    {
      id: 2,
      merchant_name: 'Amazon',
      amount: -89.99,
      roundup_amount: 0.01,
      type: 'purchase',
      category: 'shopping',
      date: '2024-08-03T15:45:00Z',
      description: 'Wireless headphones',
      goal_allocations: [
        { goal_name: 'New Laptop', amount: 0.01 }
      ]
    },
    {
      id: 3,
      merchant_name: 'Manual Contribution',
      amount: 100,
      roundup_amount: 0,
      type: 'contribution',
      category: 'savings',
      date: '2024-08-02T09:00:00Z',
      description: 'Weekly savings contribution',
      goal_allocations: [
        { goal_name: 'Emergency Fund', amount: 100 }
      ]
    },
    {
      id: 4,
      merchant_name: 'Target',
      amount: -45.67,
      roundup_amount: 0.33,
      type: 'purchase',
      category: 'shopping',
      date: '2024-08-01T14:20:00Z',
      description: 'Household items',
      goal_allocations: [
        { goal_name: 'Vacation to Hawaii', amount: 0.33 }
      ]
    },
    {
      id: 5,
      merchant_name: 'Uber',
      amount: -23.50,
      roundup_amount: 0.50,
      type: 'purchase',
      category: 'transportation',
      date: '2024-07-31T18:15:00Z',
      description: 'Ride to dinner',
      goal_allocations: [
        { goal_name: 'New Laptop', amount: 0.50 }
      ]
    }
  ],
  roundupStats: {
    totalRoundups: 1.09,
    totalTransactions: 5,
    averageRoundup: 0.22
  },
  loading: false,
  error: null
};

const transactionsSlice = createSlice({
  name: 'transactions',
  initialState,
  reducers: {
    fetchTransactionsStart: (state) => {
      state.loading = true;
      state.error = null;
    },
    fetchTransactionsSuccess: (state, action) => {
      state.loading = false;
      state.transactions = action.payload;
    },
    fetchTransactionsFailure: (state, action) => {
      state.loading = false;
      state.error = action.payload;
    },
    fetchRoundupStatsSuccess: (state, action) => {
      state.roundupStats = action.payload;
    }
  }
});

export const {
  fetchTransactionsStart,
  fetchTransactionsSuccess,
  fetchTransactionsFailure,
  fetchRoundupStatsSuccess
} = transactionsSlice.actions;

export default transactionsSlice.reducer; 