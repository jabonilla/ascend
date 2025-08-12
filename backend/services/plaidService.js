const { Configuration, PlaidApi, PlaidEnvironments } = require('plaid');
const { db } = require('../config/database');
const logger = require('../utils/logger');

// Initialize Plaid client
const configuration = new Configuration({
  basePath: PlaidEnvironments[process.env.PLAID_ENV || 'sandbox'],
  baseOptions: {
    headers: {
      'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
      'PLAID-SECRET': process.env.PLAID_SECRET,
    },
  },
});

const plaidClient = new PlaidApi(configuration);

// Create link token for Plaid Link
const createLinkToken = async (userId) => {
  try {
    const request = {
      user: { client_user_id: userId },
      client_name: 'RoundUp Savings',
      products: ['auth', 'transactions'],
      country_codes: ['US'],
      language: 'en',
      account_filters: {
        depository: {
          account_subtypes: ['checking', 'savings']
        }
      }
    };

    const response = await plaidClient.linkTokenCreate(request);
    
    logger.info(`Created link token for user ${userId}`);
    
    return {
      success: true,
      data: {
        link_token: response.data.link_token,
        expiration: response.data.expiration
      }
    };
  } catch (error) {
    logger.error('Error creating link token:', error);
    return {
      success: false,
      error: 'Failed to create link token'
    };
  }
};

// Exchange public token for access token
const exchangePublicToken = async (publicToken, userId) => {
  try {
    const request = {
      public_token: publicToken
    };

    const response = await plaidClient.itemPublicTokenExchange(request);
    const accessToken = response.data.access_token;
    const itemId = response.data.item_id;

    // Store the access token securely (in production, encrypt this)
    await db('bank_accounts')
      .insert({
        user_id: userId,
        plaid_item_id: itemId,
        access_token: accessToken, // In production, encrypt this
        is_active: true
      });

    logger.info(`Exchanged public token for user ${userId}, item ${itemId}`);

    return {
      success: true,
      data: {
        item_id: itemId,
        access_token: accessToken
      }
    };
  } catch (error) {
    logger.error('Error exchanging public token:', error);
    return {
      success: false,
      error: 'Failed to exchange public token'
    };
  }
};

// Get accounts for a user
const getAccounts = async (userId) => {
  try {
    const bankAccounts = await db('bank_accounts')
      .where('user_id', userId)
      .where('is_active', true)
      .select('*');

    const accounts = [];

    for (const bankAccount of bankAccounts) {
      try {
        const request = {
          access_token: bankAccount.access_token
        };

        const response = await plaidClient.accountsGet(request);
        
        const accountData = response.data.accounts.map(account => ({
          id: account.account_id,
          name: account.name,
          mask: account.mask,
          type: account.type,
          subtype: account.subtype,
          current_balance: account.balances.current,
          available_balance: account.balances.available,
          institution_name: bankAccount.institution_name,
          is_primary: bankAccount.is_primary
        }));

        accounts.push(...accountData);
      } catch (error) {
        logger.error(`Error fetching accounts for item ${bankAccount.plaid_item_id}:`, error);
        // Continue with other accounts even if one fails
      }
    }

    logger.info(`Retrieved ${accounts.length} accounts for user ${userId}`);

    return {
      success: true,
      data: {
        accounts
      }
    };
  } catch (error) {
    logger.error('Error getting accounts:', error);
    return {
      success: false,
      error: 'Failed to retrieve accounts'
    };
  }
};

// Get transactions for a user
const getTransactions = async (userId, startDate, endDate, accountIds = null) => {
  try {
    const bankAccounts = await db('bank_accounts')
      .where('user_id', userId)
      .where('is_active', true)
      .select('*');

    const allTransactions = [];

    for (const bankAccount of bankAccounts) {
      try {
        const request = {
          access_token: bankAccount.access_token,
          start_date: startDate,
          end_date: endDate,
          options: {
            account_ids: accountIds
          }
        };

        const response = await plaidClient.transactionsGet(request);
        
        const transactions = response.data.transactions.map(transaction => ({
          plaid_transaction_id: transaction.transaction_id,
          account_id: transaction.account_id,
          amount: transaction.amount,
          merchant_name: transaction.merchant_name,
          merchant_id: transaction.merchant_id,
          category: transaction.category?.join(' > ') || 'Uncategorized',
          category_id: transaction.category_id,
          payment_channel: transaction.payment_channel,
          pending: transaction.pending,
          date: transaction.date,
          authorized_date: transaction.authorized_date,
          user_id: userId,
          bank_account_id: bankAccount.id
        }));

        allTransactions.push(...transactions);
      } catch (error) {
        logger.error(`Error fetching transactions for item ${bankAccount.plaid_item_id}:`, error);
        // Continue with other accounts even if one fails
      }
    }

    logger.info(`Retrieved ${allTransactions.length} transactions for user ${userId}`);

    return {
      success: true,
      data: {
        transactions: allTransactions
      }
    };
  } catch (error) {
    logger.error('Error getting transactions:', error);
    return {
      success: false,
      error: 'Failed to retrieve transactions'
    };
  }
};

