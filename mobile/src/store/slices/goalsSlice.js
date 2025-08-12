import { createSlice, createAsyncThunk } from '@reduxjs/toolkit';
import { goalsAPI } from '../../services/api/goalsAPI';

// Async thunks
export const fetchGoals = createAsyncThunk(
  'goals/fetchGoals',
  async (params, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.getGoals(params);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to fetch goals');
    }
  }
);

export const createGoal = createAsyncThunk(
  'goals/createGoal',
  async (goalData, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.createGoal(goalData);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to create goal');
    }
  }
);

export const updateGoal = createAsyncThunk(
  'goals/updateGoal',
  async ({ id, goalData }, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.updateGoal(id, goalData);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to update goal');
    }
  }
);

export const deleteGoal = createAsyncThunk(
  'goals/deleteGoal',
  async (id, { rejectWithValue }) => {
    try {
      await goalsAPI.deleteGoal(id);
      return id;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to delete goal');
    }
  }
);

export const contributeToGoal = createAsyncThunk(
  'goals/contributeToGoal',
  async ({ id, amount, message }, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.contributeToGoal(id, { amount, message });
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to contribute to goal');
    }
  }
);

export const toggleGoalStatus = createAsyncThunk(
  'goals/toggleGoalStatus',
  async (id, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.toggleGoalStatus(id);
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to toggle goal status');
    }
  }
);

export const fetchGoalStats = createAsyncThunk(
  'goals/fetchGoalStats',
  async (_, { rejectWithValue }) => {
    try {
      const response = await goalsAPI.getGoalStats();
      return response.data;
    } catch (error) {
      return rejectWithValue(error.response?.data || 'Failed to fetch goal stats');
    }
  }
);

const initialState = {
  goals: [],
  selectedGoal: null,
  stats: null,
  isLoading: false,
  error: null,
  filters: {
    status: 'all',
    category: 'all',
    search: '',
  },
  pagination: {
    page: 1,
    limit: 20,
    total: 0,
    hasMore: true,
  },
};

const goalsSlice = createSlice({
  name: 'goals',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    setSelectedGoal: (state, action) => {
      state.selectedGoal = action.payload;
    },
    clearSelectedGoal: (state) => {
      state.selectedGoal = null;
    },
    setFilters: (state, action) => {
      state.filters = { ...state.filters, ...action.payload };
      state.pagination.page = 1; // Reset to first page when filters change
    },
    clearFilters: (state) => {
      state.filters = {
        status: 'all',
        category: 'all',
        search: '',
      };
      state.pagination.page = 1;
    },
    updateGoalProgress: (state, action) => {
      const { goalId, progress } = action.payload;
      const goal = state.goals.find(g => g.id === goalId);
      if (goal) {
        goal.current_amount = progress.current_amount;
        goal.progress_percentage = progress.progress_percentage;
        goal.is_completed = progress.is_completed;
      }
      if (state.selectedGoal && state.selectedGoal.id === goalId) {
        state.selectedGoal = { ...state.selectedGoal, ...progress };
      }
    },
    addContribution: (state, action) => {
      const { goalId, contribution } = action.payload;
      const goal = state.goals.find(g => g.id === goalId);
      if (goal) {
        goal.contributions = goal.contributions || [];
        goal.contributions.unshift(contribution);
        goal.current_amount += contribution.amount;
        goal.progress_percentage = (goal.current_amount / goal.target_amount) * 100;
        goal.is_completed = goal.current_amount >= goal.target_amount;
      }
    },
  },
  extraReducers: (builder) => {
    // Fetch Goals
    builder
      .addCase(fetchGoals.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(fetchGoals.fulfilled, (state, action) => {
        state.isLoading = false;
        const { goals, pagination } = action.payload;
        if (state.pagination.page === 1) {
          state.goals = goals;
        } else {
          state.goals = [...state.goals, ...goals];
        }
        state.pagination = pagination;
      })
      .addCase(fetchGoals.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Create Goal
    builder
      .addCase(createGoal.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(createGoal.fulfilled, (state, action) => {
        state.isLoading = false;
        state.goals.unshift(action.payload);
        state.pagination.total += 1;
      })
      .addCase(createGoal.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Update Goal
    builder
      .addCase(updateGoal.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(updateGoal.fulfilled, (state, action) => {
        state.isLoading = false;
        const updatedGoal = action.payload;
        const index = state.goals.findIndex(g => g.id === updatedGoal.id);
        if (index !== -1) {
          state.goals[index] = updatedGoal;
        }
        if (state.selectedGoal && state.selectedGoal.id === updatedGoal.id) {
          state.selectedGoal = updatedGoal;
        }
      })
      .addCase(updateGoal.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Delete Goal
    builder
      .addCase(deleteGoal.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(deleteGoal.fulfilled, (state, action) => {
        state.isLoading = false;
        const deletedId = action.payload;
        state.goals = state.goals.filter(g => g.id !== deletedId);
        if (state.selectedGoal && state.selectedGoal.id === deletedId) {
          state.selectedGoal = null;
        }
        state.pagination.total -= 1;
      })
      .addCase(deleteGoal.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Contribute to Goal
    builder
      .addCase(contributeToGoal.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(contributeToGoal.fulfilled, (state, action) => {
        state.isLoading = false;
        const { goal, contribution } = action.payload;
        const goalIndex = state.goals.findIndex(g => g.id === goal.id);
        if (goalIndex !== -1) {
          state.goals[goalIndex] = goal;
        }
        if (state.selectedGoal && state.selectedGoal.id === goal.id) {
          state.selectedGoal = goal;
        }
      })
      .addCase(contributeToGoal.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Toggle Goal Status
    builder
      .addCase(toggleGoalStatus.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(toggleGoalStatus.fulfilled, (state, action) => {
        state.isLoading = false;
        const updatedGoal = action.payload;
        const index = state.goals.findIndex(g => g.id === updatedGoal.id);
        if (index !== -1) {
          state.goals[index] = updatedGoal;
        }
        if (state.selectedGoal && state.selectedGoal.id === updatedGoal.id) {
          state.selectedGoal = updatedGoal;
        }
      })
      .addCase(toggleGoalStatus.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });

    // Fetch Goal Stats
    builder
      .addCase(fetchGoalStats.pending, (state) => {
        state.isLoading = true;
        state.error = null;
      })
      .addCase(fetchGoalStats.fulfilled, (state, action) => {
        state.isLoading = false;
        state.stats = action.payload;
      })
      .addCase(fetchGoalStats.rejected, (state, action) => {
        state.isLoading = false;
        state.error = action.payload;
      });
  },
});

export const {
  clearError,
  setSelectedGoal,
  clearSelectedGoal,
  setFilters,
  clearFilters,
  updateGoalProgress,
  addContribution,
} = goalsSlice.actions;

export default goalsSlice.reducer; 