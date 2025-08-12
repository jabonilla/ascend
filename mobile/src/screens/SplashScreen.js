import React from 'react';
import { View, Text, StyleSheet, ActivityIndicator } from 'react-native';
import { useTheme } from '../theme/ThemeContext';

const SplashScreen = () => {
  const { theme } = useTheme();

  return (
    <View style={[styles.container, { backgroundColor: theme.colors.primary }]}>
      <View style={styles.content}>
        <Text style={[styles.title, { color: theme.colors.white }]}>
          RoundUp
        </Text>
        <Text style={[styles.subtitle, { color: theme.colors.white }]}>
          Smart Savings
        </Text>
      </View>
      
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={theme.colors.white} />
        <Text style={[styles.loadingText, { color: theme.colors.white }]}>
          Loading...
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 60,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  title: {
    fontSize: 48,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 18,
    opacity: 0.9,
  },
  loadingContainer: {
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    opacity: 0.8,
  },
});

export default SplashScreen; 