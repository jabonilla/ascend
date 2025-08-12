import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  FlatList,
} from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useSelector, useDispatch } from 'react-redux';

// Components
import TransactionCard from '../../components/transactions/TransactionCard';
import EmptyState from '../../components/common/EmptyState';
import LoadingSpinner from '../../components/common/LoadingSpinner';

// Actions
import { fetchTransactions, fetchRoundupStats } from '../../store/actions/transactionsActions';

const TransactionsScreen = () => {
  const navigation = useNavigation();
  const { colors } = useTheme();
  const dispatch = useDispatch();
  
  const { transactions, loading, error } = useSelector(state => state.transactions);
  const { roundupStats } = useSelector(state => state.transactions);
  
  const [refreshing, setRefreshing] = useState(false);
  const [selectedFilter, setSelectedFilter] = useState('all');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      await Promise.all([
        dispatch(fetchTransactions()),
        dispatch(fetchRoundupStats())
      ]);
    } catch (error) {
      console.error('Error loading transactions:', error);
    }
  };

  const onRefresh = async () => {
    setRefreshing(true);
    await loadData();
    setRefreshing(false);
  };

  const handleTransactionPress = (transaction) => {
    navigation.navigate('TransactionDetail', { transactionId: transaction.id });
  };

  const handleRoundupHistory = () => {
    navigation.navigate('RoundupHistory');
  };

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={[styles.title, { color: colors.text }]}>Transactions</Text>
      <TouchableOpacity
        style={[styles.statsButton, { backgroundColor: colors.primary }]}
        onPress={handleRoundupHistory}
      >
        <Icon name="analytics" size={20} color="white" />
      </TouchableOpacity>
    </View>
  );

  const renderStats = () => {
    if (!roundupStats) return null;

    return (
      <View style={styles.statsContainer}>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            ${roundupStats.totalRoundups?.toFixed(2) || '0.00'}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Total Roundups
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            {roundupStats.totalTransactions || 0}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Transactions
          </Text>
        </View>
        <View style={[styles.statCard, { backgroundColor: colors.card }]}>
          <Text style={[styles.statNumber, { color: colors.primary }]}>
            ${roundupStats.averageRoundup?.toFixed(2) || '0.00'}
          </Text>
          <Text style={[styles.statLabel, { color: colors.textSecondary }]}>
            Avg Roundup
          </Text>
        </View>
      </View>
    );
  };

  const renderFilters = () => (
    <View style={styles.filtersContainer}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        {[
          { key: 'all', label: 'All' },
          { key: 'roundups', label: 'Roundups' },
          { key: 'contributions', label: 'Contributions' },
          { key: 'purchases', label: 'Purchases' },
        ].map((filter) => (
          <TouchableOpacity
            key={filter.key}
            style={[
              styles.filterButton,
              {
                backgroundColor: selectedFilter === filter.key ? colors.primary : colors.card,
              },
            ]}
            onPress={() => setSelectedFilter(filter.key)}
          >
            <Text
              style={[
                styles.filterText,
                {
                  color: selectedFilter === filter.key ? 'white' : colors.text,
                },
              ]}
            >
              {filter.label}
            </Text>
          </TouchableOpacity>
        ))}
      </ScrollView>
    </View>
  );

  const getFilteredTransactions = () => {
    if (selectedFilter === 'all') return transactions;
    
    return transactions.filter(transaction => {
      switch (selectedFilter) {
        case 'roundups':
          return transaction.roundup_amount > 0;
        case 'contributions':
          return transaction.type === 'contribution';
        case 'purchases':
          return transaction.type === 'purchase';
        default:
          return true;
      }
    });
  };

  const renderTransactionsList = () => {
    if (loading && !refreshing) {
      return <LoadingSpinner />;
    }

    const filteredTransactions = getFilteredTransactions();

    if (filteredTransactions.length === 0) {
      return (
        <EmptyState
          icon="receipt"
          title="No Transactions"
          subtitle={selectedFilter === 'all' 
            ? "Your transactions will appear here once you connect your bank account"
            : `No ${selectedFilter} transactions found`
          }
          actionText="Connect Bank"
          onAction={() => navigation.navigate('ConnectBank')}
        />
      );
    }

    return (
      <FlatList
        data={filteredTransactions}
        keyExtractor={(item) => item.id.toString()}
        renderItem={({ item }) => (
          <TransactionCard
            transaction={item}
            onPress={() => handleTransactionPress(item)}
          />
        )}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.transactionsList}
      />
    );
  };

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      {renderHeader()}
      <ScrollView
        style={styles.scrollView}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        showsVerticalScrollIndicator={false}
      >
        {renderStats()}
        {renderFilters()}
        {renderTransactionsList()}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 60,
    paddingBottom: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  statsButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollView: {
    flex: 1,
  },
  statsContainer: {
    flexDirection: 'row',
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  statCard: {
    flex: 1,
    marginHorizontal: 5,
    padding: 15,
    borderRadius: 12,
    alignItems: 'center',
  },
  statNumber: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 12,
    textAlign: 'center',
  },
  filtersContainer: {
    paddingHorizontal: 20,
    marginBottom: 20,
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    marginRight: 10,
  },
  filterText: {
    fontSize: 14,
    fontWeight: '500',
  },
  transactionsList: {
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
});

export default TransactionsScreen; 