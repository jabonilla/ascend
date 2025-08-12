const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

// Basic middleware
app.use(cors());
app.use(express.json());

// Simple health check endpoint
app.get('/health', (req, res) => {
  console.log('Health check requested');
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: '1.0.0',
    message: 'Ascend API is running!',
    port: PORT,
    host: HOST
  });
});

// Root endpoint
app.get('/', (req, res) => {
  console.log('Root endpoint requested');
  res.json({
    message: 'Welcome to Ascend API',
    version: '1.0.0',
    status: 'running',
    port: PORT,
    host: HOST
  });
});

// Start server
app.listen(PORT, HOST, () => {
  console.log(`🚀 Ascend API Server running on ${HOST}:${PORT}`);
  console.log(`�� Health check available at http://${HOST}:${PORT}/health`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`📊 Process ID: ${process.pid}`);
  console.log(`⏰ Started at: ${new Date().toISOString()}`);
});

module.exports = app;
// Redeploy trigger
// Full Supabase integration deployed
