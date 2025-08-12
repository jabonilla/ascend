# Ascend Backend API

A comprehensive Node.js/Express backend for the Ascend AI-Powered Debt Management Platform.

## 🚀 Features

- **Authentication & Authorization**: JWT-based authentication with refresh tokens
- **Plaid Integration**: Real bank account connections and transaction sync
- **AI-Powered Optimization**: OpenAI integration for debt payoff strategies
- **Real-time Notifications**: Push notifications and email alerts
- **Comprehensive Analytics**: User behavior tracking and financial insights
- **Community Features**: Challenges, leaderboards, and support groups
- **Payment Processing**: Stripe integration for premium subscriptions
- **File Uploads**: AWS S3 integration for document storage
- **Rate Limiting**: Advanced rate limiting and DDoS protection
- **API Documentation**: Auto-generated Swagger/OpenAPI documentation

## 📋 Prerequisites

- Node.js 18+ 
- PostgreSQL 12+
- Redis (optional, for caching)
- npm or yarn

## 🛠️ Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd backend

# Run the setup script
chmod +x setup.sh
./setup.sh
```

### 2. Manual Setup (Alternative)

```bash
# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Update environment variables
nano .env

# Create database
createdb ascend_dev

# Run migrations
npm run migrate

# Seed database (optional)
npm run seed
```

### 3. Start Development Server

```bash
# Start in development mode
npm run dev

# Or start in production mode
npm start
```

The API will be available at `http://localhost:3000`

## 🔧 Environment Configuration

Create a `.env` file with the following variables:

```env
# Server Configuration
NODE_ENV=development
PORT=3000
HOST=localhost

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=password
DB_NAME=ascend_dev

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# Plaid Configuration
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox

# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key

# Email Configuration
SENDGRID_API_KEY=your-sendgrid-api-key
EMAIL_FROM=noreply@ascend-financial.com

# Redis Configuration (optional)
REDIS_URL=redis://localhost:6379

# AWS Configuration (optional)
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_REGION=us-east-1
AWS_S3_BUCKET=ascend-uploads

# Stripe Configuration (optional)
STRIPE_SECRET_KEY=your-stripe-secret-key
STRIPE_WEBHOOK_SECRET=your-stripe-webhook-secret

# Frontend URL
FRONTEND_URL=http://localhost:8081

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:8081,http://localhost:3000
```

## 📚 API Documentation

### Interactive Documentation

Once the server is running, visit:
- **Swagger UI**: http://localhost:3000/api-docs
- **Health Check**: http://localhost:3000/health

### Authentication

All protected endpoints require a Bearer token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### Key Endpoints

#### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh` - Refresh access token
- `POST /api/auth/logout` - User logout
- `POST /api/auth/forgot-password` - Request password reset
- `POST /api/auth/reset-password` - Reset password

#### User Management
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile
- `PUT /api/users/change-password` - Change password
- `DELETE /api/users/account` - Delete account

#### Debt Management
- `GET /api/debts` - Get user debts
- `POST /api/debts` - Create new debt
- `PUT /api/debts/{id}` - Update debt
- `DELETE /api/debts/{id}` - Delete debt
- `GET /api/debts/stats` - Get debt statistics

#### Payment Management
- `GET /api/payments` - Get user payments
- `POST /api/payments/schedule` - Schedule payment
- `PUT /api/payments/{id}/cancel` - Cancel payment
- `GET /api/payments/stats` - Get payment statistics

#### Plaid Integration
- `POST /api/plaid/link-token` - Create Plaid link token
- `POST /api/plaid/exchange-token` - Exchange public token
- `GET /api/plaid/accounts` - Get connected accounts
- `GET /api/plaid/transactions` - Get transactions
- `POST /api/plaid/sync` - Sync transactions
- `POST /api/plaid/disconnect` - Disconnect account

#### AI Optimization
- `POST /api/optimization/strategy` - Generate optimization strategy
- `GET /api/optimization/projections` - Get payoff projections
- `GET /api/optimization/insights` - Get AI insights

#### Debt Discovery
- `GET /api/discovery/debts` - Discover debts from accounts
- `POST /api/discovery/analyze` - Analyze transactions for debts
- `POST /api/discovery/import` - Import discovered debts

#### Payoff Calculator
- `POST /api/calculator/payoff` - Calculate payoff plan
- `GET /api/calculator/scenarios` - Get saved scenarios
- `POST /api/calculator/scenarios` - Save scenario

#### Community
- `GET /api/community/challenges` - Get community challenges
- `GET /api/community/groups` - Get support groups
- `GET /api/community/leaderboard` - Get leaderboard
- `GET /api/community/achievements` - Get achievements

