const { validationResult } = require('express-validator');
const groupGoalsService = require('../services/groupGoalsService');
const logger = require('../utils/logger');

// Create a group goal
const createGroupGoal = async (req, res) => {
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
      max_participants = 10,
      is_public = false
    } = req.body;

    // Validate target amount
    if (target_amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Target amount must be greater than 0'
      });
    }

    // Validate max participants
    if (max_participants < 2 || max_participants > 50) {
      return res.status(400).json({
        success: false,
        error: 'Max participants must be between 2 and 50'
      });
    }

    const result = await groupGoalsService.createGroupGoal(user.id, {
      name,
      description,
      target_amount,
      category,
      image_url,
      product_url,
      round_up_amount,
      target_date,
      max_participants,
      is_public
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Group goal "${name}" created by user ${user.id}`);

    res.status(201).json({
      success: true,
      message: 'Group goal created successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error creating group goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create group goal'
    });
  }
};

// Get group goal details
const getGroupGoal = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;

    const result = await groupGoalsService.getGroupGoal(id, user.id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved group goal ${id} for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting group goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve group goal'
    });
  }
};

// Join group goal
const joinGroupGoal = async (req, res) => {
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
    const { invite_code } = req.body;

    const result = await groupGoalsService.joinGroupGoal(user.id, invite_code);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`User ${user.id} joined group goal with invite code ${invite_code}`);

    res.json({
      success: true,
      message: result.message,
      data: result.data
    });
  } catch (error) {
    logger.error('Error joining group goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to join group goal'
    });
  }
};

// Leave group goal
const leaveGroupGoal = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;

    const result = await groupGoalsService.leaveGroupGoal(user.id, id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`User ${user.id} left group goal ${id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error leaving group goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to leave group goal'
    });
  }
};

// Contribute to group goal
const contributeToGroupGoal = async (req, res) => {
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
    const { amount, message, is_anonymous = false } = req.body;

    if (amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Contribution amount must be greater than 0'
      });
    }

    const result = await groupGoalsService.contributeToGroupGoal(
      user.id,
      id,
      amount,
      message,
      is_anonymous
    );

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Contribution of $${amount} made to group goal ${id} by user ${user.id}`);

    res.json({
      success: true,
      message: result.message,
      data: result.data
    });
  } catch (error) {
    logger.error('Error contributing to group goal:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to add contribution'
    });
  }
};

// Get group goal contributions
const getGroupGoalContributions = async (req, res) => {
  try {
    const { user } = req;
    const { id } = req.params;
    const { limit = 20, offset = 0 } = req.query;

    const result = await groupGoalsService.getGroupGoalContributions(id, user.id, limit, offset);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved contributions for group goal ${id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting group goal contributions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve contributions'
    });
  }
};

// Get user's group goals
const getUserGroupGoals = async (req, res) => {
  try {
    const { user } = req;
    const { status = 'active' } = req.query;

    const result = await groupGoalsService.getUserGroupGoals(user.id, status);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved ${status} group goals for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting user group goals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve group goals'
    });
  }
};

// Search public group goals
const searchPublicGroupGoals = async (req, res) => {
  try {
    const { q, category, limit = 20, offset = 0 } = req.query;

    const result = await groupGoalsService.searchPublicGroupGoals(q, category, limit, offset);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Searched public group goals with query: ${q}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error searching public group goals:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to search group goals'
    });
  }
};

// Get group goal statistics
const getGroupGoalStats = async (req, res) => {
  try {
    const { user } = req;

    // Get user's group goals statistics
    const [activeGroups] = await db('group_goal_participants')
      .join('group_goals', 'group_goal_participants.group_goal_id', 'group_goals.id')
      .where('group_goal_participants.user_id', user.id)
      .where('group_goal_participants.is_active', true)
      .where('group_goals.is_active', true)
      .where('group_goals.is_completed', false)
      .count('* as count');

    const [completedGroups] = await db('group_goal_participants')
      .join('group_goals', 'group_goal_participants.group_goal_id', 'group_goals.id')
      .where('group_goal_participants.user_id', user.id)
      .where('group_goal_participants.is_active', true)
      .where('group_goals.is_completed', true)
      .count('* as count');

    const [totalContributed] = await db('group_goal_participants')
      .where('user_id', user.id)
      .where('is_active', true)
      .sum('contributed_amount as total');

    const [createdGroups] = await db('group_goals')
      .where('creator_id', user.id)
      .count('* as count');

    logger.info(`Retrieved group goal statistics for user ${user.id}`);

    res.json({
      success: true,
      data: {
        active_groups: parseInt(activeGroups.count),
        completed_groups: parseInt(completedGroups.count),
        total_contributed: parseFloat(totalContributed.total) || 0,
        created_groups: parseInt(createdGroups.count)
      }
    });
  } catch (error) {
    logger.error('Error getting group goal stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve group goal statistics'
    });
  }
};

module.exports = {
  createGroupGoal,
  getGroupGoal,
  joinGroupGoal,
  leaveGroupGoal,
  contributeToGroupGoal,
  getGroupGoalContributions,
  getUserGroupGoals,
  searchPublicGroupGoals,
  getGroupGoalStats
}; 