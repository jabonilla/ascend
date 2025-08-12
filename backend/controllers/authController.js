const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');
const { db } = require('../config/database');
const { redisUtils } = require('../config/redis');
const logger = require('../utils/logger');
const { sendVerificationEmail, sendOTP } = require('../services/emailService');

// Generate JWT token
const generateToken = (userId) => {
  return jwt.sign(
    { userId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
  );
};

// Generate refresh token
const generateRefreshToken = (userId) => {
  return jwt.sign(
    { userId, type: 'refresh' },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d' }
  );
};

// Register new user
const register = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { email, password, first_name, last_name, phone } = req.body;

    // Check if user already exists
    const existingUser = await db('users')
      .where('email', email)
      .orWhere('phone', phone)
      .first();

    if (existingUser) {
      return res.status(400).json({
        success: false,
        error: 'User with this email or phone already exists'
      });
    }

    // Hash password
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Generate verification token
    const verificationToken = jwt.sign(
      { email },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Create user
    const [user] = await db('users')
      .insert({
        email,
        password_hash: passwordHash,
        first_name,
        last_name,
        phone,
        verification_token: verificationToken
      })
      .returning(['id', 'email', 'first_name', 'last_name', 'phone', 'is_verified', 'created_at']);

    // Send verification email
    if (email) {
      await sendVerificationEmail(email, verificationToken, user.first_name);
    }

    // Send OTP if phone provided
    if (phone) {
      await sendOTP(phone);
    }

    // Generate tokens
    const token = generateToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    // Store refresh token in Redis
    await redisUtils.setEx(`refresh_token:${user.id}`, 30 * 24 * 60 * 60, refreshToken);

    logger.info(`New user registered: ${user.email}`);

    res.status(201).json({
      success: true,
      message: 'User registered successfully. Please verify your email/phone.',
      data: {
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          phone: user.phone,
          is_verified: user.is_verified
        },
        token,
        refresh_token: refreshToken
      }
    });
  } catch (error) {
    logger.error('Registration error:', error);
    res.status(500).json({
      success: false,
      error: 'Registration failed. Please try again.'
    });
  }
};

// Login user
const login = async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        details: errors.array()
      });
    }

    const { email, password } = req.body;

    // Find user
    const user = await db('users')
      .where('email', email)
      .first();

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    // Check if user is active
    if (!user.is_active) {
      return res.status(401).json({
        success: false,
        error: 'Account is deactivated'
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        error: 'Invalid credentials'
      });
    }

    // Update last login
    await db('users')
      .where('id', user.id)
      .update({ last_login_at: db.fn.now() });

    // Generate tokens
    const token = generateToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    // Store refresh token in Redis
    await redisUtils.setEx(`refresh_token:${user.id}`, 30 * 24 * 60 * 60, refreshToken);

    logger.info(`User logged in: ${user.email}`);

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          phone: user.phone,
          is_verified: user.is_verified
        },
        token,
        refresh_token: refreshToken
      }
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed. Please try again.'
    });
  }
};

// Logout user
const logout = async (req, res) => {
  try {
    const { token } = req;
    const { user } = req;

    // Blacklist current token
    await redisUtils.setEx(`blacklist:${token}`, 24 * 60 * 60, true);

    // Remove refresh token
    await redisUtils.del(`refresh_token:${user.id}`);

    logger.info(`User logged out: ${user.email}`);

    res.json({
      success: true,
      message: 'Logout successful'
    });
  } catch (error) {
    logger.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Logout failed'
    });
  }
};

// Refresh token
const refreshToken = async (req, res) => {
  try {
    const { refresh_token } = req.body;

    if (!refresh_token) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token is required'
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(refresh_token, process.env.JWT_SECRET);
    
    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        success: false,
        error: 'Invalid refresh token'
      });
    }

    // Check if refresh token exists in Redis
    const storedToken = await redisUtils.get(`refresh_token:${decoded.userId}`);
    if (!storedToken || storedToken !== refresh_token) {
      return res.status(401).json({
        success: false,
        error: 'Refresh token is invalid or expired'
      });
    }

    // Generate new tokens
    const newToken = generateToken(decoded.userId);
    const newRefreshToken = generateRefreshToken(decoded.userId);

    // Update refresh token in Redis
    await redisUtils.setEx(`refresh_token:${decoded.userId}`, 30 * 24 * 60 * 60, newRefreshToken);

    res.json({
      success: true,
      message: 'Token refreshed successfully',
      data: {
        token: newToken,
        refresh_token: newRefreshToken
      }
    });
  } catch (error) {
    logger.error('Token refresh error:', error);
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Refresh token expired'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Token refresh failed'
    });
  }
};

// Verify email
const verifyEmail = async (req, res) => {
  try {
    const { token } = req.params;

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Update user
    const [user] = await db('users')
      .where('email', decoded.email)
      .where('verification_token', token)
      .update({
        is_verified: true,
        email_verified_at: db.fn.now(),
        verification_token: null
      })
      .returning(['id', 'email', 'first_name', 'is_verified']);

    if (!user) {
      return res.status(400).json({
        success: false,
        error: 'Invalid or expired verification token'
      });
    }

    logger.info(`Email verified: ${user.email}`);

    res.json({
      success: true,
      message: 'Email verified successfully'
    });
  } catch (error) {
    logger.error('Email verification error:', error);
    
    if (error.name === 'TokenExpiredError') {
      return res.status(400).json({
        success: false,
        error: 'Verification token expired'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Email verification failed'
    });
  }
};

// Verify OTP
const verifyOTP = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    // Verify OTP (implementation depends on your SMS service)
    const isValidOTP = await verifyOTPWithService(phone, otp);

    if (!isValidOTP) {
      return res.status(400).json({
        success: false,
        error: 'Invalid OTP'
      });
    }

    // Update user
    const [user] = await db('users')
      .where('phone', phone)
      .update({
        is_verified: true,
        phone_verified_at: db.fn.now()
      })
      .returning(['id', 'phone', 'is_verified']);

    if (!user) {
      return res.status(400).json({
        success: false,
        error: 'User not found'
      });
    }

    logger.info(`Phone verified: ${user.phone}`);

    res.json({
      success: true,
      message: 'Phone verified successfully'
    });
  } catch (error) {
    logger.error('OTP verification error:', error);
    res.status(500).json({
      success: false,
      error: 'OTP verification failed'
    });
  }
};

// Helper function to verify OTP (implement based on your SMS service)
const verifyOTPWithService = async (phone, otp) => {
  // This is a placeholder - implement based on your SMS service
  // For example, with Twilio Verify:
  // const twilio = require('twilio');
  // const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  // const verification = await client.verify.v2.services(process.env.TWILIO_VERIFY_SERVICE_SID)
  //   .verificationChecks.create({ to: phone, code: otp });
  // return verification.status === 'approved';
  
  // For now, return true for development
  return true;
};

module.exports = {
  register,
  login,
  logout,
  refreshToken,
  verifyEmail,
  verifyOTP
}; 