import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';

const TransactionCard = ({ transaction, onPress }) => {
  const { colors } = useTheme();

  const formatAmount = (amount) => {
    return `$${Math.abs(amount).toFixed(2)}`;
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const getTransactionIcon = (type) => {
    switch (type) {
      case 'purchase':
        return 'shopping-cart';
      case 'contribution':
        return 'account-balance-wallet';
      case 'roundup':
        return 'trending-up';
      case 'transfer':
        return 'swap-horiz';
      default:
        return 'receipt';
    }
  };

  const getTransactionColor = (type) => {
    switch (type) {
      case 'purchase':
        return colors.error;
      case 'contribution':
        return colors.success;
      case 'roundup':
        return colors.primary;
      case 'transfer':
        return colors.warning;
      default:
        return colors.textSecondary;
    }
  };

  const renderRoundupInfo = () => {
    if (!transaction.roundup_amount || transaction.roundup_amount <= 0) {
      return null;
    }

    return (
      <View style={styles.roundupContainer}>
        <Icon name="trending-up" size={16} color={colors.primary} />
        <Text style={[styles.roundupText, { color: colors.primary }]}>
          +${transaction.roundup_amount.toFixed(2)} roundup
        </Text>
      </View>
    );
  };

  const renderGoalAllocation = () => {
    if (!transaction.goal_allocations || transaction.goal_allocations.length === 0) {
      return null;
    }

    return (
      <View style={styles.goalAllocationContainer}>
        <Text style={[styles.goalAllocationLabel, { color: colors.textSecondary }]}>
          Allocated to:
        </Text>
        {transaction.goal_allocations.map((allocation, index) => (
          <Text key={index} style={[styles.goalAllocationText, { color: colors.primary }]}>
            {allocation.goal_name} (${allocation.amount.toFixed(2)})
          </Text>
        ))}
      </View>
    );
  };

  return (
    <TouchableOpacity
      style={[styles.container, { backgroundColor: colors.card }]}
      onPress={onPress}
      activeOpacity={0.7}
    >
      <View style={styles.mainContent}>
        <View style={styles.leftSection}>
          <View style={[styles.iconContainer, { backgroundColor: getTransactionColor(transaction.type) + '20' }]}>
            <Icon 
              name={getTransactionIcon(transaction.type)} 
              size={20} 
              color={getTransactionColor(transaction.type)} 
            />
          </View>
          <View style={styles.transactionInfo}>
            <Text style={[styles.merchantName, { color: colors.text }]} numberOfLines={1}>
              {transaction.merchant_name || transaction.description || 'Transaction'}
            </Text>
            <Text style={[styles.transactionDate, { color: colors.textSecondary }]}>
              {formatDate(transaction.date)}
            </Text>
            {renderRoundupInfo()}
            {renderGoalAllocation()}
          </View>
        </View>
        
        <View style={styles.rightSection}>
          <Text style={[
            styles.amount,
            { 
              color: transaction.amount < 0 ? colors.error : colors.success 
            }
          ]}>
            {transaction.amount < 0 ? '-' : '+'}{formatAmount(transaction.amount)}
          </Text>
          {transaction.category && (
            <Text style={[styles.category, { color: colors.textSecondary }]}>
              {transaction.category}
            </Text>
          )}
        </View>
      </View>
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 12,
    borderRadius: 12,
    padding: 16,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  mainContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  leftSection: {
    flex: 1,
    flexDirection: 'row',
    marginRight: 12,
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  transactionInfo: {
    flex: 1,
  },
  merchantName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  transactionDate: {
    fontSize: 12,
    marginBottom: 4,
  },
  roundupContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  roundupText: {
    fontSize: 12,
    fontWeight: '500',
    marginLeft: 4,
  },
  goalAllocationContainer: {
    marginTop: 4,
  },
  goalAllocationLabel: {
    fontSize: 11,
    marginBottom: 2,
  },
  goalAllocationText: {
    fontSize: 11,
    fontWeight: '500',
  },
  rightSection: {
    alignItems: 'flex-end',
  },
  amount: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 2,
  },
  category: {
    fontSize: 11,
    textAlign: 'right',
  },
});

export default TransactionCard; 