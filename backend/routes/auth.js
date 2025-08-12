const express = require('express');
const { body } = require('express-validator');
const { auth } = require('../middleware/auth');
const {
  register,
  login,
  logout,
  refreshToken,
  verifyEmail,
  verifyOTP
} = require('../controllers/authController');

const router = express.Router();

// Validation middleware
const registerValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters long')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .withMessage('Password must contain at least one uppercase letter, one lowercase letter, and one number'),
  body('first_name')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('First name is required and must be less than 50 characters'),
  body('last_name')
    .trim()
    .isLength({ min: 1, max: 50 })
    .withMessage('Last name is required and must be less than 50 characters'),
  body('phone')
    .optional()
    .isMobilePhone()
    .withMessage('Please provide a valid phone number')
];

const loginValidation = [
  body('email')
    .isEmail()
    .normalizeEmail()
    .withMessage('Please provide a valid email'),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
];

const refreshTokenValidation = [
  body('refresh_token')
    .notEmpty()
    .withMessage('Refresh token is required')
];

const verifyOTPValidation = [
  body('phone')
    .isMobilePhone()
    .withMessage('Please provide a valid phone number'),
  body('otp')
    .isLength({ min: 4, max: 6 })
    .isNumeric()
    .withMessage('OTP must be 4-6 digits')
];

// Routes
router.post('/register', registerValidation, register);
router.post('/login', loginValidation, login);
router.post('/logout', auth, logout);
router.post('/refresh', refreshTokenValidation, refreshToken);
router.get('/verify-email/:token', verifyEmail);
router.post('/verify-otp', verifyOTPValidation, verifyOTP);

module.exports = router; 