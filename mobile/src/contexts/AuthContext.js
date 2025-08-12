import React, { createContext, useContext, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { 
  login, 
  register, 
  logout, 
  refreshToken, 
  verifyEmail,
  setUser,
  setToken,
  setRefreshToken,
  setOnboardingComplete,
  updateUserProfile,
} from '../store/slices/authSlice';
import { authAPI } from '../services/api/authAPI';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const dispatch = useDispatch();
  const { 
    user, 
    token, 
    refreshToken: refreshTokenValue, 
    isAuthenticated, 
    isLoading,
    isEmailVerified,
    isOnboardingComplete,
  } = useSelector((state) => state.auth);

  // Initialize auth state on app start
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        const storedToken = await AsyncStorage.getItem('token');
        const storedRefreshToken = await AsyncStorage.getItem('refreshToken');
        const storedUser = await AsyncStorage.getItem('user');
        const storedOnboarding = await AsyncStorage.getItem('onboardingComplete');

        if (storedToken && storedUser) {
          const userData = JSON.parse(storedUser);
          dispatch(setUser(userData));
          dispatch(setToken(storedToken));
          if (storedRefreshToken) {
            dispatch(setRefreshToken(storedRefreshToken));
          }
        }

        if (storedOnboarding === 'true') {
          dispatch(setOnboardingComplete(true));
        }
      } catch (error) {
        console.error('Error initializing auth:', error);
      }
    };

    initializeAuth();
  }, [dispatch]);

  // Auto-refresh token when it's about to expire
  useEffect(() => {
    if (token && refreshTokenValue) {
      const tokenExpiry = getTokenExpiry(token);
      const now = Date.now();
      const timeUntilExpiry = tokenExpiry - now;

      // Refresh token 5 minutes before expiry
      if (timeUntilExpiry > 0 && timeUntilExpiry < 300000) {
        dispatch(refreshToken());
      }
    }
  }, [token, refreshTokenValue, dispatch]);

  // Helper function to get token expiry
  const getTokenExpiry = (token) => {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp * 1000; // Convert to milliseconds
    } catch (error) {
      return Date.now() + 3600000; // Default 1 hour
    }
  };

  // Login function
  const handleLogin = async (credentials) => {
    try {
      const result = await dispatch(login(credentials)).unwrap();
      
      // Store user data in AsyncStorage
      await AsyncStorage.setItem('user', JSON.stringify(result.user));
      
      return result;
    } catch (error) {
      throw error;
    }
  };

  // Register function
  const handleRegister = async (userData) => {
    try {
      const result = await dispatch(register(userData)).unwrap();
      
      // Store user data in AsyncStorage
      await AsyncStorage.setItem('user', JSON.stringify(result.user));
      
      return result;
    } catch (error) {
      throw error;
    }
  };

  // Logout function
  const handleLogout = async () => {
    try {
      await dispatch(logout()).unwrap();
      
      // Clear AsyncStorage
      await AsyncStorage.multiRemove([
        'token',
        'refreshToken',
        'user',
      ]);
    } catch (error) {
      console.error('Logout error:', error);
      // Clear storage even if logout fails
      await AsyncStorage.multiRemove([
        'token',
        'refreshToken',
        'user',
      ]);
    }
  };

  // Verify email function
  const handleVerifyEmail = async (token) => {
    try {
      const result = await dispatch(verifyEmail(token)).unwrap();
      return result;
    } catch (error) {
      throw error;
    }
  };

  // Update user profile
  const handleUpdateProfile = async (profileData) => {
    try {
      const result = await authAPI.updateProfile(profileData);
      dispatch(updateUserProfile(result.data.data));
      
      // Update stored user data
      const updatedUser = { ...user, ...result.data.data };
      await AsyncStorage.setItem('user', JSON.stringify(updatedUser));
      
      return result.data;
    } catch (error) {
      throw error;
    }
  };

  // Complete onboarding
  const completeOnboarding = async () => {
    try {
      await AsyncStorage.setItem('onboardingComplete', 'true');
      dispatch(setOnboardingComplete(true));
    } catch (error) {
      console.error('Error completing onboarding:', error);
    }
  };

  // Check if user needs to complete profile
  const needsProfileCompletion = () => {
    if (!user) return false;
    
    return !user.first_name || 
           !user.last_name || 
           !user.email_verified ||
           !user.phone_number;
  };

  // Check if user needs to link bank account
  const needsBankLinking = () => {
    if (!user) return false;
    
    return !user.primary_account_id;
  };

  const value = {
    user,
    token,
    isAuthenticated,
    isLoading,
    isEmailVerified,
    isOnboardingComplete,
    login: handleLogin,
    register: handleRegister,
    logout: handleLogout,
    verifyEmail: handleVerifyEmail,
    updateProfile: handleUpdateProfile,
    completeOnboarding,
    needsProfileCompletion,
    needsBankLinking,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}; 