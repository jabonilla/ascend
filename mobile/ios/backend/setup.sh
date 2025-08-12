#!/bin/bash

# Ascend Backend Setup Script
# This script sets up the complete backend environment

set -e

echo "🚀 Setting up Ascend Backend..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Node.js is installed
check_node() {
    print_status "Checking Node.js installation..."
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18 or higher."
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18 or higher is required. Current version: $(node -v)"
        exit 1
    fi
    
    print_success "Node.js $(node -v) is installed"
}

# Check if npm is installed
check_npm() {
    print_status "Checking npm installation..."
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed."
        exit 1
    fi
    
    print_success "npm $(npm -v) is installed"
}

# Check if PostgreSQL is installed
check_postgres() {
    print_status "Checking PostgreSQL installation..."
    if ! command -v psql &> /dev/null; then
        print_warning "PostgreSQL is not installed. Please install PostgreSQL 12 or higher."
        print_status "You can install PostgreSQL using:"
        echo "  macOS: brew install postgresql"
        echo "  Ubuntu: sudo apt-get install postgresql postgresql-contrib"
        echo "  CentOS: sudo yum install postgresql postgresql-server"
        echo ""
        print_status "After installation, run this script again."
        exit 1
    fi
    
    print_success "PostgreSQL is installed"
}

# Install dependencies
install_dependencies() {
    print_status "Installing npm dependencies..."
    npm install
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Create environment file
create_env_file() {
    print_status "Creating .env file..."
    
    if [ -f .env ]; then
        print_warning ".env file already exists. Backing up to .env.backup"
        cp .env .env.backup
    fi
    
    cat > .env << EOF
# Ascend Backend Environment Configuration

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
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# Plaid Configuration
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=sandbox

# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key

# Email Configuration (SendGrid)
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

# Twilio Configuration (optional)
TWILIO_ACCOUNT_SID=your-twilio-account-sid
TWILIO_AUTH_TOKEN=your-twilio-auth-token
TWILIO_PHONE_NUMBER=+1234567890

# Frontend URL
FRONTEND_URL=http://localhost:8081

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:8081,http://localhost:3000

# Logging Configuration
LOG_LEVEL=info
LOG_FILE=logs/app.log

# Security Configuration
BCRYPT_ROUNDS=12
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Feature Flags
ENABLE_PLAID=true
ENABLE_AI=true
ENABLE_NOTIFICATIONS=true
ENABLE_ANALYTICS=true
EOF

    print_success ".env file created"
    print_warning "Please update the .env file with your actual API keys and configuration"
}

# Create database
create_database() {
    print_status "Creating database..."
    
    # Check if database exists
    if psql -h localhost -U postgres -lqt | cut -d \| -f 1 | grep -qw ascend_dev; then
        print_warning "Database 'ascend_dev' already exists"
        read -p "Do you want to drop and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Dropping existing database..."
            dropdb -h localhost -U postgres ascend_dev || true
        else
            print_status "Using existing database"
            return 0
        fi
    fi
    
    # Create database
    createdb -h localhost -U postgres ascend_dev
    
    if [ $? -eq 0 ]; then
        print_success "Database 'ascend_dev' created successfully"
    else
        print_error "Failed to create database"
        exit 1
    fi
}

# Run database migrations
run_migrations() {
    print_status "Running database migrations..."
    
    # Create migrations directory if it doesn't exist
    mkdir -p migrations
    
    # Run migrations
    npm run migrate
    
    if [ $? -eq 0 ]; then
        print_success "Database migrations completed"
    else
        print_error "Failed to run database migrations"
        exit 1
    fi
}

# Seed database
seed_database() {
    print_status "Seeding database with initial data..."
    
    # Create seeds directory if it doesn't exist
    mkdir -p seeds
    
    # Run seeds
    npm run seed
    
    if [ $? -eq 0 ]; then
        print_success "Database seeded successfully"
    else
        print_warning "Failed to seed database (this is optional)"
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p uploads
    mkdir -p temp
    mkdir -p config
    
    print_success "Directories created"
}

# Set up logging
setup_logging() {
    print_status "Setting up logging..."
    
    # Create log file
    touch logs/app.log
    touch logs/error.log
    
    print_success "Logging setup complete"
}

# Create PM2 configuration
create_pm2_config() {
    print_status "Creating PM2 configuration..."
    
    cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'ascend-backend',
    script: 'src/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'development',
      PORT: 3000
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024'
  }]
};
EOF

    print_success "PM2 configuration created"
}

# Create Docker configuration
create_docker_config() {
    print_status "Creating Docker configuration..."
    
    cat > Dockerfile << EOF
FROM node:18-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm ci --only=production

# Bundle app source
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /usr/src/app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "start"]
EOF

    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DB_HOST=postgres
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - ./logs:/usr/src/app/logs
      - ./uploads:/usr/src/app/uploads
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ascend_prod
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

    print_success "Docker configuration created"
}

# Create GitHub Actions workflow
create_github_actions() {
    print_status "Creating GitHub Actions workflow..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/ci.yml << EOF
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: ascend_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - uses: actions/checkout@v3
    
    - name: Use Node.js 18
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Run linter
      run: npm run lint
    
    - name: Run tests
      run: npm test
      env:
        NODE_ENV: test
        DB_HOST: localhost
        DB_PORT: 5432
        DB_USER: postgres
        DB_PASSWORD: postgres
        DB_NAME: ascend_test
        JWT_SECRET: test-secret

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to production
      run: echo "Deploy to production server"
      # Add your deployment steps here
EOF

    print_success "GitHub Actions workflow created"
}

# Main setup function
main() {
    echo "🎯 Ascend Backend Setup"
    echo "========================"
    echo ""
    
    # Check prerequisites
    check_node
    check_npm
    check_postgres
    
    # Install dependencies
    install_dependencies
    
    # Create environment
    create_env_file
    create_directories
    setup_logging
    
    # Database setup
    create_database
    run_migrations
    seed_database
    
    # Additional configurations
    create_pm2_config
    create_docker_config
    create_github_actions
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Update the .env file with your actual API keys"
    echo "2. Start the server: npm run dev"
    echo "3. Access the API documentation: http://localhost:3000/api-docs"
    echo "4. Test the health endpoint: http://localhost:3000/health"
    echo ""
    echo "For production deployment:"
    echo "- Use PM2: pm2 start ecosystem.config.js"
    echo "- Use Docker: docker-compose up -d"
    echo ""
}

# Run main function
main "$@"
