# iOS Backend Integration Guide

This guide provides step-by-step instructions for integrating the Ascend iOS app with the backend API.

## 🎯 Overview

The iOS app is now configured to connect to a real backend API instead of using simulated data. This integration enables:

- **Real User Authentication**: JWT-based login/registration
- **Live Bank Connections**: Plaid integration for real accounts
- **AI-Powered Optimization**: OpenAI-driven debt strategies
- **Real-time Data Sync**: Live debt and payment data
- **Push Notifications**: Real-time alerts and reminders
- **Community Features**: Live challenges and leaderboards

## 🚀 Quick Start

### 1. Backend Setup

First, ensure the backend is running:

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Update environment variables (see Backend README)
nano .env

# Start the server
npm run dev
```

The backend should be running at `http://localhost:3000`

### 2. iOS App Configuration

The iOS app is already configured to connect to the backend. Key configuration points:

- **API Base URL**: `http://localhost:3000` (development)
- **Authentication**: JWT tokens with automatic refresh
- **Plaid Integration**: Real bank account connections
- **Error Handling**: Comprehensive error management

### 3. Test the Integration

```bash
# Test backend health
curl http://localhost:3000/health

# Test API documentation
open http://localhost:3000/api-docs
```

## 🔧 Configuration Details

### API Endpoints

The iOS app uses these key endpoints:

#### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Token refresh
- `POST /api/auth/logout` - User logout

#### Debt Management
- `GET /api/debts` - Fetch user debts
- `POST /api/debts` - Create new debt
- `PUT /api/debts/{id}` - Update debt
- `DELETE /api/debts/{id}` - Delete debt

#### Payment Management
- `GET /api/payments` - Fetch payments
- `POST /api/payments/schedule` - Schedule payment
- `PUT /api/payments/{id}/cancel` - Cancel payment

#### Plaid Integration
- `POST /api/plaid/link-token` - Create Plaid link
- `POST /api/plaid/exchange-token` - Exchange tokens
- `GET /api/plaid/accounts` - Get accounts
- `GET /api/plaid/transactions` - Get transactions

#### AI Optimization
- `POST /api/optimization/strategy` - Generate strategy
- `GET /api/optimization/insights` - Get insights

### Environment Variables

The iOS app automatically detects the environment:

```swift
#if DEBUG
static let baseURL = "http://localhost:3000"
#else
static let baseURL = "https://api.ascend-financial.com"
#endif
```

## 🔐 Authentication Flow

### 1. Registration

```swift
// User registers with email/password
let request = RegisterRequest(
    email: "user@example.com",
    password: "securepassword",
    firstName: "John",
    lastName: "Doe"
)

// NetworkManager handles the API call
let response: APIResponse<User> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.register,
    method: .POST,
    body: request
)

// Store tokens securely
if let tokens = response.data?.tokens {
    KeychainService.shared.saveAccessToken(tokens.accessToken)
    KeychainService.shared.saveRefreshToken(tokens.refreshToken)
}
```

### 2. Login

```swift
// User logs in
let request = LoginRequest(
    email: "user@example.com",
    password: "securepassword"
)

let response: APIResponse<User> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.login,
    method: .POST,
    body: request
)
```

### 3. Automatic Token Refresh

The `NetworkManager` automatically handles token refresh:

```swift
// When a 401 response is received
if response.statusCode == 401 {
    // Attempt to refresh token
    let refreshResponse: APIResponse<AuthTokens> = try await refreshToken()
    
    // Retry original request with new token
    return try await executeRequest(originalRequest)
}
```

## 🏦 Plaid Integration

### 1. Create Link Token

```swift
// Request Plaid link token
let response: APIResponse<PlaidLinkToken> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.plaidLinkToken,
    method: .POST
)

// Use token to initialize Plaid Link
if let linkToken = response.data?.token {
    // Initialize Plaid Link with token
    PlaidLink.create(configuration: PlaidLinkConfiguration(token: linkToken))
}
```

### 2. Exchange Public Token

```swift
// After user connects bank account
let request = ["publicToken": publicToken]

let response: APIResponse<Never> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.plaidExchangeToken,
    method: .POST,
    body: request
)
```