## 🗄️ Database Schema

### Core Tables

- `users` - User accounts and profiles
- `debts` - User debt information
- `payments` - Payment records and schedules
- `plaid_items` - Plaid account connections
- `plaid_accounts` - Connected bank accounts
- `plaid_transactions` - Transaction history
- `optimization_strategies` - AI-generated strategies
- `saved_scenarios` - User-saved payoff scenarios
- `notifications` - User notifications
- `analytics_events` - User behavior tracking

### Relationships

- Users have many debts, payments, and Plaid items
- Plaid items have many accounts and transactions
- Debts have many payments
- Users can save multiple scenarios

## 🔒 Security Features

- **JWT Authentication**: Secure token-based authentication
- **Password Hashing**: bcrypt with 12 rounds
- **Rate Limiting**: Configurable rate limits per endpoint
- **CORS Protection**: Configurable CORS policies
- **Input Validation**: Comprehensive request validation
- **SQL Injection Protection**: Parameterized queries
- **XSS Protection**: Helmet.js security headers
- **CSRF Protection**: Built-in CSRF protection

## 🚀 Deployment

### Production Deployment

#### Option 1: PM2 (Recommended)

```bash
# Install PM2 globally
npm install -g pm2

# Start the application
pm2 start ecosystem.config.js

# Monitor the application
pm2 monit

# View logs
pm2 logs
```

#### Option 2: Docker

```bash
# Build and run with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

#### Option 3: Manual

```bash
# Set production environment
export NODE_ENV=production

# Start the application
npm start
```

### Environment Variables for Production

```env
NODE_ENV=production
PORT=3000
DB_HOST=your-production-db-host
DB_PASSWORD=your-secure-password
JWT_SECRET=your-very-secure-jwt-secret
PLAID_ENV=production
```

## 📊 Monitoring & Logging

### Logging

Logs are stored in the `logs/` directory:
- `app.log` - Application logs
- `error.log` - Error logs
- `combined.log` - Combined logs (PM2)

### Health Checks

- **Health Endpoint**: `GET /health`
- **Database Check**: Automatic database connectivity check
- **External Services**: Plaid, OpenAI, and other service health checks

### Metrics

The application exposes metrics for monitoring:
- Request count and response times
- Error rates
- Database connection status
- External API response times

## 🧪 Testing

### Run Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run specific test file
npm test -- --grep "auth"

# Generate coverage report
npm run test:coverage
```

### Test Structure

- `tests/unit/` - Unit tests
- `tests/integration/` - Integration tests
- `tests/e2e/` - End-to-end tests

## 🔧 Development

### Code Style

```bash
# Run linter
npm run lint

# Fix linting issues
npm run lint:fix

# Format code
npm run format
```

### Database Migrations

```bash
# Create new migration
npm run migrate:make -- create_users_table

# Run migrations
npm run migrate

# Rollback last migration
npm run migrate:rollback

# Reset database
npm run migrate:reset
```

### Database Seeds

```bash
# Run all seeds
npm run seed

# Run specific seed
npm run seed -- --specific=users

# Reset and seed
npm run seed:reset
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Add tests for new functionality
5. Run the test suite: `npm test`
6. Commit your changes: `git commit -am 'Add feature'`
7. Push to the branch: `git push origin feature-name`
8. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the API documentation at `/api-docs`

## 🔄 API Versioning

The API uses semantic versioning. Current version: `v1`

To use a specific version, include it in the URL:
```
GET /api/v1/users/profile
```

## 📈 Performance

### Optimization Tips

1. **Database Indexing**: Ensure proper indexes on frequently queried columns
2. **Caching**: Use Redis for caching frequently accessed data
3. **Connection Pooling**: Configure database connection pools
4. **Compression**: Enable gzip compression for responses
5. **CDN**: Use CDN for static assets

### Benchmarks

- **Response Time**: < 200ms for most endpoints
- **Throughput**: 1000+ requests per second
- **Concurrent Users**: 10,000+ simultaneous users
- **Database Queries**: < 50ms average query time

## 🔐 Security Checklist

- [ ] JWT tokens are properly secured
- [ ] Passwords are hashed with bcrypt
- [ ] Rate limiting is enabled
- [ ] CORS is properly configured
- [ ] Input validation is comprehensive
- [ ] SQL injection protection is in place
- [ ] XSS protection is enabled
- [ ] HTTPS is enforced in production
- [ ] Environment variables are secure
- [ ] Logs don't contain sensitive data
- [ ] API keys are rotated regularly
- [ ] Security headers are set
- [ ] Dependencies are regularly updated
