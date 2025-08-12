const http = require('http');

const PORT = process.env.PORT || 3000;

// In-memory storage for demo
let users = [];
let debts = [];

// Create HTTP server
const server = http.createServer((req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Parse URL
  const url = req.url;
  const method = req.method;
  
  // Parse request body
  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });
  
  req.on('end', () => {
    let requestData = {};
    if (body) {
      try {
        requestData = JSON.parse(body);
      } catch (e) {
        console.error('Error parsing JSON:', e);
      }
    }
    
    // Route handling
    if (url === '/' || url === '/index.html') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        message: 'Hello from Ascend API!',
        version: '1.0.0',
        timestamp: new Date().toISOString()
      }));
    } else if (url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
      }));
    } else if (url === '/api/test') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        message: 'API is working!',
        timestamp: new Date().toISOString()
      }));
    } else if (url === '/api/auth/register' && method === 'POST') {
      // Registration endpoint
      const { email, password, firstName, lastName, phone } = requestData;
      
      if (!email || !password || !firstName || !lastName) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: {
            message: 'Missing required fields',
            code: 'VALIDATION_ERROR'
          }
        }));
        return;
      }
      
      // Check if user already exists
      if (users.find(u => u.email === email)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: {
            message: 'User already exists',
            code: 'USER_EXISTS'
          }
        }));
        return;
      }
      
      // Create new user
      const newUser = {
        id: `user_${Date.now()}`,
        email,
        firstName,
        lastName,
        phone: phone || '',
        isPremium: false,
        createdAt: new Date().toISOString()
      };
      
      users.push(newUser);
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        data: {
          user: newUser,
          tokens: {
            accessToken: `access_${newUser.id}_${Date.now()}`,
            refreshToken: `refresh_${newUser.id}_${Date.now()}`
          }
        }
      }));
    } else if (url === '/api/auth/login' && method === 'POST') {
      // Login endpoint
      const { email, password } = requestData;
      
      if (!email || !password) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: {
            message: 'Email and password required',
            code: 'VALIDATION_ERROR'
          }
        }));
        return;
      }
      
      const user = users.find(u => u.email === email);
      
      if (!user) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: {
            message: 'Invalid credentials',
            code: 'AUTH_ERROR'
          }
        }));
        return;
      }
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        data: {
          user: {
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            isPremium: user.isPremium,
            lastLoginAt: new Date().toISOString()
          },
          tokens: {
            accessToken: `access_${user.id}_${Date.now()}`,
            refreshToken: `refresh_${user.id}_${Date.now()}`
          }
        }
      }));
    } else if (url === '/api/users/profile' && method === 'GET') {
      // Get user profile
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.writeHead(401, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          success: false,
          error: {
            message: 'Unauthorized',
            code: 'UNAUTHORIZED'
          }
        }));
        return;
      }
      
      // For demo, return a mock user
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        data: {
          id: 'test-user-id',
          email: 'test@example.com',
          firstName: 'Test',
          lastName: 'User',
          phone: '+1234567890',
          isPremium: false,
          createdAt: new Date().toISOString()
        }
      }));
    } else if (url === '/api/debts' && method === 'GET') {
      // Get debts
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        data: {
          debts: [
            {
              id: 'debt-1',
              name: 'Credit Card',
              balance: 5000.00,
              interestRate: 18.99,
              minimumPayment: 150.00,
              dueDate: '2024-01-15',
              status: 'active',
              category: 'credit_card',
              createdAt: new Date().toISOString()
            }
          ],
          pagination: {
            page: 1,
            limit: 10,
            total: 1,
            totalPages: 1
          }
        }
      }));
    } else if (url === '/api/debts' && method === 'POST') {
      // Create debt
      const { name, balance, interestRate, minimumPayment, dueDate, category } = requestData;
      
      const newDebt = {
        id: `debt_${Date.now()}`,
        name,
        balance,
        interestRate,
        minimumPayment,
        dueDate,
        status: 'active',
        category,
        createdAt: new Date().toISOString()
      };
      
      debts.push(newDebt);
      
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        data: newDebt
      }));
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: 'Not Found',
        message: `Route ${url} not found`
      }));
    }
  });
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🌐 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`⏰ Started at: ${new Date().toISOString()}`);
  console.log(`📊 Process ID: ${process.pid}`);
  console.log(`🔗 Available endpoints:`);
  console.log(`   - GET  /health`);
  console.log(`   - GET  /api/test`);
  console.log(`   - POST /api/auth/register`);
  console.log(`   - GET  /api/auth/login`);
  console.log(`   - GET  /api/users/profile`);
  console.log(`   - GET  /api/debts`);
  console.log(`   - POST /api/debts`);
});

// Error handling
server.on('error', (error) => {
  console.error('Server error:', error);
});

process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});
