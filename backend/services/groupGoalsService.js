const { db } = require('../config/database');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

// Generate unique invite code
const generateInviteCode = () => {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
};

// Create a group goal
const createGroupGoal = async (creatorId, goalData) => {
  try {
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
    } = goalData;

    // Generate unique invite code
    let inviteCode;
    let isUnique = false;
    while (!isUnique) {
      inviteCode = generateInviteCode();
      const existing = await db('group_goals')
        .where('invite_code', inviteCode)
        .first();
      if (!existing) {
        isUnique = true;
      }
    }

    await db.transaction(async (trx) => {
      // Create group goal
      const [groupGoal] = await trx('group_goals').insert({
        creator_id: creatorId,
        name,
        description,
        target_amount,
        category,
        image_url,
        product_url,
        round_up_amount,
        target_date: target_date ? new Date(target_date) : null,
        max_participants,
        is_public,
        invite_code: inviteCode
      }).returning('*');

      // Add creator as participant with creator role
      await trx('group_goal_participants').insert({
        group_goal_id: groupGoal.id,
        user_id: creatorId,
        role: 'creator'
      });

      // Create social activity
      await createSocialActivity(creatorId, 'group_goal_created', {
        group_goal_id: groupGoal.id,
        group_goal_name: name,
        target_amount
      });
    });

    logger.info(`Group goal "${name}" created by user ${creatorId}`);

    return {
      success: true,
      data: {
        group_goal: {
          ...goalData,
          invite_code: inviteCode
        }
      }
    };
  } catch (error) {
    logger.error('Error creating group goal:', error);
    return {
      success: false,
      error: 'Failed to create group goal'
    };
  }
};

