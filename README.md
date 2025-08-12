# RoundUp Savings App

A micro-saving application that helps users save for specific purchase goals through round-up transactions and automated savings.

## 🎯 Concept

RoundUp takes the proven micro-saving mechanism (like Acorns) but directs savings toward tangible, short-term purchase goals rather than investments. This creates immediate emotional satisfaction and stronger user motivation.

## 🏗️ Architecture

### Backend
- **Framework**: Node.js with Express/NestJS
- **Database**: PostgreSQL + Redis
- **Authentication**: JWT with refresh tokens
- **Banking Integration**: Plaid API
- **Payment Processing**: Stripe/Dwolla
- **File Storage**: AWS S3

### Frontend
- **Framework**: React Native (cross-platform)
- **State Management**: Redux/MobX
- **UI Library**: NativeBase/React Native Elements
- **Navigation**: React Navigation

### Key Features
- Round-up savings from transactions
- Goal-based saving with progress tracking
- Bank account integration
- Social features and group goals
- Automated purchases when goals are reached
- Price tracking for goal items

## 🚀 Quick Start

### Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Redis 6+
- React Native development environment

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd roundup-savings-app
   ```

2. **Install dependencies**
   ```bash
   # Backend
   cd backend && npm install
   
   # Frontend
   cd ../frontend && npm install
   
   # Mobile
   cd ../mobile && npm install
   ```

3. **Environment Setup**
   ```bash
   # Copy environment files
   cp backend/.env.example backend/.env
   cp frontend/.env.example frontend/.env
   cp mobile/.env.example mobile/.env
   ```

4. **Database Setup**
   ```bash
   cd backend
   npm run db:migrate
   npm run db:seed
   ```

5. **Start Development Servers**
   ```bash
   # Backend
   cd backend && npm run dev
   
   # Frontend (in new terminal)
   cd frontend && npm start
   
   # Mobile (in new terminal)
   cd mobile && npm start
   ```

## 📁 Project Structure

```
roundup-savings-app/
├── backend/                 # Node.js API server
│   ├── src/
│   │   ├── controllers/    # Route controllers
│   │   ├── services/       # Business logic
│   │   ├── models/         # Database models
│   │   ├── middleware/     # Custom middleware
│   │   ├── routes/         # API routes
│   │   └── utils/          # Utility functions
│   ├── config/             # Configuration files
│   └── tests/              # Test files
├── frontend/               # Web dashboard (future)
│   ├── src/
│   │   ├── components/     # Reusable components
│   │   ├── screens/        # Page components
│   │   ├── services/       # API services
│   │   └── utils/          # Utility functions
│   └── public/             # Static assets
├── mobile/                 # React Native app
│   ├── src/
│   │   ├── components/     # Mobile components
│   │   ├── screens/        # App screens
│   │   ├── services/       # API services
│   │   └── utils/          # Utility functions
│   ├── android/            # Android specific files
│   └── ios/                # iOS specific files
├── shared/                 # Shared code
│   ├── types/              # TypeScript types
│   ├── constants/          # Shared constants
│   └── utils/              # Shared utilities
└── docs/                   # Documentation
```

## 🔧 Development

### Backend Development
```bash
cd backend
npm run dev          # Start development server
npm run test         # Run tests
npm run db:migrate   # Run database migrations
npm run db:seed      # Seed database with test data
```

### Mobile Development
```bash
cd mobile
npm start            # Start Metro bundler
npm run android      # Run on Android
npm run ios          # Run on iOS
```

## 📋 API Endpoints

### Authentication
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `POST /auth/logout` - User logout
- `POST /auth/refresh` - Refresh token
- `POST /auth/verify-otp` - OTP verification

### Banking
- `POST /banking/connect` - Connect bank account
- `GET /banking/accounts` - Get user accounts
- `GET /banking/transactions` - Get transactions
- `POST /banking/refresh` - Refresh account data

### Goals
- `GET /goals` - Get user goals
- `POST /goals` - Create new goal
- `PUT /goals/:id` - Update goal
- `DELETE /goals/:id` - Delete goal
- `POST /goals/:id/contribute` - Manual contribution

### Social
- `GET /social/friends` - Get friends list
- `POST /social/invite` - Send friend invite
- `GET /social/activity` - Get social activity

## 🔒 Security & Compliance

- **Encryption**: AES-256 for data at rest
- **SSL/TLS**: For all API communications
- **PCI Compliance**: For payment data
- **2FA**: SMS/Email verification
- **GDPR/CCPA**: Data protection compliance
- **SOC 2**: Security certification

## 📱 Features Roadmap

### Phase 1 (MVP)
- [ ] User authentication
- [ ] Bank account connection
- [ ] Basic goal creation
- [ ] Round-up savings
- [ ] Progress tracking

### Phase 2
- [ ] Social features
- [ ] Group goals
- [ ] Price tracking
- [ ] Automated purchases

### Phase 3
- [ ] Advanced analytics
- [ ] Merchant integrations
- [ ] Advanced social features
- [ ] Web dashboard

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support, email support@roundup-savings.com or create an issue in the repository. 