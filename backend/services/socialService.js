const { db } = require('../config/database');
const logger = require('../utils/logger');
const { v4: uuidv4 } = require('uuid');

// Send friend request
const sendFriendRequest = async (fromUserId, toUserId, message = null) => {
  try {
    // Check if users exist
    const [fromUser, toUser] = await Promise.all([
      db('users').where('id', fromUserId).first(),
      db('users').where('id', toUserId).first()
    ]);

    if (!fromUser || !toUser) {
      return {
        success: false,
        error: 'User not found'
      };
    }

    // Check if they're already friends
    const existingFriendship = await db('friends')
      .where('user_id', fromUserId)
      .where('friend_id', toUserId)
      .where('is_active', true)
      .first();

    if (existingFriendship) {
      return {
        success: false,
        error: 'Users are already friends'
      };
    }

    // Check if there's already a pending request
    const existingRequest = await db('friend_requests')
      .where('from_user_id', fromUserId)
      .where('to_user_id', toUserId)
      .where('status', 'pending')
      .first();

    if (existingRequest) {
      return {
        success: false,
        error: 'Friend request already sent'
      };
    }

    // Create friend request
    const [request] = await db('friend_requests').insert({
      from_user_id: fromUserId,
      to_user_id: toUserId,
      message,
      status: 'pending'
    }).returning('*');

    // Create social activity
    await createSocialActivity(fromUserId, 'friend_request_sent', {
      to_user_id: toUserId,
      to_user_name: `${toUser.first_name} ${toUser.last_name}`
    });

    logger.info(`Friend request sent from ${fromUserId} to ${toUserId}`);

    return {
      success: true,
      data: {
        request,
        to_user: {
          id: toUser.id,
          first_name: toUser.first_name,
          last_name: toUser.last_name,
          email: toUser.email
        }
      }
    };
  } catch (error) {
    logger.error('Error sending friend request:', error);
    return {
      success: false,
      error: 'Failed to send friend request'
    };
  }
};

// Accept friend request
const acceptFriendRequest = async (userId, requestId) => {
  try {
    // Get the friend request
    const request = await db('friend_requests')
      .where('id', requestId)
      .where('to_user_id', userId)
      .where('status', 'pending')
      .first();

    if (!request) {
      return {
        success: false,
        error: 'Friend request not found or already processed'
      };
    }

    await db.transaction(async (trx) => {
      // Update request status
      await trx('friend_requests')
        .where('id', requestId)
        .update({
          status: 'accepted',
          updated_at: trx.fn.now()
        });

      // Create friendship records (bidirectional)
      await trx('friends').insert([
        {
          user_id: request.from_user_id,
          friend_id: request.to_user_id
        },
        {
          user_id: request.to_user_id,
          friend_id: request.from_user_id
        }
      ]);

      // Create social activities
      await Promise.all([
        createSocialActivity(request.from_user_id, 'friend_request_accepted', {
          by_user_id: request.to_user_id
        }),
        createSocialActivity(request.to_user_id, 'friend_added', {
          friend_user_id: request.from_user_id
        })
      ]);
    });

    logger.info(`Friend request ${requestId} accepted by user ${userId}`);

    return {
      success: true,
      message: 'Friend request accepted'
    };
  } catch (error) {
    logger.error('Error accepting friend request:', error);
    return {
      success: false,
      error: 'Failed to accept friend request'
    };
  }
};

// Reject friend request
const rejectFriendRequest = async (userId, requestId) => {
  try {
    const request = await db('friend_requests')
      .where('id', requestId)
      .where('to_user_id', userId)
      .where('status', 'pending')
      .first();

    if (!request) {
      return {
        success: false,
        error: 'Friend request not found or already processed'
      };
    }

    await db('friend_requests')
      .where('id', requestId)
      .update({
        status: 'rejected',
        updated_at: db.fn.now()
      });

    logger.info(`Friend request ${requestId} rejected by user ${userId}`);

    return {
      success: true,
      message: 'Friend request rejected'
    };
  } catch (error) {
    logger.error('Error rejecting friend request:', error);
    return {
      success: false,
      error: 'Failed to reject friend request'
    };
  }
};

// Get friend requests
const getFriendRequests = async (userId, status = 'pending') => {
  try {
    const requests = await db('friend_requests')
      .join('users', 'friend_requests.from_user_id', 'users.id')
      .where('friend_requests.to_user_id', userId)
      .where('friend_requests.status', status)
      .select(
        'friend_requests.*',
        'users.first_name',
        'users.last_name',
        'users.email'
      )
      .orderBy('friend_requests.created_at', 'desc');

    return {
      success: true,
      data: {
        requests
      }
    };
  } catch (error) {
    logger.error('Error getting friend requests:', error);
    return {
      success: false,
      error: 'Failed to retrieve friend requests'
    };
  }
};

// Get friends list
const getFriends = async (userId) => {
  try {
    const friends = await db('friends')
      .join('users', 'friends.friend_id', 'users.id')
      .where('friends.user_id', userId)
      .where('friends.is_active', true)
      .select(
        'users.id',
        'users.first_name',
        'users.last_name',
        'users.email',
        'users.profile_picture_url',
        'friends.created_at as friendship_date'
      )
      .orderBy('users.first_name', 'asc');

    return {
      success: true,
      data: {
        friends
      }
    };
  } catch (error) {
    logger.error('Error getting friends:', error);
    return {
      success: false,
      error: 'Failed to retrieve friends'
    };
  }
};

