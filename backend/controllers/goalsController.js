const { validationResult } = require('express-validator');
const { db } = require('../config/database');
const logger = require('../utils/logger');

// Get all goals for a user
const getGoals = async (req, res) => {
  try {
    const { user } = req;
    const { status, category, limit = 20, offset = 0 } = req.query;

    let query = db('goals')
      .where('user_id', user.id)
      .orderBy('created_at', 'desc');

    // Filter by status
    if (status) {
      if (status === 'active') {
        query = query.where('is_active', true).where('is_completed', false);
      } else if (status === 'completed') {
        query = query.where('is_completed', true);
      } else if (status === 'paused') {
        query = query.where('is_active', false);
      }
    }

    // Filter by category
    if (category) {
      query = query.where('category', category);
    }

    // Get total count for pagination
    const totalQuery = query.clone();
    const [{ count }] = await totalQuery.count('* as count');

    // Apply pagination
    const goals = await query
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .select('*');

    // Calculate progress percentage for each goal
    const goalsWithProgress = goals.map(goal => ({
      ...goal,
      progress_percentage: Math.min((goal.current_amount / goal.target_amount) * 100, 100),
      days_remaining: goal.target_date ? Math.max(0, Math.ceil((new Date(goal.target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null
    }));

    logger.info(`Retrieved ${goals.length} goals for user ${user.id}`);

    res.json({
      success: true,
      data: {
        goals: goalsWithProgress,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + goals.length < parseInt(count)
        }
      }
    });
  } catch (error) {
    logger.error('Error getting goals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve goals'
    });
  }
};

// Get a specific goal by ID
const getGoal = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;

    const goal = await db('goals')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    // Get recent round-ups for this goal
    const recentRoundUps = await db('round_ups')
      .where('goal_id', id)
      .orderBy('created_at', 'desc')
      .limit(10)
      .select('*');

    // Calculate progress
    const progressPercentage = Math.min((goal.current_amount / goal.target_amount) * 100, 100);
    const daysRemaining = goal.target_date ? Math.max(0, Math.ceil((new Date(goal.target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null;

    logger.info(`Retrieved goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      data: {
        goal: {
          ...goal,
          progress_percentage: progressPercentage,
          days_remaining: daysRemaining
        },
        recent_round_ups: recentRoundUps
      }
    });
  } catch (error) {
    logger.error('Error getting goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve goal'
    });
  }
};

// Create a new goal
const createGoal = async (req, res) => {
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
    const {
      name,
      description,
      target_amount,
      category,
      image_url,
      product_url,
      round_up_amount = 1.00,
      target_date,
      auto_purchase_enabled = false
    } = req.body;

    // Validate target amount
    if (target_amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Target amount must be greater than 0'
      });
    }

    // Validate round-up amount
    if (round_up_amount < 0.50 || round_up_amount > 10.00) {
      return res.status(400).json({
        success: false,
        error: 'Round-up amount must be between $0.50 and $10.00'
      });
    }

    // Create the goal
    const [goal] = await db('goals')
      .insert({
        user_id: user.id,
        name,
        description,
        target_amount,
        category,
        image_url,
        product_url,
        round_up_amount,
        target_date: target_date ? new Date(target_date) : null,
        auto_purchase_enabled,
        current_amount: 0,
        is_active: true,
        is_completed: false
      })
      .returning('*');

    logger.info(`Created new goal "${name}" for user ${user.id}`);

    res.status(201).json({
      success: true,
      message: 'Goal created successfully',
      data: {
        goal: {
          ...goal,
          progress_percentage: 0,
          days_remaining: target_date ? Math.max(0, Math.ceil((new Date(target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null
        }
      }
    });
  } catch (error) {
    logger.error('Error creating goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create goal'
    });
  }
};

// Update a goal
const updateGoal = async (req, res) => {
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
    const { id } = req.params;
    const {
      name,
      description,
      target_amount,
      category,
      image_url,
      product_url,
      round_up_amount,
      target_date,
      auto_purchase_enabled
    } = req.body;

    // Check if goal exists and belongs to user
    const existingGoal = await db('goals')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!existingGoal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    // Don't allow updates to completed goals
    if (existingGoal.is_completed) {
      return res.status(400).json({
        success: false,
        error: 'Cannot update completed goals'
      });
    }

    // Prepare update data
    const updateData = {};
    if (name !== undefined) updateData.name = name;
    if (description !== undefined) updateData.description = description;
    if (target_amount !== undefined) {
      if (target_amount <= 0) {
        return res.status(400).json({
          success: false,
          error: 'Target amount must be greater than 0'
        });
      }
      updateData.target_amount = target_amount;
    }
    if (category !== undefined) updateData.category = category;
    if (image_url !== undefined) updateData.image_url = image_url;
    if (product_url !== undefined) updateData.product_url = product_url;
    if (round_up_amount !== undefined) {
      if (round_up_amount < 0.50 || round_up_amount > 10.00) {
        return res.status(400).json({
          success: false,
          error: 'Round-up amount must be between $0.50 and $10.00'
        });
      }
      updateData.round_up_amount = round_up_amount;
    }
    if (target_date !== undefined) updateData.target_date = target_date ? new Date(target_date) : null;
    if (auto_purchase_enabled !== undefined) updateData.auto_purchase_enabled = auto_purchase_enabled;

    updateData.updated_at = db.fn.now();

    // Update the goal
    const [updatedGoal] = await db('goals')
      .where('id', id)
      .update(updateData)
      .returning('*');

    logger.info(`Updated goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      message: 'Goal updated successfully',
      data: {
        goal: updatedGoal
      }
    });
  } catch (error) {
    logger.error('Error updating goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update goal'
    });
  }
};

// Delete a goal
const deleteGoal = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;

    // Check if goal exists and belongs to user
    const goal = await db('goals')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    // Don't allow deletion of completed goals with savings
    if (goal.is_completed && goal.current_amount > 0) {
      return res.status(400).json({
        success: false,
        error: 'Cannot delete completed goals with savings. Please withdraw funds first.'
      });
    }

    // Delete the goal
    await db('goals')
      .where('id', id)
      .del();

    logger.info(`Deleted goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      message: 'Goal deleted successfully'
    });
  } catch (error) {
    logger.error('Error deleting goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete goal'
    });
  }
};

// Pause/Resume a goal
const toggleGoalStatus = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;
    const { action } = req.body; // 'pause' or 'resume'

    if (!['pause', 'resume'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: 'Action must be either "pause" or "resume"'
      });
    }

    // Check if goal exists and belongs to user
    const goal = await db('goals')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    // Don't allow status changes for completed goals
    if (goal.is_completed) {
      return res.status(400).json({
        success: false,
        error: 'Cannot change status of completed goals'
      });
    }

    const isActive = action === 'resume';

    // Update the goal status
    const [updatedGoal] = await db('goals')
      .where('id', id)
      .update({
        is_active: isActive,
        updated_at: db.fn.now()
      })
      .returning('*');

    logger.info(`${action}d goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      message: `Goal ${action}d successfully`,
      data: {
        goal: updatedGoal
      }
    });
  } catch (error) {
    logger.error('Error toggling goal status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update goal status'
    });
  }
};

