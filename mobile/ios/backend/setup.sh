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

# Test the server
test_server() {
    print_status "Testing the server..."

    # Start server in background
    npm run dev &
    SERVER_PID=$!

    # Wait for server to start
    sleep 5

    # Test health endpoint
    if curl -f http://localhost:3000/health > /dev/null 2>&1; then
        print_success "Server is running and responding"
    else
        print_error "Server failed to start or respond"
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi

    # Stop server
    kill $SERVER_PID 2>/dev/null || true

    print_success "Server test completed"
}

# Main setup function
main() {
    echo "🎯 Ascend Backend Setup"
    echo "========================"
    echo ""

    # Check prerequisites
    check_node
    check_npm

    # Install dependencies
    install_dependencies

    # Create environment
    create_env_file
    create_directories
    setup_logging

    # Test server
    test_server

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