// Get group goal by ID
const getGroupGoal = async (groupId, userId) => {
  try {
    const groupGoal = await db('group_goals')
      .where('id', groupId)
      .first();

    if (!groupGoal) {
      return {
        success: false,
        error: 'Group goal not found'
      };
    }

    // Check if user is participant
    const participant = await db('group_goal_participants')
      .where('group_goal_id', groupId)
      .where('user_id', userId)
      .first();

    if (!participant && !groupGoal.is_public) {
      return {
        success: false,
        error: 'Access denied'
      };
    }

    // Get participants
    const participants = await db('group_goal_participants')
      .join('users', 'group_goal_participants.user_id', 'users.id')
      .where('group_goal_participants.group_goal_id', groupId)
      .where('group_goal_participants.is_active', true)
      .select(
        'users.id',
        'users.first_name',
        'users.last_name',
        'users.profile_picture_url',
        'group_goal_participants.role',
        'group_goal_participants.contributed_amount',
        'group_goal_participants.joined_at'
      );

    // Calculate progress
    const progressPercentage = Math.min((groupGoal.current_amount / groupGoal.target_amount) * 100, 100);
    const daysRemaining = groupGoal.target_date ? Math.max(0, Math.ceil((new Date(groupGoal.target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null;

    return {
      success: true,
      data: {
        group_goal: {
          ...groupGoal,
          progress_percentage: progressPercentage,
          days_remaining: daysRemaining
        },
        participants,
        user_role: participant?.role || null
      }
    };
  } catch (error) {
    logger.error('Error getting group goal:', error);
    return {
      success: false,
      error: 'Failed to retrieve group goal'
    };
  }
};

// Join group goal
const joinGroupGoal = async (userId, inviteCode) => {
  try {
    // Find group goal by invite code
    const groupGoal = await db('group_goals')
      .where('invite_code', inviteCode)
      .where('is_active', true)
      .where('is_completed', false)
      .first();

    if (!groupGoal) {
      return {
        success: false,
        error: 'Invalid invite code or group goal is inactive'
      };
    }

    // Check if user is already a participant
    const existingParticipant = await db('group_goal_participants')
      .where('group_goal_id', groupGoal.id)
      .where('user_id', userId)
      .first();

    if (existingParticipant) {
      return {
        success: false,
        error: 'Already a participant in this group goal'
      };
    }

    // Check if group is full
    const participantCount = await db('group_goal_participants')
      .where('group_goal_id', groupGoal.id)
      .where('is_active', true)
      .count('* as count');

    if (parseInt(participantCount[0].count) >= groupGoal.max_participants) {
      return {
        success: false,
        error: 'Group goal is full'
      };
    }

    // Add user as participant
    await db('group_goal_participants').insert({
      group_goal_id: groupGoal.id,
      user_id: userId,
      role: 'member'
    });

    // Create social activity
    await createSocialActivity(userId, 'group_goal_joined', {
      group_goal_id: groupGoal.id,
      group_goal_name: groupGoal.name
    });

    logger.info(`User ${userId} joined group goal ${groupGoal.id}`);

    return {
      success: true,
      message: 'Successfully joined group goal',
      data: {
        group_goal_id: groupGoal.id,
        group_goal_name: groupGoal.name
      }
    };
  } catch (error) {
    logger.error('Error joining group goal:', error);
    return {
      success: false,
      error: 'Failed to join group goal'
    };
  }
};

// Leave group goal
const leaveGroupGoal = async (userId, groupId) => {
  try {
    const participant = await db('group_goal_participants')
      .where('group_goal_id', groupId)
      .where('user_id', userId)
      .first();

    if (!participant) {
      return {
        success: false,
        error: 'Not a participant in this group goal'
      };
    }

    // Don't allow creator to leave
    if (participant.role === 'creator') {
      return {
        success: false,
        error: 'Creator cannot leave the group goal'
      };
    }

    await db('group_goal_participants')
      .where('group_goal_id', groupId)
      .where('user_id', userId)
      .update({
        is_active: false,
        updated_at: db.fn.now()
      });

    logger.info(`User ${userId} left group goal ${groupId}`);

    return {
      success: true,
      message: 'Successfully left group goal'
    };
  } catch (error) {
    logger.error('Error leaving group goal:', error);
    return {
      success: false,
      error: 'Failed to leave group goal'
    };
  }
};

// Contribute to group goal
const contributeToGroupGoal = async (userId, groupId, amount, message = null, isAnonymous = false) => {
  try {
    // Check if user is participant
    const participant = await db('group_goal_participants')
      .where('group_goal_id', groupId)
      .where('user_id', userId)
      .where('is_active', true)
      .first();

    if (!participant) {
      return {
        success: false,
        error: 'Not a participant in this group goal'
      };
    }

    // Check if group goal is active
    const groupGoal = await db('group_goals')
      .where('id', groupId)
      .where('is_active', true)
      .where('is_completed', false)
      .first();

    if (!groupGoal) {
      return {
        success: false,
        error: 'Group goal is not active'
      };
    }

    await db.transaction(async (trx) => {
      // Create contribution record
      await trx('group_goal_contributions').insert({
        group_goal_id: groupId,
        user_id: userId,
        amount,
        type: 'manual',
        message,
        is_anonymous
      });

      // Update participant's contributed amount
      await trx('group_goal_participants')
        .where('group_goal_id', groupId)
        .where('user_id', userId)
        .increment('contributed_amount', amount);

      // Update group goal current amount
      const [updatedGroupGoal] = await trx('group_goals')
        .where('id', groupId)
        .increment('current_amount', amount)
        .returning('*');

      // Check if goal is completed
      if (updatedGroupGoal.current_amount >= updatedGroupGoal.target_amount && !updatedGroupGoal.is_completed) {
        await trx('group_goals')
          .where('id', groupId)
          .update({
            is_completed: true,
            completed_at: trx.fn.now()
          });
      }
    });

    logger.info(`Contribution of $${amount} made to group goal ${groupId} by user ${userId}`);

    return {
      success: true,
      message: 'Contribution added successfully',
      data: {
        amount,
        group_goal_id: groupId
      }
    };
  } catch (error) {
    logger.error('Error contributing to group goal:', error);
    return {
      success: false,
      error: 'Failed to add contribution'
    };
  }
};

// Get group goal contributions
const getGroupGoalContributions = async (groupId, userId, limit = 20, offset = 0) => {
  try {
    // Check if user is participant
    const participant = await db('group_goal_participants')
      .where('group_goal_id', groupId)
      .where('user_id', userId)
      .first();

    if (!participant) {
      return {
        success: false,
        error: 'Access denied'
      };
    }

    // Get total count
    const [{ count }] = await db('group_goal_contributions')
      .where('group_goal_id', groupId)
      .count('* as count');

    // Get contributions with user info (respecting anonymity)
    const contributions = await db('group_goal_contributions')
      .join('users', 'group_goal_contributions.user_id', 'users.id')
      .where('group_goal_contributions.group_goal_id', groupId)
      .select(
        'group_goal_contributions.*',
        'users.first_name',
        'users.last_name',
        'users.profile_picture_url'
      )
      .orderBy('group_goal_contributions.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Anonymize contributions if requested
    const anonymizedContributions = contributions.map(contribution => {
      if (contribution.is_anonymous) {
        return {
          ...contribution,
          first_name: 'Anonymous',
          last_name: 'User',
          profile_picture_url: null
        };
      }
      return contribution;
    });

    return {
      success: true,
      data: {
        contributions: anonymizedContributions,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + contributions.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error getting group goal contributions:', error);
    return {
      success: false,
      error: 'Failed to retrieve contributions'
    };
  }
};

// Get user's group goals
const getUserGroupGoals = async (userId, status = 'active') => {
  try {
    let query = db('group_goal_participants')
      .join('group_goals', 'group_goal_participants.group_goal_id', 'group_goals.id')
      .where('group_goal_participants.user_id', userId)
      .where('group_goal_participants.is_active', true);

    if (status === 'active') {
      query = query.where('group_goals.is_active', true).where('group_goals.is_completed', false);
    } else if (status === 'completed') {
      query = query.where('group_goals.is_completed', true);
    }

    const groupGoals = await query
      .select(
        'group_goals.*',
        'group_goal_participants.role',
        'group_goal_participants.contributed_amount'
      )
      .orderBy('group_goals.created_at', 'desc');

    // Calculate progress for each goal
    const groupGoalsWithProgress = groupGoals.map(goal => ({
      ...goal,
      progress_percentage: Math.min((goal.current_amount / goal.target_amount) * 100, 100),
      days_remaining: goal.target_date ? Math.max(0, Math.ceil((new Date(goal.target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null
    }));

    return {
      success: true,
      data: {
        group_goals: groupGoalsWithProgress
      }
    };
  } catch (error) {
    logger.error('Error getting user group goals:', error);
    return {
      success: false,
      error: 'Failed to retrieve group goals'
    };
  }
};

// Search public group goals
const searchPublicGroupGoals = async (query, category = null, limit = 20, offset = 0) => {
  try {
    let dbQuery = db('group_goals')
      .where('is_public', true)
      .where('is_active', true)
      .where('is_completed', false);

    if (query) {
      dbQuery = dbQuery.where('name', 'like', `%${query}%`);
    }

    if (category) {
      dbQuery = dbQuery.where('category', category);
    }

    // Get total count
    const totalQuery = dbQuery.clone();
    const [{ count }] = await totalQuery.count('* as count');

    // Get group goals with participant count
    const groupGoals = await dbQuery
      .select('group_goals.*')
      .select(db.raw('(SELECT COUNT(*) FROM group_goal_participants WHERE group_goal_participants.group_goal_id = group_goals.id AND group_goal_participants.is_active = true) as participant_count'))
      .orderBy('group_goals.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Calculate progress for each goal
    const groupGoalsWithProgress = groupGoals.map(goal => ({
      ...goal,
      progress_percentage: Math.min((goal.current_amount / goal.target_amount) * 100, 100),
      days_remaining: goal.target_date ? Math.max(0, Math.ceil((new Date(goal.target_date) - new Date()) / (1000 * 60 * 60 * 24))) : null
    }));

    return {
      success: true,
      data: {
        group_goals: groupGoalsWithProgress,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + groupGoals.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error searching public group goals:', error);
    return {
      success: false,
      error: 'Failed to search group goals'
    };
  }
};

// Helper function to create social activity
const createSocialActivity = async (userId, activityType, activityData = {}) => {
  try {
    await db('social_activities').insert({
      user_id: userId,
      activity_type: activityType,
      activity_data: activityData
    });
  } catch (error) {
    logger.error('Error creating social activity:', error);
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
  searchPublicGroupGoals
}; 