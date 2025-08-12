const express = require('express');
const { PlaidApi, PlaidEnvironments, Configuration } = require('plaid');
const { body, validationResult } = require('express-validator');

const { logger } = require('../utils/logger');
const { PlaidItem } = require('../models/PlaidItem');
const { PlaidAccount } = require('../models/PlaidAccount');
const { PlaidTransaction } = require('../models/PlaidTransaction');

const router = express.Router();

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

/**
 * @swagger
 * /api/plaid/link-token:
 *   post:
 *     summary: Create Plaid link token
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               userId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Link token created successfully
 */
router.post('/link-token', async (req, res) => {
  try {
    const { userId } = req.body;
    const clientUserId = userId || req.userId;

    const request = {
      user: { client_user_id: clientUserId },
      client_name: 'Ascend',
      products: ['auth', 'transactions'],
      country_codes: ['US'],
      language: 'en',
      account_filters: {
        depository: {
          account_subtypes: ['checking', 'savings'],
        },
        credit: {
          account_subtypes: ['credit card'],
        },
        loan: {
          account_subtypes: ['student', 'mortgage', 'auto'],
        },
      },
    };

    const createTokenResponse = await plaidClient.linkTokenCreate(request);

    res.json({
      success: true,
      data: {
        linkToken: createTokenResponse.data.link_token,
        expiration: createTokenResponse.data.expiration,
      },
    });
  } catch (error) {
    logger.error('Plaid link token creation error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to create link token',
        code: 'LINK_TOKEN_ERROR',
      },
    });
  }
});

/**
 * @swagger
 * /api/plaid/exchange-token:
 *   post:
 *     summary: Exchange public token for access token
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - publicToken
 *             properties:
 *               publicToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token exchanged successfully
 */
router.post('/exchange-token', [
  body('publicToken').notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array(),
        },
      });
    }

    const { publicToken } = req.body;
    const userId = req.userId;

    // Exchange public token for access token
    const exchangeRequest = {
      public_token: publicToken,
    };

    const exchangeResponse = await plaidClient.itemPublicTokenExchange(exchangeRequest);
    const accessToken = exchangeResponse.data.access_token;
    const itemId = exchangeResponse.data.item_id;

    // Get item information
    const itemRequest = {
      access_token: accessToken,
    };

    const itemResponse = await plaidClient.itemGet(itemRequest);
    const item = itemResponse.data.item;

    // Save Plaid item to database
    const plaidItemData = {
      id: itemId,
      userId,
      accessToken,
      institutionId: item.institution_id,
      webhook: item.webhook,
      error: item.error,
      availableProducts: item.available_products,
      billedProducts: item.billed_products,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    await PlaidItem.create(plaidItemData);

    // Get accounts for this item
    const accountsRequest = {
      access_token: accessToken,
    };

    const accountsResponse = await plaidClient.accountsGet(accountsRequest);
    const accounts = accountsResponse.data.accounts;

    // Save accounts to database
    for (const account of accounts) {
      const accountData = {
        id: account.account_id,
        itemId,
        userId,
        name: account.name,
        mask: account.mask,
        type: account.type,
        subtype: account.subtype,
        institutionId: item.institution_id,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await PlaidAccount.create(accountData);
    }

    logger.info(`Plaid item connected for user ${userId}: ${itemId}`);

    res.json({
      success: true,
      data: {
        itemId,
        institutionId: item.institution_id,
        accounts: accounts.map(account => ({
          id: account.account_id,
          name: account.name,
          mask: account.mask,
          type: account.type,
          subtype: account.subtype,
        })),
      },
    });
  } catch (error) {
    logger.error('Plaid token exchange error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to exchange token',
        code: 'TOKEN_EXCHANGE_ERROR',
      },
    });
  }
});

/**
 * @swagger
 * /api/plaid/accounts:
 *   get:
 *     summary: Get user's connected accounts
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Accounts retrieved successfully
 */
