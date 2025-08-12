const jwt = require('jsonwebtoken');
const { logger } = require('../utils/logger');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Access token required',
          code: 'MISSING_TOKEN'
        }
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid token format',
          code: 'INVALID_TOKEN_FORMAT'
        }
      });
    }

    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (!decoded || !decoded.userId) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid token',
          code: 'INVALID_TOKEN'
        }
      });
    }

    // Check if token is expired
    if (decoded.exp && Date.now() >= decoded.exp * 1000) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Token expired',
          code: 'TOKEN_EXPIRED'
        }
      });
    }

    // Add user info to request object
    req.userId = decoded.userId;
    req.user = decoded;
    
    // Log successful authentication
    logger.info(`User ${decoded.userId} authenticated successfully`);
    
    next();
  } catch (error) {
    logger.error('Authentication error:', error);
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid token',
          code: 'INVALID_TOKEN'
        }
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Token expired',
          code: 'TOKEN_EXPIRED'
        }
      });
    }
    
    return res.status(500).json({
      success: false,
      error: {
        message: 'Authentication failed',
        code: 'AUTH_ERROR'
      }
    });
  }
};

// Optional authentication middleware for routes that can work with or without auth
const optionalAuthMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next(); // Continue without authentication
    }

    const token = authHeader.substring(7);
    
    if (!token) {
      return next(); // Continue without authentication
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    if (decoded && decoded.userId) {
      req.userId = decoded.userId;
      req.user = decoded;
    }
    
    next();
  } catch (error) {
    // Continue without authentication on error
    next();
  }
};

// Role-based authorization middleware
const requireRole = (roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Authentication required',
          code: 'AUTH_REQUIRED'
        }
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: {
          message: 'Insufficient permissions',
          code: 'INSUFFICIENT_PERMISSIONS'
        }
      });
    }

    next();
  };
};

// Admin-only middleware
const requireAdmin = requireRole(['admin']);

// Premium user middleware
const requirePremium = (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: {
        message: 'Authentication required',
        code: 'AUTH_REQUIRED'
      }
    });
  }

  if (!req.user.isPremium) {
    return res.status(403).json({
      success: false,
      error: {
        message: 'Premium subscription required',
        code: 'PREMIUM_REQUIRED'
      }
    });
  }

  next();
};

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
  requireRole,
  requireAdmin,
  requirePremium
};
