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

    // For demo purposes, accept any token that starts with 'access_'
    if (!token.startsWith('access_')) {
      return res.status(401).json({
        success: false,
        error: {
          message: 'Invalid token',
          code: 'INVALID_TOKEN'
        }
      });
    }

    // Extract userId from token (demo format: access_userId_timestamp)
    const parts = token.split('_');
    if (parts.length >= 2) {
      req.userId = parts[1];
      req.user = { userId: parts[1] };
    } else {
      req.userId = 'demo-user-id';
      req.user = { userId: 'demo-user-id' };
    }
    
    console.log(`User ${req.userId} authenticated successfully`);
    
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    
    return res.status(500).json({
      success: false,
      error: {
        message: 'Authentication failed',
        code: 'AUTH_ERROR'
      }
    });
  }
};

module.exports = { authMiddleware };
