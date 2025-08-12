const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
require('dotenv').config();

// Import middleware
const { authMiddleware } = require('./middleware/authMiddleware');
const { errorHandler } = require('./middleware/errorHandler');
const { notFoundHandler } = require('./middleware/notFoundHandler');

// Import routes
const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const debtRoutes = require('./routes/debts');
const paymentRoutes = require('./routes/payments');
const optimizationRoutes = require('./routes/optimization');
const plaidRoutes = require('./routes/plaid');
const analyticsRoutes = require('./routes/analytics');
const communityRoutes = require('./routes/community');
const calculatorRoutes = require('./routes/calculator');
const consolidationRoutes = require('./routes/consolidation');
const discoveryRoutes = require('./routes/discovery');
const notificationRoutes = require('./routes/notifications');
const webhookRoutes = require('./routes/webhooks');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://localhost:8081'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
}));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression middleware
app.use(compression());

// Logging middleware
app.use(morgan('combined'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0'
  });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', authMiddleware, userRoutes);
app.use('/api/debts', authMiddleware, debtRoutes);
app.use('/api/payments', authMiddleware, paymentRoutes);
app.use('/api/optimization', authMiddleware, optimizationRoutes);
app.use('/api/plaid', authMiddleware, plaidRoutes);
app.use('/api/analytics', authMiddleware, analyticsRoutes);
app.use('/api/community', authMiddleware, communityRoutes);
app.use('/api/calculator', authMiddleware, calculatorRoutes);
app.use('/api/consolidation', authMiddleware, consolidationRoutes);
app.use('/api/discovery', authMiddleware, discoveryRoutes);
app.use('/api/notifications', authMiddleware, notificationRoutes);
app.use('/api/webhooks', webhookRoutes);

// Error handling middleware
app.use(errorHandler);

// 404 handler
app.use(notFoundHandler);

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Ascend API Server running on port ${PORT}`);
  console.log(`🏥 Health check available at http://localhost:${PORT}/health`);
  console.log(`📚 API Documentation available at http://localhost:${PORT}/api-docs`);
});

module.exports = app;
