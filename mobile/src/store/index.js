import { configureStore } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { combineReducers } from 'redux';

// Import slices
import authReducer from './slices/authSlice';
import goalsReducer from './slices/goalsSlice';
import transactionsReducer from './slices/transactionsSlice';
import bankingReducer from './slices/bankingSlice';
import socialReducer from './slices/socialSlice';
import notificationsReducer from './slices/notificationsSlice';
import uiReducer from './slices/uiSlice';

// Root reducer
const rootReducer = combineReducers({
  auth: authReducer,
  goals: goalsReducer,
  transactions: transactionsReducer,
  banking: bankingReducer,
  social: socialReducer,
  notifications: notificationsReducer,
  ui: uiReducer,
});

// Persist configuration
const persistConfig = {
  key: 'root',
  storage: AsyncStorage,
  whitelist: ['auth', 'goals', 'transactions', 'banking', 'social', 'notifications'],
  blacklist: ['ui'], // Don't persist UI state
};

const persistedReducer = persistReducer(persistConfig, rootReducer);

// Configure store
export const store = configureStore({
  reducer: persistedReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: ['persist/PERSIST', 'persist/REHYDRATE'],
      },
    }),
  devTools: __DEV__,
});

export const persistor = persistStore(store);

// Store types for TypeScript (if using .ts extension)
// export type RootState = ReturnType<typeof store.getState>;
// export type AppDispatch = typeof store.dispatch; 