router.get('/accounts', async (req, res) => {
  try {
    const userId = req.userId;

    // Get all Plaid items for user
    const items = await PlaidItem.findByUserId(userId);
    const accounts = [];

    for (const item of items) {
      try {
        const request = {
          access_token: item.accessToken,
        };

        const response = await plaidClient.accountsGet(request);
        const itemAccounts = response.data.accounts;

        for (const account of itemAccounts) {
          // Get account balance
          const balanceRequest = {
            access_token: item.accessToken,
            options: {
              account_ids: [account.account_id],
            },
          };

          const balanceResponse = await plaidClient.accountsBalanceGet(balanceRequest);
          const balance = balanceResponse.data.accounts[0];

          accounts.push({
            id: account.account_id,
            itemId: item.id,
            name: account.name,
            mask: account.mask,
            type: account.type,
            subtype: account.subtype,
            institutionId: item.institutionId,
            balances: {
              available: balance.balances.available,
              current: balance.balances.current,
              limit: balance.balances.limit,
              isoCurrencyCode: balance.balances.iso_currency_code,
            },
          });
        }
      } catch (itemError) {
        logger.error(`Error fetching accounts for item ${item.id}:`, itemError);
        // Continue with other items
      }
    }

    res.json({
      success: true,
      data: {
        accounts,
      },
    });
  } catch (error) {
    logger.error('Plaid accounts fetch error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to fetch accounts',
        code: 'ACCOUNTS_FETCH_ERROR',
      },
    });
  }
});

/**
 * @swagger
 * /api/plaid/transactions:
 *   get:
 *     summary: Get transactions for an account
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: accountId
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: startDate
 *         schema:
 *           type: string
 *           format: date
 *       - in: query
 *         name: endDate
 *         schema:
 *           type: string
 *           format: date
 *     responses:
 *       200:
 *         description: Transactions retrieved successfully
 */
router.get('/transactions', async (req, res) => {
  try {
    const { accountId, startDate, endDate } = req.query;
    const userId = req.userId;

    if (!accountId) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Account ID is required',
          code: 'MISSING_ACCOUNT_ID',
        },
      });
    }

    // Find the account and its associated item
    const account = await PlaidAccount.findById(accountId);
    if (!account || account.userId !== userId) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Account not found',
          code: 'ACCOUNT_NOT_FOUND',
        },
      });
    }

    const item = await PlaidItem.findById(account.itemId);
    if (!item) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Plaid item not found',
          code: 'ITEM_NOT_FOUND',
        },
      });
    }

    // Set default date range if not provided
    const end = endDate || new Date().toISOString().split('T')[0];
    const start = startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    const request = {
      access_token: item.accessToken,
      start_date: start,
      end_date: end,
      options: {
        account_ids: [accountId],
      },
    };

    const response = await plaidClient.transactionsGet(request);
    const transactions = response.data.transactions;

    // Save transactions to database
    for (const transaction of transactions) {
      const transactionData = {
        id: transaction.transaction_id,
        accountId: transaction.account_id,
        userId,
        amount: transaction.amount,
        date: transaction.date,
        name: transaction.name,
        merchantName: transaction.merchant_name,
        category: transaction.category,
        categoryId: transaction.category_id,
        pending: transaction.pending,
        paymentChannel: transaction.payment_channel,
        transactionType: transaction.transaction_type,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      await PlaidTransaction.create(transactionData);
    }

    res.json({
      success: true,
      data: {
        transactions: transactions.map(transaction => ({
          id: transaction.transaction_id,
          accountId: transaction.account_id,
          amount: transaction.amount,
          date: transaction.date,
          name: transaction.name,
          merchantName: transaction.merchant_name,
          category: transaction.category,
          categoryId: transaction.category_id,
          pending: transaction.pending,
          paymentChannel: transaction.payment_channel,
          transactionType: transaction.transaction_type,
        })),
        total: transactions.length,
      },
    });
  } catch (error) {
    logger.error('Plaid transactions fetch error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to fetch transactions',
        code: 'TRANSACTIONS_FETCH_ERROR',
      },
    });
  }
});