### 3. Fetch Accounts and Transactions

```swift
// Get connected accounts
let accountsResponse: APIResponse<[PlaidAccount]> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.plaidAccounts
)

// Get transactions for specific account
let transactionsResponse: APIResponse<[PlaidTransaction]> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.plaidTransactions,
    parameters: ["accountId": accountId]
)
```

## 📊 Data Synchronization

### 1. Debt Management

```swift
// Fetch user debts
let debtsResponse: APIResponse<[Debt]> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.debts
)

// Create new debt
let newDebt = Debt(
    name: "Credit Card",
    type: .creditCard,
    currentBalance: 5000.0,
    apr: 18.99
)

let createResponse: APIResponse<Debt> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.debts,
    method: .POST,
    body: newDebt
)
```

### 2. Payment Scheduling

```swift
// Schedule payment
let paymentRequest = SchedulePaymentRequest(
    debtId: debtId,
    amount: 500.0,
    scheduledDate: Date(),
    frequency: .monthly
)

let scheduleResponse: APIResponse<Payment> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.schedulePayment,
    method: .POST,
    body: paymentRequest
)
```

### 3. AI Optimization

```swift
// Generate optimization strategy
let optimizationRequest = OptimizationRequest(
    debts: userDebts,
    monthlyPayment: 1000.0,
    strategy: .avalanche
)

let strategyResponse: APIResponse<OptimizationStrategy> = try await NetworkManager.shared.request(
    endpoint: APIConstants.Endpoints.generateStrategy,
    method: .POST,
    body: optimizationRequest
)
```

## 🔄 Offline Support

The iOS app includes comprehensive offline support:

### 1. Core Data Storage

```swift
// Save data locally
CoreDataManager.shared.saveDebts(debts)
CoreDataManager.shared.savePayments(payments)

// Retrieve data when offline
let localDebts = CoreDataManager.shared.getDebts()
let localPayments = CoreDataManager.shared.getPayments()
```

### 2. Request Queuing

```swift
// NetworkManager automatically queues requests when offline
NetworkManager.shared.request(endpoint: "/api/debts", method: .POST, body: newDebt)

// Requests are automatically retried when connection is restored
```

### 3. Data Synchronization

```swift
// Sync local changes when online
CoreDataManager.shared.syncData()
```

## 🧪 Testing the Integration

### 1. Backend Health Check

```bash
# Test backend is running
curl http://localhost:3000/health

# Expected response:
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "uptime": 3600,
  "environment": "development"
}
```

### 2. API Documentation

Visit `http://localhost:3000/api-docs` to see the interactive API documentation.

### 3. Test User Registration

```bash
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User"
  }'
```

### 4. Test iOS App Connection

1. Build and run the iOS app
2. Navigate to the registration screen
3. Create a test account
4. Verify the app connects to the backend

## 🐛 Troubleshooting

### Common Issues

#### 1. Backend Connection Failed

**Symptoms**: iOS app shows "Network Error" or "Unable to connect"

**Solutions**:
- Verify backend is running: `curl http://localhost:3000/health`
- Check iOS simulator can reach localhost
- Verify API base URL in `APIConstants.swift`

#### 2. Authentication Errors

**Symptoms**: Login/registration fails with 401/403 errors

**Solutions**:
- Check JWT_SECRET in backend .env file
- Verify token expiration settings
- Check CORS configuration

#### 3. Plaid Integration Issues

**Symptoms**: Bank connection fails

**Solutions**:
- Verify Plaid credentials in backend .env
- Check Plaid environment (sandbox/development)
- Ensure Plaid webhook is configured

#### 4. Database Connection Issues

**Symptoms**: Backend fails to start or API calls fail

**Solutions**:
- Verify PostgreSQL is running
- Check database credentials in .env
- Run database migrations: `npm run migrate`

### Debug Mode

Enable debug logging in the iOS app:

```swift
// In NetworkManager.swift
#if DEBUG
print("🌐 API Request: \(endpoint)")
print("📦 Request Body: \(body)")
print("📡 Response: \(response)")
#endif
```

### Backend Logging

Check backend logs for errors:

