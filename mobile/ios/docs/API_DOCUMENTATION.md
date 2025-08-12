# 📚 Ascend API Documentation

## 🔗 **Base URL**
```
Development: http://localhost:3000
Production: https://api.ascend-financial.com
```

## 🔐 **Authentication**

All protected endpoints require a valid JWT token in the Authorization header:

```
Authorization: Bearer <your-access-token>
```

### **Token Types**
- **Access Token**: Short-lived (15 minutes) for API requests
- **Refresh Token**: Long-lived (7 days) for getting new access tokens

## 📊 **API Endpoints**

### **🔐 Authentication**

#### **Register User**
```http
POST /api/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123",
  "firstName": "John",
  "lastName": "Doe",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user-uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "phone": "+1234567890",
      "isPremium": false,
      "createdAt": "2024-01-01T00:00:00.000Z"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

#### **Login User**
```http
POST /api/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "user-uuid",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe",
      "isPremium": false,
      "lastLoginAt": "2024-01-01T00:00:00.000Z"
    },
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

#### **Refresh Token**
```http
POST /api/auth/refresh
```

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "tokens": {
      "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
  }
}
```

#### **Logout**
```http
POST /api/auth/logout
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "message": "Logout successful"
}
```

### **👤 User Management**

#### **Get User Profile**
```http
GET /api/users/profile
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user-uuid",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890",
    "isPremium": false,
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

#### **Update User Profile**
```http
PUT /api/users/profile
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Request Body:**
```json
{
  "firstName": "John",
  "lastName": "Smith",
  "phone": "+1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "user-uuid",
    "firstName": "John",
    "lastName": "Smith",
    "phone": "+1234567890",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

### **💳 Debt Management**

#### **Get All Debts**
```http
GET /api/debts
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)
- `status` (optional): Filter by status (active, paid, defaulted)

**Response:**
```json
{
  "success": true,
  "data": {
    "debts": [
      {
        "id": "debt-uuid",
        "name": "Credit Card",
        "balance": 5000.00,
        "interestRate": 18.99,
        "minimumPayment": 150.00,
        "dueDate": "2024-01-15",
        "status": "active",
        "category": "credit_card",
        "createdAt": "2024-01-01T00:00:00.000Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

#### **Create New Debt**
```http
POST /api/debts
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Request Body:**
```json
{
  "name": "Student Loan",
  "balance": 25000.00,
  "interestRate": 5.50,
  "minimumPayment": 300.00,
  "dueDate": "2024-01-20",
  "category": "student_loan"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "debt-uuid",
    "name": "Student Loan",
    "balance": 25000.00,
    "interestRate": 5.50,
    "minimumPayment": 300.00,
    "dueDate": "2024-01-20",
    "status": "active",
    "category": "student_loan",
    "createdAt": "2024-01-01T00:00:00.000Z"
  }
}
```

#### **Update Debt**
```http
PUT /api/debts/:id
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Request Body:**
```json
{
  "balance": 24000.00,
  "minimumPayment": 350.00
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "debt-uuid",
    "name": "Student Loan",
    "balance": 24000.00,
    "interestRate": 5.50,
    "minimumPayment": 350.00,
    "dueDate": "2024-01-20",
    "status": "active",
    "category": "student_loan",
    "updatedAt": "2024-01-01T00:00:00.000Z"
  }
}
```

#### **Delete Debt**
```http
DELETE /api/debts/:id
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "message": "Debt deleted successfully"
}
```

### **🧠 AI Optimization**

#### **Generate Payoff Strategy**
```http
POST /api/optimization/strategy
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Request Body:**
```json
{
  "strategy": "avalanche",
  "extraPayment": 500.00,
  "preferences": {
    "riskTolerance": "moderate",
    "timeHorizon": "5_years"
  }
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "strategy": "avalanche",
    "recommendations": [
      {
        "debtId": "debt-uuid",
        "name": "Credit Card",
        "priority": 1,
        "recommendedPayment": 650.00,
        "payoffDate": "2024-06-15"
      }
    ],
    "projections": {
      "payoffTime": 18,
      "totalInterestPaid": 2500.00,
      "interestSaved": 1500.00,
      "totalCost": 27500.00
    }
  }
}
```

#### **Get Financial Insights**
```http
GET /api/optimization/insights
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "insights": [
      {
        "type": "savings_opportunity",
        "title": "High Interest Debt",
        "description": "Your credit card has the highest interest rate. Consider paying it off first.",
        "priority": "high",
        "estimatedSavings": 1500.00
      }
    ],
    "summary": {
      "totalDebt": 30000.00,
      "averageInterestRate": 12.25,
      "monthlyPayments": 800.00,
      "debtToIncomeRatio": 0.35
    }
  }
}
```

### **🏦 Bank Integration (Plaid)**

#### **Create Link Token**
```http
POST /api/plaid/link-token
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "linkToken": "link-sandbox-1234567890",
    "expiration": "2024-01-01T01:00:00.000Z"
  }
}
```

#### **Exchange Public Token**
```http
POST /api/plaid/exchange-token
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Request Body:**
```json
{
  "publicToken": "public-sandbox-1234567890"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accessToken": "access-sandbox-1234567890",
    "itemId": "item-1234567890"
  }
}
```

