#!/bin/bash

echo "🚀 Setting up RoundUp Savings App development environment..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

echo "✅ Node.js version: $(node -v)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

echo "✅ Docker is installed"

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker Compose is installed"

# Create .env files if they don't exist
if [ ! -f "backend/.env" ]; then
    echo "📝 Creating backend .env file..."
    cp backend/.env.example backend/.env
    echo "✅ Backend .env file created"
else
    echo "✅ Backend .env file already exists"
fi

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend
npm install
cd ..

# Start Docker services
echo "🐳 Starting Docker services..."
docker-compose up -d postgres redis

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Run database migrations
echo "🗄️ Running database migrations..."
cd backend
npm run db:migrate
cd ..

echo "✅ Development environment setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Update backend/.env with your API keys"
echo "2. Start the backend: cd backend && npm run dev"
echo "3. Test the API: curl http://localhost:3000/health"
echo ""
echo "🔗 Services:"
echo "- Backend API: http://localhost:3000"
echo "- PostgreSQL: localhost:5432"
echo "- Redis: localhost:6379"
echo ""
echo "📚 Documentation:"
echo "- API docs: http://localhost:3000/api-docs (when implemented)"
echo "- Database: Use any PostgreSQL client to connect to localhost:5432" 