// Manual contribution to a goal
const contributeToGoal = async (req, res) => {
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
    const { id } = req.params;
    const { amount, description } = req.body;

    if (amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Contribution amount must be greater than 0'
      });
    }

    // Check if goal exists and belongs to user
    const goal = await db('goals')
      .where('id', id)
      .where('user_id', user.id)
      .first();

    if (!goal) {
      return res.status(404).json({
        success: false,
        error: 'Goal not found'
      });
    }

    // Don't allow contributions to completed goals
    if (goal.is_completed) {
      return res.status(400).json({
        success: false,
        error: 'Cannot contribute to completed goals'
      });
    }

    // Start transaction
    await db.transaction(async (trx) => {
      // Update goal current amount
      const [updatedGoal] = await trx('goals')
        .where('id', id)
        .increment('current_amount', amount)
        .returning('*');

      // Check if goal is now completed
      const isCompleted = updatedGoal.current_amount >= updatedGoal.target_amount;
      
      if (isCompleted && !updatedGoal.is_completed) {
        await trx('goals')
          .where('id', id)
          .update({
            is_completed: true,
            completed_at: trx.fn.now()
          });
      }

      // Create a manual round-up record
      await trx('round_ups').insert({
        user_id: user.id,
        goal_id: id,
        original_amount: 0,
        round_up_amount: amount,
        total_amount: amount,
        status: 'processed',
        processed_at: trx.fn.now(),
        metadata: {
          type: 'manual_contribution',
          description: description || 'Manual contribution'
        }
      });
    });

    logger.info(`Manual contribution of $${amount} added to goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      message: 'Contribution added successfully',
      data: {
        amount,
        goal_id: id
      }
    });
  } catch (error) {
    logger.error('Error contributing to goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to add contribution'
    });
  }
};

// Get goal statistics
const getGoalStats = async (req, res) => {
  try {
    const { user } = req;

    const stats = await db('goals')
      .where('user_id', user.id)
      .select(
        db.raw('COUNT(*) as total_goals'),
        db.raw('COUNT(CASE WHEN is_completed = true THEN 1 END) as completed_goals'),
        db.raw('COUNT(CASE WHEN is_active = true AND is_completed = false THEN 1 END) as active_goals'),
        db.raw('SUM(CASE WHEN is_completed = true THEN current_amount ELSE 0 END) as total_saved'),
        db.raw('SUM(CASE WHEN is_active = true AND is_completed = false THEN current_amount ELSE 0 END) as active_savings'),
        db.raw('AVG(CASE WHEN is_completed = true THEN current_amount ELSE NULL END) as avg_completed_amount')
      )
      .first();

    // Get category breakdown
    const categoryStats = await db('goals')
      .where('user_id', user.id)
      .select('category')
      .select(db.raw('COUNT(*) as count'))
      .select(db.raw('SUM(current_amount) as total_amount'))
      .groupBy('category');

    logger.info(`Retrieved goal statistics for user ${user.id}`);

    res.json({
      success: true,
      data: {
        stats: {
          total_goals: parseInt(stats.total_goals) || 0,
          completed_goals: parseInt(stats.completed_goals) || 0,
          active_goals: parseInt(stats.active_goals) || 0,
          total_saved: parseFloat(stats.total_saved) || 0,
          active_savings: parseFloat(stats.active_savings) || 0,
          avg_completed_amount: parseFloat(stats.avg_completed_amount) || 0
        },
        category_breakdown: categoryStats
      }
    });
  } catch (error) {
    logger.error('Error getting goal stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve goal statistics'
    });
  }
};

module.exports = {
  getGoals,
  getGoal,
  createGoal,
  updateGoal,
  deleteGoal,
  toggleGoalStatus,
  contributeToGoal,
  getGoalStats
}; 