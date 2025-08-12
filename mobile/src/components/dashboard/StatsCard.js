import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useTheme } from '../../theme/ThemeContext';

const StatsCard = ({ 
  title, 
  value, 
  icon, 
  color = null,
  subtitle = null,
  trend = null 
}) => {
  const { theme } = useTheme();
  const cardColor = color || theme.colors.primary;

  return (
    <View style={[
      styles.container,
      { 
        backgroundColor: theme.colors.background,
        borderColor: theme.colors.border,
      }
    ]}>
      <View style={styles.header}>
        <Icon 
          name={icon} 
          size={20} 
          color={cardColor} 
          style={styles.icon}
        />
        <Text style={[styles.title, { color: theme.colors.textSecondary }]}>
          {title}
        </Text>
      </View>
      
      <Text style={[styles.value, { color: theme.colors.textPrimary }]}>
        {value}
      </Text>
      
      {subtitle && (
        <Text style={[styles.subtitle, { color: theme.colors.textTertiary }]}>
          {subtitle}
        </Text>
      )}
      
      {trend && (
        <View style={styles.trendContainer}>
          <Icon 
            name={trend > 0 ? 'trending-up' : 'trending-down'} 
            size={16} 
            color={trend > 0 ? theme.colors.success : theme.colors.error} 
          />
          <Text style={[
            styles.trendText, 
            { color: trend > 0 ? theme.colors.success : theme.colors.error }
          ]}>
            {Math.abs(trend)}%
          </Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '48%',
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  icon: {
    marginRight: 8,
  },
  title: {
    fontSize: 12,
    fontWeight: '500',
    flex: 1,
  },
  value: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 12,
    marginBottom: 8,
  },
  trendContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trendText: {
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 4,
  },
});

export default StatsCard; 