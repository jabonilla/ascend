import api from './index';

export const authAPI = {
  // Login user
  login: (credentials) => {
    return api.post('/auth/login', credentials);
  },

  // Register user
  register: (userData) => {
    return api.post('/auth/register', userData);
  },

  // Logout user
  logout: () => {
    return api.post('/auth/logout');
  },

  // Refresh token
  refreshToken: (refreshToken) => {
    return api.post('/auth/refresh', { refreshToken });
  },

  // Verify email
  verifyEmail: (token) => {
    return api.get(`/auth/verify-email/${token}`);
  },

  // Forgot password
  forgotPassword: (email) => {
    return api.post('/auth/forgot-password', { email });
  },

  // Reset password
  resetPassword: (token, password) => {
    return api.post('/auth/reset-password', { token, password });
  },

  // Get user profile
  getProfile: () => {
    return api.get('/users/profile');
  },

  // Update user profile
  updateProfile: (profileData) => {
    return api.put('/users/profile', profileData);
  },

  // Delete account
  deleteAccount: () => {
    return api.delete('/users/account');
  },

  // Change password
  changePassword: (currentPassword, newPassword) => {
    return api.post('/users/change-password', {
      currentPassword,
      newPassword,
    });
  },

  // Enable 2FA
  enable2FA: () => {
    return api.post('/users/2fa/enable');
  },

  // Disable 2FA
  disable2FA: (code) => {
    return api.post('/users/2fa/disable', { code });
  },

  // Verify 2FA
  verify2FA: (code) => {
    return api.post('/users/2fa/verify', { code });
  },
}; 