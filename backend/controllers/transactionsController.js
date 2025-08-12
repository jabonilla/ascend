const { validationResult } = require('express-validator');
const { db } = require('../config/database');
const roundupService = require('../services/roundupService');
const logger = require('../utils/logger');

// Get user transactions
const getTransactions = async (req, res) => {
  try {
    const { user } = req;
    const { 
      start_date, 
      end_date, 
      category, 
      merchant, 
      min_amount, 
      max_amount,
      limit = 50, 
      offset = 0 
    } = req.query;

    let query = db('transactions')
      .where('user_id', user.id)
      .orderBy('date', 'desc');

    // Apply filters
    if (start_date && end_date) {
      query = query.whereBetween('date', [start_date, end_date]);
    }

    if (category) {
      query = query.where('category', 'like', `%${category}%`);
    }

    if (merchant) {
      query = query.where('merchant_name', 'like', `%${merchant}%`);
    }

    if (min_amount) {
      query = query.where('amount', '>=', parseFloat(min_amount));
    }

    if (max_amount) {
      query = query.where('amount', '<=', parseFloat(max_amount));
    }

    // Get total count for pagination
    const totalQuery = query.clone();
    const [{ count }] = await totalQuery.count('* as count');

    // Apply pagination
    const transactions = await query
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .select('*');

    logger.info(`Retrieved ${transactions.length} transactions for user ${user.id}`);

    res.json({
      success: true,
      data: {
        transactions,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + transactions.length < parseInt(count)
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

// Get transaction details
const getTransaction = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;

    const transaction = await db('transactions')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!transaction) {
      return res.status(404).json({
        success: false,
        error: 'Transaction not found'
      });
    }

    // Get round-ups for this transaction
    const roundUps = await db('round_ups')
      .join('goals', 'round_ups.goal_id', 'goals.id')
      .where('round_ups.transaction_id', id)
      .select(
        'round_ups.round_up_amount',
        'round_ups.created_at',
        'goals.name as goal_name',
        'goals.category as goal_category'
      );

    logger.info(`Retrieved transaction ${id} for user ${user.id}`);

    res.json({
      success: true,
      data: {
        transaction,
        round_ups: roundUps
      }
    });
  } catch (error) {
    logger.error('Error getting transaction:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve transaction'
    });
  }
};

// Process round-ups for a transaction
const processTransactionRoundUps = async (req, res) => {
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
    const { transaction_id } = req.params;

    const result = await roundupService.processRoundUps(transaction_id, user.id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Processed round-ups for transaction ${transaction_id} for user ${user.id}`);

    res.json({
      success: true,
      message: 'Round-ups processed successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error processing transaction round-ups:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process round-ups'
    });
  }
};

// Process round-ups for multiple transactions
const processBatchRoundUps = async (req, res) => {
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
    const { transaction_ids } = req.body;

    if (!Array.isArray(transaction_ids) || transaction_ids.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Transaction IDs array is required'
      });
    }

    const result = await roundupService.processBatchRoundUps(user.id, transaction_ids);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Batch processed round-ups for ${transaction_ids.length} transactions for user ${user.id}`);

    res.json({
      success: true,
      message: 'Batch round-ups processed successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error processing batch round-ups:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process batch round-ups'
    });
  }
};

// Get transaction statistics
const getTransactionStats = async (req, res) => {
  try {
    const { user } = req;
    const { start_date, end_date } = req.query;

    let query = db('transactions')
      .where('user_id', user.id);

    if (start_date && end_date) {
      query = query.whereBetween('date', [start_date, end_date]);
    }

    const stats = await query
      .select(
        db.raw('COUNT(*) as total_transactions'),
        db.raw('SUM(amount) as total_spent'),
        db.raw('AVG(amount) as avg_transaction'),
        db.raw('COUNT(DISTINCT merchant_name) as unique_merchants'),
        db.raw('COUNT(DISTINCT category) as unique_categories')
      )
      .first();

    // Get spending by category
    const categoryStats = await db('transactions')
      .where('user_id', user.id)
      .select('category')
      .select(db.raw('COUNT(*) as transaction_count'))
      .select(db.raw('SUM(amount) as total_spent'))
      .groupBy('category')
      .orderBy('total_spent', 'desc')
      .limit(10);

    // Get top merchants
    const merchantStats = await db('transactions')
      .where('user_id', user.id)
      .select('merchant_name')
      .select(db.raw('COUNT(*) as transaction_count'))
      .select(db.raw('SUM(amount) as total_spent'))
      .groupBy('merchant_name')
      .orderBy('total_spent', 'desc')
      .limit(10);

    logger.info(`Retrieved transaction statistics for user ${user.id}`);

    res.json({
      success: true,
      data: {
        stats: {
          total_transactions: parseInt(stats.total_transactions) || 0,
          total_spent: parseFloat(stats.total_spent) || 0,
          avg_transaction: parseFloat(stats.avg_transaction) || 0,
          unique_merchants: parseInt(stats.unique_merchants) || 0,
          unique_categories: parseInt(stats.unique_categories) || 0
        },
        category_breakdown: categoryStats,
        top_merchants: merchantStats
      }
    });
  } catch (error) {
    logger.error('Error getting transaction stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve transaction statistics'
    });
  }
};

// Get round-up statistics
const getRoundUpStats = async (req, res) => {
  try {
    const { user } = req;
    const { start_date, end_date } = req.query;

    const result = await roundupService.getRoundUpStats(user.id, start_date, end_date);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved round-up statistics for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting round-up stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve round-up statistics'
    });
  }
};

// Get round-ups for a specific goal
const getGoalRoundUps = async (req, res) => {
  try {
    const { user } = req;
    const { goal_id } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    const result = await roundupService.getGoalRoundUps(user.id, goal_id, limit, offset);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved round-ups for goal ${goal_id} for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting goal round-ups:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve goal round-ups'
    });
  }
};

module.exports = {
  getTransactions,
  getTransaction,
  processTransactionRoundUps,
  processBatchRoundUps,
  getTransactionStats,
  getRoundUpStats,
  getGoalRoundUps
}; 