```bash
# View real-time logs
tail -f logs/app.log

# View error logs
tail -f logs/error.log
```

## 🚀 Production Deployment

### 1. Backend Deployment

```bash
# Set production environment
export NODE_ENV=production

# Update environment variables
nano .env

# Start with PM2
pm2 start ecosystem.config.js
```

### 2. iOS App Configuration

Update the API base URL for production:

```swift
// In APIConstants.swift
#if DEBUG
static let baseURL = "http://localhost:3000"
#else
static let baseURL = "https://api.ascend-financial.com"
#endif
```

### 3. SSL Certificate

Ensure your production backend has a valid SSL certificate for HTTPS.

### 4. Environment Variables

Update production environment variables:

```env
NODE_ENV=production
PLAID_ENV=production
JWT_SECRET=your-production-secret
DB_HOST=your-production-db
```

## 📱 iOS App Features

### 1. Real-time Updates

The iOS app now receives real-time updates:

- **Live Debt Balances**: Updated from bank connections
- **Payment Confirmations**: Real payment processing
- **AI Insights**: Live optimization recommendations
- **Community Updates**: Real-time challenge progress

### 2. Enhanced Security

- **Biometric Authentication**: Touch ID/Face ID integration
- **Secure Token Storage**: Keychain Services
- **Certificate Pinning**: SSL certificate validation
- **Data Encryption**: Local data encryption

### 3. Performance Optimizations

- **Request Caching**: Intelligent API response caching
- **Background Sync**: Automatic data synchronization
- **Image Optimization**: Efficient image loading and caching
- **Memory Management**: Optimized memory usage

## 🔄 Continuous Integration

### 1. Automated Testing

```bash
# Run backend tests
cd backend && npm test

# Run iOS tests
cd ios && xcodebuild test -scheme RoundUpSavings -destination 'platform=iOS Simulator,name=iPhone 14'
```

### 2. API Contract Testing

The iOS app includes API contract tests to ensure compatibility:

```swift
// Test API responses match expected format
func testUserRegistrationResponse() async throws {
    let response = try await AuthenticationService.shared.register(
        email: "test@example.com",
        password: "password123",
        firstName: "Test",
        lastName: "User"
    )
    
    XCTAssertNotNil(response.user)
    XCTAssertNotNil(response.tokens)
    XCTAssertNotNil(response.tokens.accessToken)
}
```

## 📊 Monitoring and Analytics

### 1. API Performance

Monitor API performance in the iOS app:

```swift
// Track API response times
AnalyticsService.shared.trackEvent("api_request", properties: [
    "endpoint": endpoint,
    "response_time": responseTime,
    "status_code": statusCode
])
```

### 2. Error Tracking

Track and report errors:

```swift
// Report API errors
AnalyticsService.shared.trackEvent("api_error", properties: [
    "endpoint": endpoint,
    "error_code": error.code,
    "error_message": error.message
])
```

## 🎉 Success Metrics

### 1. Integration Success

- ✅ Backend server running and accessible
- ✅ iOS app can register/login users
- ✅ Plaid bank connections working
- ✅ Real-time data synchronization
- ✅ Push notifications delivered
- ✅ AI optimization generating strategies

### 2. Performance Metrics

- **API Response Time**: < 200ms average
- **App Launch Time**: < 2 seconds
- **Data Sync Time**: < 5 seconds
- **Offline Functionality**: 100% core features
- **Error Rate**: < 1% API calls

## 📞 Support

For integration issues:

1. **Check Logs**: Review iOS and backend logs
2. **API Documentation**: Visit `/api-docs` endpoint
3. **Health Check**: Verify `/health` endpoint
4. **Create Issue**: Report bugs in the repository
5. **Contact Team**: Reach out to development team

## 🔄 Next Steps

After successful integration:

1. **User Testing**: Test with real users
2. **Performance Optimization**: Monitor and optimize
3. **Feature Expansion**: Add new API endpoints
4. **Security Audit**: Review security measures
5. **Production Deployment**: Deploy to production

---

**🎯 Integration Complete!** 

The Ascend iOS app is now fully integrated with a real backend API, providing users with a complete, production-ready debt management experience.
