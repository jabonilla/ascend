const axios = require('axios');

// Configuration
const BASE_URL = 'http://localhost:3000';
const TEST_USER = {
  email: 'test@ascend.com',
  password: 'testpassword123',
  firstName: 'Test',
  lastName: 'User'
};

let authToken = null;
let userId = null;

// Test utilities
const api = axios.create({
  baseURL: BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add auth token to requests
api.interceptors.request.use(config => {
  if (authToken) {
    config.headers.Authorization = `Bearer ${authToken}`;
  }
  return config;
});

// Test functions
async function testHealthCheck() {
  console.log('🏥 Testing health check...');
  try {
    const response = await api.get('/health');
    console.log('✅ Health check passed:', response.data);
    return true;
  } catch (error) {
    console.error('❌ Health check failed:', error.response?.data || error.message);
    return false;
  }
}

async function testUserRegistration() {
  console.log('👤 Testing user registration...');
  try {
    const response = await api.post('/api/auth/register', TEST_USER);
    console.log('✅ User registration passed');
    
    if (response.data.success && response.data.data.tokens) {
      authToken = response.data.data.tokens.accessToken;
      userId = response.data.data.user.id;
    }
    
    return true;
  } catch (error) {
    if (error.response?.status === 409) {
      console.log('⚠️ User already exists, proceeding with login...');
      return await testUserLogin();
    }
    console.error('❌ User registration failed:', error.response?.data || error.message);
    return false;
  }
}

async function testUserLogin() {
  console.log('🔐 Testing user login...');
  try {
    const response = await api.post('/api/auth/login', {
      email: TEST_USER.email,
      password: TEST_USER.password
    });
    console.log('✅ User login passed');
    
    if (response.data.success && response.data.data.tokens) {
      authToken = response.data.data.tokens.accessToken;
      userId = response.data.data.user.id;
    }
    
    return true;
  } catch (error) {
    console.error('❌ User login failed:', error.response?.data || error.message);
    return false;
  }
}

async function testUserProfile() {
  console.log('👤 Testing user profile...');
  try {
    const response = await api.get('/api/users/profile');
    console.log('✅ User profile passed:', response.data.data);
    return true;
  } catch (error) {
    console.error('❌ User profile failed:', error.response?.data || error.message);
    return false;
  }
}

async function testDebtsEndpoint() {
  console.log('💳 Testing debts endpoint...');
  try {
    const response = await api.get('/api/debts');
    console.log('✅ Debts endpoint passed:', response.data.data.debts.length, 'debts found');
    return true;
  } catch (error) {
    console.error('❌ Debts endpoint failed:', error.response?.data || error.message);
    return false;
  }
}

async function testOptimizationEndpoint() {
  console.log('🧠 Testing optimization endpoint...');
  try {
    const response = await api.post('/api/optimization/strategy', {
      monthlyPayment: 1000,
      strategy: 'avalanche'
    });
    console.log('✅ Optimization endpoint passed');
    return true;
  } catch (error) {
    console.error('❌ Optimization endpoint failed:', error.response?.data || error.message);
    return false;
  }
}

async function testLogout() {
  console.log('🚪 Testing logout...');
  try {
    const response = await api.post('/api/auth/logout');
    console.log('✅ Logout passed');
    return true;
  } catch (error) {
    console.error('❌ Logout failed:', error.response?.data || error.message);
    return false;
  }
}

// Main test runner
async function runAllTests() {
  console.log('🚀 Starting API Integration Tests...\n');
  
  const tests = [
    { name: 'Health Check', fn: testHealthCheck },
    { name: 'User Registration/Login', fn: testUserRegistration },
    { name: 'User Profile', fn: testUserProfile },
    { name: 'Debts Endpoint', fn: testDebtsEndpoint },
    { name: 'Optimization Endpoint', fn: testOptimizationEndpoint },
    { name: 'Logout', fn: testLogout }
  ];
  
  let passed = 0;
  let failed = 0;
  
  for (const test of tests) {
    console.log(`\n--- ${test.name} ---`);
    const result = await test.fn();
    if (result) {
      passed++;
    } else {
      failed++;
    }
  }
  
  console.log('\n📊 Test Results:');
  console.log(`✅ Passed: ${passed}`);
  console.log(`❌ Failed: ${failed}`);
  console.log(`📈 Success Rate: ${((passed / (passed + failed)) * 100).toFixed(1)}%`);
  
  if (failed === 0) {
    console.log('\n🎉 All tests passed! API integration is working correctly.');
  } else {
    console.log('\n⚠️ Some tests failed. Please check the errors above.');
  }
}

// Error handling
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Run tests if this file is executed directly
if (require.main === module) {
  runAllTests().catch(error => {
    console.error('Test runner failed:', error);
    process.exit(1);
  });
}

module.exports = {
  runAllTests,
  testHealthCheck,
  testUserRegistration,
  testUserLogin,
  testUserProfile,
  testDebtsEndpoint,
  testOptimizationEndpoint,
  testLogout
};
