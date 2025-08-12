const { validationResult } = require('express-validator');
const socialService = require('../services/socialService');
const logger = require('../utils/logger');

// Send friend request
const sendFriendRequest = async (req, res) => {
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
    const { to_user_id, message } = req.body;

    const result = await socialService.sendFriendRequest(user.id, to_user_id, message);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Friend request sent by user ${user.id} to ${to_user_id}`);

    res.json({
      success: true,
      message: 'Friend request sent successfully',
      data: result.data
    });
  } catch (error) {
    logger.error('Error sending friend request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to send friend request'
    });
  }
};

// Accept friend request
const acceptFriendRequest = async (req, res) => {
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
    const { request_id } = req.params;

    const result = await socialService.acceptFriendRequest(user.id, request_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Friend request ${request_id} accepted by user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error accepting friend request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to accept friend request'
    });
  }
};

// Reject friend request
const rejectFriendRequest = async (req, res) => {
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
    const { request_id } = req.params;

    const result = await socialService.rejectFriendRequest(user.id, request_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Friend request ${request_id} rejected by user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error rejecting friend request:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reject friend request'
    });
  }
};

// Get friend requests
const getFriendRequests = async (req, res) => {
  try {
    const { user } = req;
    const { status = 'pending' } = req.query;

    const result = await socialService.getFriendRequests(user.id, status);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved friend requests for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting friend requests:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve friend requests'
    });
  }
};

// Get friends list
const getFriends = async (req, res) => {
  try {
    const { user } = req;

    const result = await socialService.getFriends(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved friends for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting friends:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve friends'
    });
  }
};

// Remove friend
const removeFriend = async (req, res) => {
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
    const { friend_id } = req.params;

    const result = await socialService.removeFriend(user.id, friend_id);

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Friend ${friend_id} removed by user ${user.id}`);

    res.json({
      success: true,
      message: result.message
    });
  } catch (error) {
    logger.error('Error removing friend:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to remove friend'
    });
  }
};

// Search users
const searchUsers = async (req, res) => {
  try {
    const { user } = req;
    const { q, limit = 10 } = req.query;

    if (!q || q.trim().length < 2) {
      return res.status(400).json({
        success: false,
        error: 'Search query must be at least 2 characters long'
      });
    }

    const result = await socialService.searchUsers(user.id, q.trim(), limit);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`User search performed by ${user.id} for query: ${q}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error searching users:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to search users'
    });
  }
};

// Get social feed
const getSocialFeed = async (req, res) => {
  try {
    const { user } = req;
    const { limit = 20, offset = 0 } = req.query;

    const result = await socialService.getSocialFeed(user.id, limit, offset);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved social feed for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting social feed:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve social feed'
    });
  }
};

// Get user social statistics
const getUserSocialStats = async (req, res) => {
  try {
    const { user } = req;

    const result = await socialService.getUserSocialStats(user.id);

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error
      });
    }

    logger.info(`Retrieved social stats for user ${user.id}`);

    res.json({
      success: true,
      data: result.data
    });
  } catch (error) {
    logger.error('Error getting user social stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve social statistics'
    });
  }
};

// Get friend suggestions
const getFriendSuggestions = async (req, res) => {
  try {
    const { user } = req;
    const { limit = 10 } = req.query;

    // Get user's current friends
    const friends = await db('friends')
      .where('user_id', user.id)
      .where('is_active', true)
      .select('friend_id');

    const friendIds = friends.map(f => f.friend_id);
    friendIds.push(user.id); // Exclude current user and friends

    // Get users who are not friends and have some activity
    const suggestions = await db('users')
      .whereNotIn('id', friendIds)
      .where('is_verified', true)
      .select('id', 'first_name', 'last_name', 'email', 'profile_picture_url')
      .limit(limit);

    // Add activity count for each suggestion
    const suggestionsWithActivity = await Promise.all(
      suggestions.map(async (suggestion) => {
        const [activityCount] = await db('social_activities')
          .where('user_id', suggestion.id)
          .where('is_public', true)
          .count('* as count');

        return {
          ...suggestion,
          activity_count: parseInt(activityCount.count)
        };
      })
    );

    // Sort by activity count
    suggestionsWithActivity.sort((a, b) => b.activity_count - a.activity_count);

    logger.info(`Retrieved friend suggestions for user ${user.id}`);

    res.json({
      success: true,
      data: {
        suggestions: suggestionsWithActivity
      }
    });
  } catch (error) {
    logger.error('Error getting friend suggestions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve friend suggestions'
    });
  }
};

module.exports = {
  sendFriendRequest,
  acceptFriendRequest,
  rejectFriendRequest,
  getFriendRequests,
  getFriends,
  removeFriend,
  searchUsers,
  getSocialFeed,
  getUserSocialStats,
  getFriendSuggestions
}; 