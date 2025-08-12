import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useTheme } from '../../theme/ThemeContext';

const QuickActionButton = ({ 
  title, 
  icon, 
  onPress, 
  color = null,
  disabled = false 
}) => {
  const { theme } = useTheme();
  const buttonColor = color || theme.colors.primary;
  const disabledColor = theme.colors.textTertiary;

  return (
    <TouchableOpacity
      style={[
        styles.container,
        { 
          backgroundColor: disabled ? disabledColor : buttonColor,
          opacity: disabled ? 0.6 : 1,
        }
      ]}
      onPress={onPress}
      disabled={disabled}
      activeOpacity={0.8}
    >
      <Icon 
        name={icon} 
        size={24} 
        color={theme.colors.white} 
        style={styles.icon}
      />
      <Text style={[styles.title, { color: theme.colors.white }]}>
        {title}
      </Text>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '48%',
    aspectRatio: 1,
    borderRadius: 12,
    padding: 16,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  icon: {
    marginBottom: 8,
  },
  title: {
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
});

export default QuickActionButton; 