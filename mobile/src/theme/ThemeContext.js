import React, { createContext, useContext, useState } from 'react';

// Color palette
const colors = {
  primary: '#4CAF50',
  primaryDark: '#388E3C',
  primaryLight: '#81C784',
  secondary: '#FF9800',
  secondaryDark: '#F57C00',
  secondaryLight: '#FFB74D',
  success: '#4CAF50',
  warning: '#FF9800',
  error: '#F44336',
  info: '#2196F3',
  
  // Background colors
  background: '#FFFFFF',
  backgroundSecondary: '#F5F5F5',
  backgroundTertiary: '#EEEEEE',
  
  // Text colors
  textPrimary: '#212121',
  textSecondary: '#757575',
  textTertiary: '#9E9E9E',
  textInverse: '#FFFFFF',
  
  // Border colors
  border: '#E0E0E0',
  borderLight: '#F5F5F5',
  
  // Status colors
  goalActive: '#4CAF50',
  goalPaused: '#FF9800',
  goalCompleted: '#2196F3',
  goalOverdue: '#F44336',
  
  // Social colors
  friendOnline: '#4CAF50',
  friendOffline: '#9E9E9E',
  groupGoal: '#FF9800',
  
  // Transaction colors
  income: '#4CAF50',
  expense: '#F44336',
  roundup: '#2196F3',
};

// Typography
const typography = {
  fontFamily: {
    regular: 'System',
    medium: 'System',
    bold: 'System',
    light: 'System',
  },
  fontSize: {
    xs: 10,
    sm: 12,
    md: 14,
    lg: 16,
    xl: 18,
    xxl: 20,
    xxxl: 24,
    title: 28,
    largeTitle: 32,
  },
  fontWeight: {
    light: '300',
    regular: '400',
    medium: '500',
    semibold: '600',
    bold: '700',
  },
  lineHeight: {
    tight: 1.2,
    normal: 1.4,
    relaxed: 1.6,
  },
};

// Spacing
const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
  xxxl: 64,
};

// Border radius
const borderRadius = {
  xs: 2,
  sm: 4,
  md: 8,
  lg: 12,
  xl: 16,
  xxl: 24,
  round: 50,
};

// Shadows
const shadows = {
  sm: {
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.18,
    shadowRadius: 1.0,
    elevation: 1,
  },
  md: {
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  lg: {
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.30,
    shadowRadius: 4.65,
    elevation: 8,
  },
};

// Theme object
const theme = {
  colors,
  typography,
  spacing,
  borderRadius,
  shadows,
};

// Dark theme
const darkTheme = {
  ...theme,
  colors: {
    ...colors,
    background: '#121212',
    backgroundSecondary: '#1E1E1E',
    backgroundTertiary: '#2D2D2D',
    textPrimary: '#FFFFFF',
    textSecondary: '#B0B0B0',
    textTertiary: '#808080',
    border: '#333333',
    borderLight: '#2D2D2D',
  },
};

// Theme context
const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [isDarkMode, setIsDarkMode] = useState(false);
  
  const currentTheme = isDarkMode ? darkTheme : theme;
  
  const toggleTheme = () => {
    setIsDarkMode(!isDarkMode);
  };
  
  const value = {
    theme: currentTheme,
    isDarkMode,
    toggleTheme,
  };
  
  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};

export default theme; 