// Remove friend
const removeFriend = async (userId, friendId) => {
  try {
    // Check if friendship exists
    const friendship = await db('friends')
      .where('user_id', userId)
      .where('friend_id', friendId)
      .where('is_active', true)
      .first();

    if (!friendship) {
      return {
        success: false,
        error: 'Friendship not found'
      };
    }

    // Deactivate both friendship records
    await db('friends')
      .where(function() {
        this.where('user_id', userId).where('friend_id', friendId)
          .orWhere('user_id', friendId).where('friend_id', userId);
      })
      .update({
        is_active: false,
        updated_at: db.fn.now()
      });

    logger.info(`Friendship removed between users ${userId} and ${friendId}`);

    return {
      success: true,
      message: 'Friend removed successfully'
    };
  } catch (error) {
    logger.error('Error removing friend:', error);
    return {
      success: false,
      error: 'Failed to remove friend'
    };
  }
};

// Search users by email or name
const searchUsers = async (userId, query, limit = 10) => {
  try {
    const users = await db('users')
      .where('id', '!=', userId) // Exclude current user
      .where(function() {
        this.where('email', 'like', `%${query}%`)
          .orWhere('first_name', 'like', `%${query}%`)
          .orWhere('last_name', 'like', `%${query}%`);
      })
      .select('id', 'first_name', 'last_name', 'email', 'profile_picture_url')
      .limit(limit);

    // Check friendship status for each user
    const usersWithStatus = await Promise.all(
      users.map(async (user) => {
        const friendship = await db('friends')
          .where('user_id', userId)
          .where('friend_id', user.id)
          .where('is_active', true)
          .first();

        const pendingRequest = await db('friend_requests')
          .where('from_user_id', userId)
          .where('to_user_id', user.id)
          .where('status', 'pending')
          .first();

        return {
          ...user,
          friendship_status: friendship ? 'friends' : pendingRequest ? 'request_sent' : 'none'
        };
      })
    );

    return {
      success: true,
      data: {
        users: usersWithStatus
      }
    };
  } catch (error) {
    logger.error('Error searching users:', error);
    return {
      success: false,
      error: 'Failed to search users'
    };
  }
};

// Create social activity
const createSocialActivity = async (userId, activityType, activityData = {}) => {
  try {
    const [activity] = await db('social_activities').insert({
      user_id: userId,
      activity_type: activityType,
      activity_data: activityData
    }).returning('*');

    logger.info(`Social activity created: ${activityType} for user ${userId}`);

    return {
      success: true,
      data: activity
    };
  } catch (error) {
    logger.error('Error creating social activity:', error);
    return {
      success: false,
      error: 'Failed to create social activity'
    };
  }
};

// Get social activity feed
const getSocialFeed = async (userId, limit = 20, offset = 0) => {
  try {
    // Get user's friends
    const friends = await db('friends')
      .where('user_id', userId)
      .where('is_active', true)
      .select('friend_id');

    const friendIds = friends.map(f => f.friend_id);
    friendIds.push(userId); // Include user's own activities

    // Get public activities from user and friends
    const activities = await db('social_activities')
      .join('users', 'social_activities.user_id', 'users.id')
      .whereIn('social_activities.user_id', friendIds)
      .where('social_activities.is_public', true)
      .select(
        'social_activities.*',
        'users.first_name',
        'users.last_name',
        'users.profile_picture_url'
      )
      .orderBy('social_activities.created_at', 'desc')
      .limit(limit)
      .offset(offset);

    // Get total count for pagination
    const [{ count }] = await db('social_activities')
      .whereIn('user_id', friendIds)
      .where('is_public', true)
      .count('* as count');

    return {
      success: true,
      data: {
        activities,
        pagination: {
          total: parseInt(count),
          limit: parseInt(limit),
          offset: parseInt(offset),
          has_more: parseInt(offset) + activities.length < parseInt(count)
        }
      }
    };
  } catch (error) {
    logger.error('Error getting social feed:', error);
    return {
      success: false,
      error: 'Failed to retrieve social feed'
    };
  }
};

// Get user's social statistics
const getUserSocialStats = async (userId) => {
  try {
    const [friendCount] = await db('friends')
      .where('user_id', userId)
      .where('is_active', true)
      .count('* as count');

    const [pendingRequests] = await db('friend_requests')
      .where('to_user_id', userId)
      .where('status', 'pending')
      .count('* as count');

    const [sentRequests] = await db('friend_requests')
      .where('from_user_id', userId)
      .where('status', 'pending')
      .count('* as count');

    const [activityCount] = await db('social_activities')
      .where('user_id', userId)
      .count('* as count');

    return {
      success: true,
      data: {
        friends_count: parseInt(friendCount.count),
        pending_requests_count: parseInt(pendingRequests.count),
        sent_requests_count: parseInt(sentRequests.count),
        activities_count: parseInt(activityCount.count)
      }
    };
  } catch (error) {
    logger.error('Error getting user social stats:', error);
    return {
      success: false,
      error: 'Failed to retrieve social statistics'
    };
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
  createSocialActivity,
  getSocialFeed,
  getUserSocialStats
}; 