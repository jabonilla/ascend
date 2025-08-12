const { validationResult } = require('express-validator');
const plaidService = require('../services/plaidService');
const logger = require('../utils/logger');

// Create link token for Plaid Link
const createLinkToken = async (req, res) => {
  try {
    const { user } = req;

    const result = await plaidService.createLinkToken(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Created link token for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating link token:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create link token'
    });
  }
};

// Exchange public token for access token
const exchangePublicToken = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { public_token, institution_name } = req.body;

    const result = await plaidService.exchangePublicToken(public_token, user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    // Update institution name if provided
    if (institution_name) {
      await db('bank_accounts')
        .where('plaid_item_id', result.data.item_id)
        .update({ institution_name });
    }

    logger.info(`Exchanged public token for user ${user.id}`);

    res.json({
      success: true,
      message: 'Bank account connected successfully',
      data: {
        item_id: result.data.item_id
      }
    });
  } catch (error) {
    logger.error('Error exchanging public token:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to connect bank account'
    });
  }
};

// Get user's bank accounts
const getAccounts = async (req, res) => {
  try {
    const { user } = req;

    const result = await plaidService.getAccounts(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved accounts for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting accounts:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve accounts'
    });
  }
};

// Set primary account
const setPrimaryAccount = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { account_id } = req.body;

    const result = await plaidService.setPrimaryAccount(user.id, account_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Set primary account for user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error setting primary account:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to set primary account'
    });
  }
};

// Remove bank account
const removeAccount = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { user } = req;
    const { account_id } = req.params;

    const result = await plaidService.removeBankAccount(user.id, account_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Removed bank account for user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error removing bank account:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to remove bank account'
    });
  }
};

// Get account balance
const getBalance = async (req, res) => {
  try {
    const { user } = req;

    const result = await plaidService.getAccountBalance(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved balance for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting balance:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve balance'
    });
  }
};

// Sync transactions
const syncTransactions = async (req, res) => {
  try {
    const { user } = req;

    const result = await plaidService.syncTransactions(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Synced transactions for user ${user.id}`);

    res.json({
      success: true,
      message: 'Transactions synced successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error syncing transactions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to sync transactions'
    });
  }
};

// Get transactions
const getTransactions = async (req, res) => {
  try {
    const { user } = req;
    const { start_date, end_date, account_ids, limit = 50, offset = 0 } = req.query;

    // Validate dates
    if (!start_date || !end_date) {
      return res.status(400).json({
        success: false,
        error: 'Start date and end date are required'
      });
    }

    // Validate date format (YYYY-MM-DD)
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(start_date) || !dateRegex.test(end_date)) {
      return res.status(400).json({
        success: false,
        error: 'Date format must be YYYY-MM-DD'
      });
    }

    const result = await plaidService.getTransactions(user.id, start_date, end_date, account_ids);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    // Apply pagination
    const transactions = result.data.transactions.slice(offset, offset + parseInt(limit));

    logger.info(`Retrieved transactions for user ${user.id}`);

    res.json({
      success: true,
      data: {
        transactions,
        pagination: {
          total: result.data.transactions.length,
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: offset + transactions.length < result.data.transactions.length
        }
      }
    });
  } catch (error) {
    logger.error('Error getting transactions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve transactions'
    });
  }
};

module.exports = {
  createLinkToken,
  exchangePublicToken,
  getAccounts,
  setPrimaryAccount,
  removeAccount,
  getBalance,
  syncTransactions,
  getTransactions
}; 