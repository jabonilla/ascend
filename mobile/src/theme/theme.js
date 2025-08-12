export const theme = {
  colors: {
    // Primary colors
    primary: '#4CAF50',
    primaryDark: '#388E3C',
    primaryLight: '#81C784',
    
    // Secondary colors
    secondary: '#FF9800',
    secondaryDark: '#F57C00',
    secondaryLight: '#FFB74D',
    
    // Success colors
    success: '#4CAF50',
    successLight: '#A5D6A7',
    
    // Warning colors
    warning: '#FF9800',
    warningLight: '#FFCC80',
    
    // Error colors
    error: '#F44336',
    errorLight: '#EF9A9A',
    
    // Info colors
    info: '#2196F3',
    infoLight: '#90CAF9',
    
    // Neutral colors
    white: '#FFFFFF',
    black: '#000000',
    gray: '#9E9E9E',
    grayLight: '#F5F5F5',
    grayDark: '#424242',
    grayMedium: '#757575',
    
    // Background colors
    background: '#FFFFFF',
    backgroundSecondary: '#F8F9FA',
    backgroundTertiary: '#E9ECEF',
    
    // Text colors
    textPrimary: '#212121',
    textSecondary: '#757575',
    textTertiary: '#9E9E9E',
    textInverse: '#FFFFFF',
    
    // Border colors
    border: '#E0E0E0',
    borderLight: '#F5F5F5',
    borderDark: '#BDBDBD',
    
    // Shadow colors
    shadow: 'rgba(0, 0, 0, 0.1)',
    shadowDark: 'rgba(0, 0, 0, 0.2)',
    
    // Gradient colors
    gradientStart: '#4CAF50',
    gradientEnd: '#388E3C',
    gradientSecondaryStart: '#FF9800',
    gradientSecondaryEnd: '#F57C00',
  },
  
  typography: {
    // Font families
    fontFamily: {
      regular: 'System',
      medium: 'System',
      bold: 'System',
      light: 'System',
    },
    
    // Font sizes
    fontSize: {
      xs: 10,
      sm: 12,
      md: 14,
      lg: 16,
      xl: 18,
      xxl: 20,
      xxxl: 24,
      display: 32,
      displayLarge: 48,
    },
    
    // Font weights
    fontWeight: {
      light: '300',
      regular: '400',
      medium: '500',
      semibold: '600',
      bold: '700',
      extrabold: '800',
    },
    
    // Line heights
    lineHeight: {
      tight: 1.2,
      normal: 1.4,
      relaxed: 1.6,
      loose: 1.8,
    },
  },
  
  spacing: {
    xs: 4,
    sm: 8,
    md: 16,
    lg: 24,
    xl: 32,
    xxl: 48,
    xxxl: 64,
  },
  
  borderRadius: {
    none: 0,
    sm: 4,
    md: 8,
    lg: 12,
    xl: 16,
    xxl: 24,
    full: 9999,
  },
  
  shadows: {
    none: {
      shadowColor: 'transparent',
      shadowOffset: { width: 0, height: 0 },
      shadowOpacity: 0,
      shadowRadius: 0,
      elevation: 0,
    },
    sm: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.05,
      shadowRadius: 2,
      elevation: 1,
    },
    md: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 2,
    },
    lg: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.15,
      shadowRadius: 8,
      elevation: 4,
    },
    xl: {
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.2,
      shadowRadius: 16,
      elevation: 8,
    },
  },
  
  // Component-specific styles
  components: {
    button: {
      primary: {
        backgroundColor: '#4CAF50',
        color: '#FFFFFF',
        borderRadius: 8,
        paddingVertical: 12,
        paddingHorizontal: 24,
        fontSize: 16,
        fontWeight: '600',
      },
      secondary: {
        backgroundColor: 'transparent',
        color: '#4CAF50',
        borderWidth: 1,
        borderColor: '#4CAF50',
        borderRadius: 8,
        paddingVertical: 12,
        paddingHorizontal: 24,
        fontSize: 16,
        fontWeight: '600',
      },
      outline: {
        backgroundColor: 'transparent',
        color: '#757575',
        borderWidth: 1,
        borderColor: '#E0E0E0',
        borderRadius: 8,
        paddingVertical: 12,
        paddingHorizontal: 24,
        fontSize: 16,
        fontWeight: '500',
      },
    },
    
    card: {
      backgroundColor: '#FFFFFF',
      borderRadius: 12,
      padding: 16,
      marginVertical: 8,
      marginHorizontal: 16,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 2 },
      shadowOpacity: 0.1,
      shadowRadius: 4,
      elevation: 2,
    },
    
    input: {
      backgroundColor: '#FFFFFF',
      borderWidth: 1,
      borderColor: '#E0E0E0',
      borderRadius: 8,
      paddingHorizontal: 16,
      paddingVertical: 12,
      fontSize: 16,
      color: '#212121',
    },
    
    modal: {
      backgroundColor: '#FFFFFF',
      borderRadius: 16,
      margin: 20,
      padding: 24,
      shadowColor: '#000',
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.25,
      shadowRadius: 8,
      elevation: 8,
    },
  },
  
  // Animation durations
  animation: {
    fast: 200,
    normal: 300,
    slow: 500,
  },
  
  // Breakpoints for responsive design
  breakpoints: {
    phone: 0,
    tablet: 768,
    desktop: 1024,
  },
};

export default theme; 