/**
 * @swagger
 * /api/plaid/sync:
 *   post:
 *     summary: Sync transactions for all user accounts
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Sync completed successfully
 */
router.post('/sync', async (req, res) => {
  try {
    const userId = req.userId;

    // Get all user's Plaid items
    const items = await PlaidItem.findByUserId(userId);
    const syncResults = [];

    for (const item of items) {
      try {
        // Get accounts for this item
        const accountsRequest = {
          access_token: item.accessToken,
        };

        const accountsResponse = await plaidClient.accountsGet(accountsRequest);
        const accounts = accountsResponse.data.accounts;

        for (const account of accounts) {
          // Sync transactions for this account
          const endDate = new Date().toISOString().split('T')[0];
          const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

          const transactionsRequest = {
            access_token: item.accessToken,
            start_date: startDate,
            end_date: endDate,
            options: {
              account_ids: [account.account_id],
            },
          };

          const transactionsResponse = await plaidClient.transactionsGet(transactionsRequest);
          const transactions = transactionsResponse.data.transactions;

          // Save new transactions
          let newTransactions = 0;
          for (const transaction of transactions) {
            const existing = await PlaidTransaction.findById(transaction.transaction_id);
            if (!existing) {
              const transactionData = {
                id: transaction.transaction_id,
                accountId: transaction.account_id,
                userId,
                amount: transaction.amount,
                date: transaction.date,
                name: transaction.name,
                merchantName: transaction.merchant_name,
                category: transaction.category,
                categoryId: transaction.category_id,
                pending: transaction.pending,
                paymentChannel: transaction.payment_channel,
                transactionType: transaction.transaction_type,
                createdAt: new Date(),
                updatedAt: new Date(),
              };

              await PlaidTransaction.create(transactionData);
              newTransactions++;
            }
          }

          syncResults.push({
            accountId: account.account_id,
            accountName: account.name,
            newTransactions,
            totalTransactions: transactions.length,
          });
        }
      } catch (itemError) {
        logger.error(`Error syncing item ${item.id}:`, itemError);
        syncResults.push({
          itemId: item.id,
          error: itemError.message,
        });
      }
    }

    res.json({
      success: true,
      data: {
        syncResults,
        totalItems: items.length,
      },
    });
  } catch (error) {
    logger.error('Plaid sync error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to sync transactions',
        code: 'SYNC_ERROR',
      },
    });
  }
});

/**
 * @swagger
 * /api/plaid/disconnect:
 *   post:
 *     summary: Disconnect a Plaid item
 *     tags: [Plaid]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - itemId
 *             properties:
 *               itemId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Item disconnected successfully
 */
router.post('/disconnect', [
  body('itemId').notEmpty(),
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Validation failed',
          code: 'VALIDATION_ERROR',
          details: errors.array(),
        },
      });
    }

    const { itemId } = req.body;
    const userId = req.userId;

    // Verify item belongs to user
    const item = await PlaidItem.findById(itemId);
    if (!item || item.userId !== userId) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Item not found',
          code: 'ITEM_NOT_FOUND',
        },
      });
    }

    // Remove item from Plaid
    try {
      const request = {
        access_token: item.accessToken,
      };

      await plaidClient.itemRemove(request);
    } catch (plaidError) {
      logger.error('Error removing item from Plaid:', plaidError);
      // Continue with local cleanup even if Plaid removal fails
    }

    // Delete from database
    await PlaidItem.deleteById(itemId);
    await PlaidAccount.deleteByItemId(itemId);
    await PlaidTransaction.deleteByItemId(itemId);

    logger.info(`Plaid item disconnected: ${itemId}`);

    res.json({
      success: true,
      message: 'Item disconnected successfully',
    });
  } catch (error) {
    logger.error('Plaid disconnect error:', error);
    res.status(500).json({
      success: false,
      error: {
        message: 'Failed to disconnect item',
        code: 'DISCONNECT_ERROR',
      },
    });
  }
});

module.exports = router;
