import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useTheme } from '../../theme/ThemeContext';

const EmptyState = ({ 
  icon = 'info', 
  title, 
  message, 
  actionText, 
  onAction,
  iconSize = 64,
  iconColor = null 
}) => {
  const { theme } = useTheme();
  const defaultIconColor = iconColor || theme.colors.textTertiary;

  return (
    <View style={styles.container}>
      <Icon 
        name={icon} 
        size={iconSize} 
        color={defaultIconColor} 
        style={styles.icon}
      />
      <Text style={[styles.title, { color: theme.colors.textPrimary }]}>
        {title}
      </Text>
      <Text style={[styles.message, { color: theme.colors.textSecondary }]}>
        {message}
      </Text>
      {actionText && onAction && (
        <TouchableOpacity 
          style={[styles.actionButton, { backgroundColor: theme.colors.primary }]}
          onPress={onAction}
        >
          <Text style={[styles.actionText, { color: theme.colors.white }]}>
            {actionText}
          </Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 32,
    paddingVertical: 48,
  },
  icon: {
    marginBottom: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 8,
  },
  message: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
    marginBottom: 24,
  },
  actionButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 120,
  },
  actionText: {
    fontSize: 16,
    fontWeight: '600',
    textAlign: 'center',
  },
});

export default EmptyState; 