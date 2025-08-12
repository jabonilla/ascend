const jwt = require('jsonwebtoken');
const { logger } = require('./logger');

const generateTokens = (userId) => {
  try {
    const accessToken = jwt.sign(
      { userId },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_ACCESS_EXPIRY || '15m' }
    );

    const refreshToken = jwt.sign(
      { userId },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d' }
    );

    return { accessToken, refreshToken };
  } catch (error) {
    logger.error('Error generating tokens:', error);
    throw new Error('Failed to generate tokens');
  }
};

const verifyAccessToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    logger.error('Error verifying access token:', error);
    return null;
  }
};

const verifyRefreshToken = (token) => {
  try {
    return jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    logger.error('Error verifying refresh token:', error);
    return null;
  }
};

const decodeToken = (token) => {
  try {
    return jwt.decode(token);
  } catch (error) {
    logger.error('Error decoding token:', error);
    return null;
  }
};

module.exports = {
  generateTokens,
  verifyAccessToken,
  verifyRefreshToken,
  decodeToken
};
