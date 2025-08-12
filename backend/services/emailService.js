const sgMail = require('@sendgrid/mail');
const logger = require('../utils/logger');

// Initialize SendGrid
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

// Send verification email
const sendVerificationEmail = async (email, token, firstName) => {
  try {
    const verificationUrl = `${process.env.API_URL}/api/auth/verify-email/${token}`;
    
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: 'Verify your RoundUp Savings account',
      templateId: 'd-verification-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        verification_url: verificationUrl,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`Verification email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending verification email:', error);
    return false;
  }
};

// Send welcome email
const sendWelcomeEmail = async (email, firstName) => {
  try {
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: 'Welcome to RoundUp Savings!',
      templateId: 'd-welcome-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`Welcome email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending welcome email:', error);
    return false;
  }
};

// Send password reset email
const sendPasswordResetEmail = async (email, token, firstName) => {
  try {
    const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${token}`;
    
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: 'Reset your RoundUp Savings password',
      templateId: 'd-password-reset-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        reset_url: resetUrl,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`Password reset email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending password reset email:', error);
    return false;
  }
};

// Send goal completion email
const sendGoalCompletionEmail = async (email, firstName, goalName, amount) => {
  try {
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: `Congratulations! You've reached your goal: ${goalName}`,
      templateId: 'd-goal-completion-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        goal_name: goalName,
        amount: amount,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`Goal completion email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending goal completion email:', error);
    return false;
  }
};

// Send weekly summary email
const sendWeeklySummaryEmail = async (email, firstName, summary) => {
  try {
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: 'Your RoundUp Savings Weekly Summary',
      templateId: 'd-weekly-summary-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        summary: summary,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`Weekly summary email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending weekly summary email:', error);
    return false;
  }
};

// Send OTP via email (fallback for SMS)
const sendOTPEmail = async (email, otp, firstName) => {
  try {
    const msg = {
      to: email,
      from: process.env.SENDGRID_FROM_EMAIL || 'noreply@roundup-savings.com',
      subject: 'Your RoundUp Savings verification code',
      templateId: 'd-otp-template-id', // Replace with your SendGrid template ID
      dynamicTemplateData: {
        first_name: firstName,
        otp: otp,
        app_name: 'RoundUp Savings'
      }
    };

    await sgMail.send(msg);
    logger.info(`OTP email sent to: ${email}`);
    return true;
  } catch (error) {
    logger.error('Error sending OTP email:', error);
    return false;
  }
};

module.exports = {
  sendVerificationEmail,
  sendWelcomeEmail,
  sendPasswordResetEmail,
  sendGoalCompletionEmail,
  sendWeeklySummaryEmail,
  sendOTPEmail
}; 