const express = require('express');
const app = express();
const PORT = 3000;

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running!' });
});

// Test auth endpoint
app.post('/api/auth/register', (req, res) => {
  res.json({
    success: true,
    data: {
      user: {
        id: 'test-user-id',
        email: req.body.email,
        firstName: req.body.firstName,
        lastName: req.body.lastName
      },
      tokens: {
        accessToken: 'access_test-user-id_1234567890',
        refreshToken: 'refresh_test-user-id_1234567890'
      }
    }
  });
});

// Test protected endpoint
app.get('/api/users/profile', (req, res) => {
  res.json({
    success: true,
    data: {
      id: 'test-user-id',
      email: 'test@example.com',
      firstName: 'Test',
      lastName: 'User'
    }
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Simple test server running on port ${PORT}`);
  console.log(`🏥 Health check: http://localhost:${PORT}/health`);
});
