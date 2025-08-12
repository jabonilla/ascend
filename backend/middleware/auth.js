const jwt = require('jsonwebtoken');
const { db } = require('../config/database');
const { redisUtils } = require('../config/redis');
const logger = require('../utils/logger');

const auth = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Access denied. No token provided.'
      });
    }

    const token = authHeader.replace('Bearer ', '');

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if token is blacklisted
    const isBlacklisted = await redisUtils.get(`blacklist:${token}`);
    if (isBlacklisted) {
      return res.status(401).json({
        success: false,
        error: 'Token has been invalidated.'
      });
    }

    // Get user from database
    const user = await db('users')
      .where('id', decoded.userId)
      .select('id', 'email', 'first_name', 'last_name', 'phone', 'is_verified', 'created_at', 'updated_at')
      .first();

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'User not found.'
      });
    }

    // Check if user is verified (optional for some routes)
    if (req.requireVerification && !user.is_verified) {
      return res.status(403).json({
        success: false,
        error: 'Account not verified. Please verify your email/phone.'
      });
    }

    // Add user to request object
    req.user = user;
    req.token = token;
    
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expired. Please login again.'
      });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: 'Invalid token.'
      });
    }

    return res.status(500).json({
      success: false,
      error: 'Authentication failed.'
    });
  }
};

// Optional authentication middleware
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.replace('Bearer ', '');
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await db('users')
      .where('id', decoded.userId)
      .select('id', 'email', 'first_name', 'last_name', 'phone', 'is_verified')
      .first();

    if (user) {
      req.user = user;
      req.token = token;
    }
    
    next();
  } catch (error) {
    // Continue without authentication
    next();
  }
};

// Require verification middleware
const requireVerification = (req, res, next) => {
  req.requireVerification = true;
  next();
};

module.exports = {
  auth,
  optionalAuth,
  requireVerification
}; 