#### **Get Bank Accounts**
```http
GET /api/plaid/accounts
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accounts": [
      {
        "id": "account-123",
        "name": "Checking Account",
        "type": "depository",
        "subtype": "checking",
        "mask": "1234",
        "balance": {
          "available": 2500.00,
          "current": 2500.00
        }
      }
    ]
  }
}
```

#### **Get Transactions**
```http
GET /api/plaid/transactions
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Query Parameters:**
- `start_date`: Start date (YYYY-MM-DD)
- `end_date`: End date (YYYY-MM-DD)
- `account_id` (optional): Filter by account

**Response:**
```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "id": "transaction-123",
        "accountId": "account-123",
        "amount": -150.00,
        "date": "2024-01-01",
        "name": "Credit Card Payment",
        "category": ["Transfer", "Payment"],
        "pending": false
      }
    ]
  }
}
```

### **📊 Analytics**

#### **Get Debt Statistics**
```http
GET /api/analytics/debt-stats
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Response:**
```json
{
  "success": true,
  "data": {
    "totalDebt": 30000.00,
    "totalMonthlyPayments": 800.00,
    "averageInterestRate": 12.25,
    "debtByCategory": {
      "credit_card": 15000.00,
      "student_loan": 10000.00,
      "personal_loan": 5000.00
    },
    "progress": {
      "totalPaid": 5000.00,
      "percentagePaid": 14.29,
      "monthsToPayoff": 42
    }
  }
}
```

#### **Get Payment History**
```http
GET /api/analytics/payment-history
```

**Headers:**
```
Authorization: Bearer <access-token>
```

**Query Parameters:**
- `start_date`: Start date (YYYY-MM-DD)
- `end_date`: End date (YYYY-MM-DD)

**Response:**
```json
{
  "success": true,
  "data": {
    "payments": [
      {
        "id": "payment-123",
        "debtId": "debt-uuid",
        "amount": 500.00,
        "date": "2024-01-01",
        "type": "regular",
        "status": "completed"
      }
    ],
    "summary": {
      "totalPayments": 5000.00,
      "averagePayment": 500.00,
      "paymentCount": 10
    }
  }
}
```

## 🚨 **Error Responses**

### **Standard Error Format**
```json
{
  "success": false,
  "error": {
    "message": "Error description",
    "code": "ERROR_CODE",
    "details": {}
  }
}
```

### **Common Error Codes**

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `VALIDATION_ERROR` | Request validation failed | 400 |
| `AUTHENTICATION_REQUIRED` | Authentication token missing | 401 |
| `INVALID_TOKEN` | Invalid or expired token | 401 |
| `INSUFFICIENT_PERMISSIONS` | User lacks required permissions | 403 |
| `RESOURCE_NOT_FOUND` | Requested resource not found | 404 |
| `RATE_LIMIT_EXCEEDED` | Too many requests | 429 |
| `INTERNAL_SERVER_ERROR` | Server error | 500 |

### **Example Error Response**
```json
{
  "success": false,
  "error": {
    "message": "Email is already registered",
    "code": "USER_EXISTS",
    "details": {
      "field": "email",
      "value": "user@example.com"
    }
  }
}
```

## 📈 **Rate Limiting**

- **Authentication endpoints**: 5 requests per minute
- **API endpoints**: 100 requests per minute per user
- **Plaid endpoints**: 10 requests per minute per user

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## 🔒 **Security**

- All endpoints use HTTPS in production
- JWT tokens are signed with a secure secret
- Passwords are hashed using bcrypt
- Rate limiting prevents abuse
- CORS is configured for security
- Input validation on all endpoints

## 📞 **Support**

For API support:
- **Email**: api@ascend-financial.com
- **Documentation**: https://docs.ascend-financial.com
- **Status Page**: https://status.ascend-financial.com