// Sync transactions for a user
const syncTransactions = async (userId) => {
  try {
    const endDate = new Date().toISOString().split('T')[0];
    const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    const result = await getTransactions(userId, startDate, endDate);
    
    if (!result.success) {
      return result;
    }

    const { transactions } = result.data;
    let newTransactions = 0;
    let updatedTransactions = 0;

    for (const transaction of transactions) {
      try {
        // Check if transaction already exists
        const existingTransaction = await db('transactions')
          .where('plaid_transaction_id', transaction.plaid_transaction_id)
          .first();

        if (existingTransaction) {
          // Update existing transaction
          await db('transactions')
            .where('plaid_transaction_id', transaction.plaid_transaction_id)
            .update({
              amount: transaction.amount,
              merchant_name: transaction.merchant_name,
              category: transaction.category,
              pending: transaction.pending,
              updated_at: db.fn.now()
            });
          updatedTransactions++;
        } else {
          // Insert new transaction
          await db('transactions').insert(transaction);
          newTransactions++;
        }
      } catch (error) {
        logger.error(`Error syncing transaction ${transaction.plaid_transaction_id}:`, error);
      }
    }

    logger.info(`Synced transactions for user ${userId}: ${newTransactions} new, ${updatedTransactions} updated`);

    return {
      success: true,
      data: {
        new_transactions: newTransactions,
        updated_transactions: updatedTransactions,
        total_processed: transactions.length
      }
    };
  } catch (error) {
    logger.error('Error syncing transactions:', error);
    return {
      success: false,
      error: 'Failed to sync transactions'
    };
  }
};

// Set primary account
const setPrimaryAccount = async (userId, accountId) => {
  try {
    // Remove primary status from all accounts
    await db('bank_accounts')
      .where('user_id', userId)
      .update({ is_primary: false });

    // Set the specified account as primary
    await db('bank_accounts')
      .where('id', accountId)
      .where('user_id', userId)
      .update({ is_primary: true });

    logger.info(`Set primary account ${accountId} for user ${userId}`);

    return {
      success: true,
      message: 'Primary account updated successfully'
    };
  } catch (error) {
    logger.error('Error setting primary account:', error);
    return {
      success: false,
      error: 'Failed to update primary account'
    };
  }
};

// Remove bank account
const removeBankAccount = async (userId, accountId) => {
  try {
    const account = await db('bank_accounts')
      .where('id', accountId)
      .where('user_id', userId)
      .first();

    if (!account) {
      return {
        success: false,
        error: 'Account not found'
      };
    }

    // Deactivate the account
    await db('bank_accounts')
      .where('id', accountId)
      .update({ is_active: false });

    logger.info(`Removed bank account ${accountId} for user ${userId}`);

    return {
      success: true,
      message: 'Bank account removed successfully'
    };
  } catch (error) {
    logger.error('Error removing bank account:', error);
    return {
      success: false,
      error: 'Failed to remove bank account'
    };
  }
};

// Get account balance
const getAccountBalance = async (userId) => {
  try {
    const result = await getAccounts(userId);
    
    if (!result.success) {
      return result;
    }

    const totalBalance = result.data.accounts.reduce((sum, account) => {
      return sum + (account.current_balance || 0);
    }, 0);

    const totalAvailable = result.data.accounts.reduce((sum, account) => {
      return sum + (account.available_balance || 0);
    }, 0);

    return {
      success: true,
      data: {
        total_balance: totalBalance,
        total_available: totalAvailable,
        accounts: result.data.accounts
      }
    };
  } catch (error) {
    logger.error('Error getting account balance:', error);
    return {
      success: false,
      error: 'Failed to retrieve account balance'
    };
  }
};

module.exports = {
  createLinkToken,
  exchangePublicToken,
  getAccounts,
  getTransactions,
  syncTransactions,
  setPrimaryAccount,
  removeBankAccount,
  getAccountBalance
}; 