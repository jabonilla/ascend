const { db } = require('../config/database');
const logger = require('../utils/logger');

// Calculate round-up amount for a transaction
const calculateRoundUp = (transactionAmount, roundUpAmount = 1.00) => {
  // Round up to the nearest dollar and add the specified round-up amount
  const roundedAmount = Math.ceil(transactionAmount);
  const roundUp = (roundedAmount - transactionAmount) + parseFloat(roundUpAmount);
  
  return Math.max(0, roundUp);
};

// Process round-ups for a transaction
const processRoundUps = async (transactionId, userId) => {
  try {
    // Get the transaction
    const transaction = await db('transactions')
      .where('id', transactionId)
      .where('user_id', userId)
      .first();

    if (!transaction) {
      logger.error(`Transaction ${transactionId} not found for user ${userId}`);
      return {
        success: false,
        error: 'Transaction not found'
      };
    }

    // Skip if transaction amount is negative (refunds, etc.)
    if (transaction.amount <= 0) {
      logger.info(`Skipping round-up for transaction ${transactionId} (amount: ${transaction.amount})`);
      return {
        success: true,
        message: 'Transaction skipped (negative amount)'
      };
    }

    // Get user's active goals
    const activeGoals = await db('goals')
      .where('user_id', userId)
      .where('is_active', true)
      .where('is_completed', false)
      .orderBy('created_at', 'asc');

    if (activeGoals.length === 0) {
      logger.info(`No active goals found for user ${userId}`);
      return {
        success: true,
        message: 'No active goals to allocate round-ups'
      };
    }

    // Calculate total round-up amount
    const totalRoundUp = calculateRoundUp(transaction.amount);
    
    if (totalRoundUp <= 0) {
      logger.info(`No round-up calculated for transaction ${transactionId} (amount: ${transaction.amount})`);
      return {
        success: true,
        message: 'No round-up calculated'
      };
    }

    // Distribute round-up among active goals
    const roundUpPerGoal = totalRoundUp / activeGoals.length;
    const roundUps = [];

    await db.transaction(async (trx) => {
      for (const goal of activeGoals) {
        const roundUpAmount = roundUpPerGoal;
        
        // Create round-up record
        const [roundUp] = await trx('round_ups').insert({
          user_id: userId,
          transaction_id: transactionId,
          goal_id: goal.id,
          original_amount: transaction.amount,
          round_up_amount: roundUpAmount,
          total_amount: transaction.amount + roundUpAmount,
          status: 'processed',
          processed_at: trx.fn.now(),
          metadata: {
            merchant: transaction.merchant_name,
            category: transaction.category,
            distribution_method: 'equal_split'
          }
        }).returning('*');

        // Update goal current amount
        const [updatedGoal] = await trx('goals')
          .where('id', goal.id)
          .increment('current_amount', roundUpAmount)
          .returning('*');

        // Check if goal is now completed
        if (updatedGoal.current_amount >= updatedGoal.target_amount && !updatedGoal.is_completed) {
          await trx('goals')
            .where('id', goal.id)
            .update({
              is_completed: true,
              completed_at: trx.fn.now()
            });

          logger.info(`Goal ${goal.id} completed for user ${userId}`);
        }

        roundUps.push(roundUp);
      }
    });

    logger.info(`Processed round-ups for transaction ${transactionId}: $${totalRoundUp} distributed across ${activeGoals.length} goals`);

    return {
      success: true,
      data: {
        transaction_id: transactionId,
        total_round_up: totalRoundUp,
        goals_updated: activeGoals.length,
        round_ups: roundUps
      }
    };
  } catch (error) {
    logger.error('Error processing round-ups:', error);
    return {
      success: false,
      error: 'Failed to process round-ups'
    };
  }
};

// Process round-ups for multiple transactions
const processBatchRoundUps = async (userId, transactionIds) => {
  try {
    const results = [];
    let totalRoundUp = 0;
    let processedCount = 0;

    for (const transactionId of transactionIds) {
      const result = await processRoundUps(transactionId, userId);
      
      if (result.success) {
        processedCount++;
        if (result.data) {
          totalRoundUp += result.data.total_round_up;
        }
      }
      
      results.push({
        transaction_id: transactionId,
        ...result
      });
    }

    logger.info(`Batch processed ${processedCount}/${transactionIds.length} transactions for user ${userId}, total round-up: $${totalRoundUp}`);

    return {
      success: true,
      data: {
        processed_count: processedCount,
        total_transactions: transactionIds.length,
        total_round_up: totalRoundUp,
        results
      }
    };
  } catch (error) {
    logger.error('Error processing batch round-ups:', error);
    return {
      success: false,
      error: 'Failed to process batch round-ups'
    };
  }
};

