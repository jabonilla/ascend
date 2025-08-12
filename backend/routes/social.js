const express = require('express');
const { body, param, query } = require('express-validator');
const {
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
} = require('../controllers/socialController');
const {
  createGroupGoal,
  getGroupGoal,
  joinGroupGoal,
  leaveGroupGoal,
  contributeToGroupGoal,
  getGroupGoalContributions,
  getUserGroupGoals,
  searchPublicGroupGoals,
  getGroupGoalStats
} = require('../controllers/groupGoalsController');

const router = express.Router();

// Validation middleware
const sendFriendRequestValidation = [
  body('to_user_id')
    .isUUID()
    .withMessage('Invalid user ID'),
  body('message')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Message must be less than 200 characters')
];

const requestIdValidation = [
  param('request_id')
    .isUUID()
    .withMessage('Invalid request ID')
];

const friendIdValidation = [
  param('friend_id')
    .isUUID()
    .withMessage('Invalid friend ID')
];

const searchUsersValidation = [
  query('q')
    .notEmpty()
    .withMessage('Search query is required')
    .isLength({ min: 2 })
    .withMessage('Search query must be at least 2 characters'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limit must be between 1 and 50')
];

const getFeedValidation = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer')
];

const getSuggestionsValidation = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 20 })
    .withMessage('Limit must be between 1 and 20')
];

// Group goal validation
const createGroupGoalValidation = [
  body('name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('Group goal name is required and must be less than 100 characters'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description must be less than 500 characters'),
  body('target_amount')
    .isFloat({ min: 0.01 })
    .withMessage('Target amount must be a positive number'),
  body('category')
    .isIn(['fashion', 'electronics', 'travel', 'entertainment', 'food', 'custom'])
    .withMessage('Category must be one of: fashion, electronics, travel, entertainment, food, custom'),
  body('image_url')
    .optional()
    .isURL()
    .withMessage('Image URL must be a valid URL'),
  body('product_url')
    .optional()
    .isURL()
    .withMessage('Product URL must be a valid URL'),
  body('round_up_amount')
    .optional()
    .isFloat({ min: 0.50, max: 10.00 })
    .withMessage('Round-up amount must be between $0.50 and $10.00'),
  body('target_date')
    .optional()
    .isISO8601()
    .withMessage('Target date must be a valid date'),
  body('max_participants')
    .optional()
    .isInt({ min: 2, max: 50 })
    .withMessage('Max participants must be between 2 and 50'),
  body('is_public')
    .optional()
    .isBoolean()
    .withMessage('Is public must be a boolean')
];

const joinGroupGoalValidation = [
  body('invite_code')
    .notEmpty()
    .withMessage('Invite code is required')
    .isLength({ min: 6, max: 6 })
    .withMessage('Invite code must be 6 characters')
];

const contributeToGroupGoalValidation = [
  body('amount')
    .isFloat({ min: 0.01 })
    .withMessage('Contribution amount must be a positive number'),
  body('message')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Message must be less than 200 characters'),
  body('is_anonymous')
    .optional()
    .isBoolean()
    .withMessage('Is anonymous must be a boolean')
];

const groupGoalIdValidation = [
  param('id')
    .isUUID()
    .withMessage('Invalid group goal ID')
];

const getGroupGoalsValidation = [
  query('status')
    .optional()
    .isIn(['active', 'completed'])
    .withMessage('Status must be either "active" or "completed"')
];

const searchGroupGoalsValidation = [
  query('q')
    .optional()
    .trim()
    .isLength({ min: 1 })
    .withMessage('Search query must not be empty'),
  query('category')
    .optional()
    .isIn(['fashion', 'electronics', 'travel', 'entertainment', 'food', 'custom'])
    .withMessage('Category must be one of: fashion, electronics, travel, entertainment, food, custom'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 50 })
    .withMessage('Limit must be between 1 and 50'),
  query('offset')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Offset must be a non-negative integer')
];

// Friend management routes
router.post('/friends/request', sendFriendRequestValidation, sendFriendRequest);
router.post('/friends/requests/:request_id/accept', requestIdValidation, acceptFriendRequest);
router.post('/friends/requests/:request_id/reject', requestIdValidation, rejectFriendRequest);
router.get('/friends/requests', getFriendRequests);
router.get('/friends', getFriends);
router.delete('/friends/:friend_id', friendIdValidation, removeFriend);

// User search and discovery
router.get('/users/search', searchUsersValidation, searchUsers);
router.get('/users/suggestions', getSuggestionsValidation, getFriendSuggestions);

// Social feed and activity
router.get('/feed', getFeedValidation, getSocialFeed);
router.get('/stats', getUserSocialStats);

// Group goals routes
router.post('/group-goals', createGroupGoalValidation, createGroupGoal);
router.get('/group-goals', getGroupGoalsValidation, getUserGroupGoals);
router.get('/group-goals/search', searchGroupGoalsValidation, searchPublicGroupGoals);
router.get('/group-goals/stats', getGroupGoalStats);
router.get('/group-goals/:id', groupGoalIdValidation, getGroupGoal);
router.post('/group-goals/join', joinGroupGoalValidation, joinGroupGoal);
router.delete('/group-goals/:id/leave', groupGoalIdValidation, leaveGroupGoal);
router.post('/group-goals/:id/contribute', groupGoalIdValidation, contributeToGroupGoalValidation, contributeToGroupGoal);
router.get('/group-goals/:id/contributions', groupGoalIdValidation, getGroupGoalContributions);

module.exports = router; 