// Get round-up statistics for a user
const getRoundUpStats = async (userId, startDate = null, endDate = null) => {
  try {
    let query = db('round_ups')
      .where('user_id', userId)
      .where('status', 'processed');

    if (startDate && endDate) {
      query = query.whereBetween('created_at', [startDate, endDate]);
    }

    const stats = await query
      .select(
        db.raw('COUNT(*) as total_round_ups'),
        db.raw('SUM(round_up_amount) as total_amount'),
        db.raw('AVG(round_up_amount) as avg_round_up'),
        db.raw('COUNT(DISTINCT goal_id) as goals_contributed'),
        db.raw('COUNT(DISTINCT DATE(created_at)) as active_days')
      )
      .first();

    // Get round-ups by goal
    const goalStats = await db('round_ups')
      .join('goals', 'round_ups.goal_id', 'goals.id')
      .where('round_ups.user_id', userId)
      .where('round_ups.status', 'processed')
      .select('goals.name', 'goals.category')
      .select(db.raw('SUM(round_ups.round_up_amount) as total_contributed'))
      .select(db.raw('COUNT(*) as round_up_count'))
      .groupBy('goals.id', 'goals.name', 'goals.category')
      .orderBy('total_contributed', 'desc');

    // Get recent round-ups
    const recentRoundUps = await db('round_ups')
      .join('goals', 'round_ups.goal_id', 'goals.id')
      .where('round_ups.user_id', userId)
      .where('round_ups.status', 'processed')
      .select(
        'round_ups.round_up_amount',
        'round_ups.created_at',
        'goals.name as goal_name',
        'goals.category'
      )
      .orderBy('round_ups.created_at', 'desc')
      .limit(10);

    return {
      success: true,
      data: {
        stats: {
          total_round_ups: parseInt(stats.total_round_ups) || 0,
          total_amount: parseFloat(stats.total_amount) || 0,
          avg_round_up: parseFloat(stats.avg_round_up) || 0,
          goals_contributed: parseInt(stats.goals_contributed) || 0,
          active_days: parseInt(stats.active_days) || 0
        },
        goal_breakdown: goalStats,
        recent_round_ups: recentRoundUps
      }
    };
  } catch (error) {
    logger.error('Error getting round-up stats:', error);
    return {
      success: false,
      error: 'Failed to retrieve round-up statistics'
    };
  }
};

// Get round-ups for a specific goal
const getGoalRoundUps = async (userId, goalId, limit = 20, offset = 0) => {
  try {
    // Verify goal belongs to user
    const goal = await db('goals')
      .where('id', goalId)
      .where('user_id', userId)
      .first();

    if (!goal) {
      return {
        success: false,
        error: 'Goal not found'
      };
    }

    // Get total count
    const [{ count }] = await db('round_ups')
      .where('user_id', userId)
      .where('goal_id', goalId)
      .where('status', 'processed')
      .count('* as count');

    // Get round-ups with pagination
    const roundUps = await db('round_ups')
      .join('transactions', 'round_ups.transaction_id', 'transactions.id')
      .where('round_ups.user_id', userId)
      .where('round_ups.goal_id', goalId)
      .where('round_ups.status', 'processed')
      .select(
        'round_ups.*',
        'transactions.merchant_name',
        'transactions.amount as transaction_amount',
        'transactions.category'
      )
      .orderBy('round_ups.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    return {
      success: true,
      data: {
        round_ups: roundUps,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + roundUps.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error getting goal round-ups:', error);
    return {
      success: false,
      error: 'Failed to retrieve goal round-ups'
    };
  }
};

// Manual round-up allocation
const allocateManualRoundUp = async (userId, goalId, amount, description = null) => {
  try {
    // Verify goal belongs to user and is active
    const goal = await db('goals')
      .where('id', goalId)
      .where('user_id', userId)
      .where('is_active', true)
      .where('is_completed', false)
      .first();

    if (!goal) {
      return {
        success: false,
        error: 'Goal not found or not active'
      };
    }

    if (amount <= 0) {
      return {
        success: false,
        error: 'Amount must be greater than 0'
      };
    }

    await db.transaction(async (trx) => {
      // Create manual round-up record
      await trx('round_ups').insert({
        user_id: userId,
        goal_id: goalId,
        original_amount: 0,
        round_up_amount: amount,
        total_amount: amount,
        status: 'processed',
        processed_at: trx.fn.now(),
        metadata: {
          type: 'manual_allocation',
          description: description || 'Manual round-up allocation'
        }
      });

      // Update goal current amount
      const [updatedGoal] = await trx('goals')
        .where('id', goalId)
        .increment('current_amount', amount)
        .returning('*');

      // Check if goal is now completed
      if (updatedGoal.current_amount >= updatedGoal.target_amount && !updatedGoal.is_completed) {
        await trx('goals')
          .where('id', goalId)
          .update({
            is_completed: true,
            completed_at: trx.fn.now()
          });
      }
    });

    logger.info(`Manual round-up allocation: $${amount} to goal ${goalId} for user ${userId}`);

    return {
      success: true,
      message: 'Round-up allocated successfully',
      data: {
        amount,
        goal_id: goalId
      }
    };
  } catch (error) {
    logger.error('Error allocating manual round-up:', error);
    return {
      success: false,
      error: 'Failed to allocate round-up'
    };
  }
};

module.exports = {
  calculateRoundUp,
  processRoundUps,
  processBatchRoundUps,
  getRoundUpStats,
  getGoalRoundUps,
  allocateManualRoundUp
}; 