# 🚀 Ascend App Deployment Guide

This guide will help you deploy the Ascend AI-Powered Debt Management Platform to production.

## 📋 **Prerequisites**

### **Backend Requirements**
- Node.js 18.0+ 
- PostgreSQL 12+
- Redis (optional, for caching)
- PM2 (for process management)
- Nginx (for reverse proxy)

### **iOS App Requirements**
- Xcode 15.0+
- Apple Developer Account
- iOS 15.0+ deployment target

### **External Services**
- **Plaid API**: For bank account integration
- **OpenAI API**: For AI-powered insights
- **SendGrid**: For email notifications
- **AWS S3**: For file storage (optional)
- **Stripe**: For payment processing (optional)

## 🔧 **Backend Deployment**

### **1. Server Setup**

#### **Ubuntu/Debian**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Install Redis (optional)
sudo apt install redis-server -y

# Install PM2
sudo npm install -g pm2

# Install Nginx
sudo apt install nginx -y
```

#### **macOS**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js
brew install node@18

# Install PostgreSQL
brew install postgresql
brew services start postgresql

# Install Redis
brew install redis
brew services start redis

# Install PM2
npm install -g pm2
```

### **2. Database Setup**

```bash
# Create database user
sudo -u postgres createuser --interactive ascend_user

# Create database
sudo -u postgres createdb ascend_prod

# Set password
sudo -u postgres psql -c "ALTER USER ascend_user PASSWORD 'your_secure_password';"
```

### **3. Application Deployment**

```bash
# Clone repository
git clone https://github.com/yourusername/ascend-app.git
cd ascend-app/backend

# Install dependencies
npm install --production

# Create environment file
cp .env.example .env

# Edit environment variables
nano .env
```

#### **Environment Variables**
```env
# Server Configuration
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=ascend_user
DB_PASSWORD=your_secure_password
DB_NAME=ascend_prod

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d

# Plaid Configuration
PLAID_CLIENT_ID=your-plaid-client-id
PLAID_SECRET=your-plaid-secret
PLAID_ENV=production

# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key

# Email Configuration
SENDGRID_API_KEY=your-sendgrid-api-key
EMAIL_FROM=noreply@ascend-financial.com

# Redis Configuration
REDIS_URL=redis://localhost:6379

# Frontend URL
FRONTEND_URL=https://yourdomain.com

# CORS Configuration
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

### **4. Database Migration**

```bash
# Run migrations
npm run migrate

# Seed database (optional)
npm run seed
```

### **5. PM2 Configuration**

Create `ecosystem.config.js`:
```javascript
module.exports = {
  apps: [{
    name: 'ascend-backend',
    script: 'src/server.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
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
```

### **6. Start Application**

```bash
# Start with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
```

### **7. Nginx Configuration**

Create `/etc/nginx/sites-available/ascend-api`:
```nginx
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/ascend-api /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### **8. SSL Certificate (Let's Encrypt)**

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d api.yourdomain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 📱 **iOS App Deployment**

### **1. App Store Preparation**

#### **Update Configuration**
1. Open `RoundUpSavings.xcodeproj` in Xcode
2. Update Bundle Identifier to your domain
3. Update Team selection
4. Update API endpoints in `APIConstants.swift`

#### **Production API Endpoints**
```swift
#if DEBUG
    static let baseURL = "http://localhost:3000"
#else
    static let baseURL = "https://api.yourdomain.com"
#endif
```

#### **App Icons and Assets**
1. Generate app icons using [App Icon Generator](https://appicon.co/)
2. Replace icons in `Images.xcassets/AppIcon.appiconset/`
3. Update launch screen if needed

### **2. Build and Archive**

```bash
# Clean build
xcodebuild clean -workspace RoundUpSavings.xcworkspace -scheme RoundUpSavings

# Archive for App Store
xcodebuild archive -workspace RoundUpSavings.xcworkspace -scheme RoundUpSavings -archivePath build/RoundUpSavings.xcarchive
```

### **3. App Store Connect**

1. **Create App Record**
   - Go to App Store Connect
   - Click "My Apps" → "+" → "New App"
   - Fill in app information

2. **Upload Build**
   - Use Xcode Organizer or Application Loader
   - Upload the archived build

3. **App Information**
   - App Name: "Ascend - Debt Management"
   - Subtitle: "AI-Powered Financial Freedom"
   - Description: [See marketing materials]
   - Keywords: debt,finance,ai,management,payoff

4. **Screenshots**
   - iPhone 6.7" Display: 1290 x 2796
   - iPhone 6.5" Display: 1242 x 2688
   - iPhone 5.5" Display: 1242 x 2208

### **4. Submit for Review**

1. **TestFlight Testing**
   - Upload build to TestFlight
   - Test with internal team
   - Test with external beta testers

2. **App Store Review**
   - Complete all required information
   - Submit for review
   - Monitor review status

## 🔒 **Security Checklist**

### **Backend Security**
- [ ] JWT_SECRET is strong and unique
- [ ] Database passwords are secure
- [ ] API keys are properly configured
- [ ] CORS is properly configured
- [ ] Rate limiting is enabled
- [ ] HTTPS is enforced
- [ ] Security headers are set

### **iOS App Security**
- [ ] API endpoints use HTTPS
- [ ] Sensitive data is stored in Keychain
- [ ] Biometric authentication is implemented
- [ ] App Transport Security is enabled
- [ ] No sensitive data in logs

### **Infrastructure Security**
- [ ] Firewall is configured
- [ ] SSH keys are used (no passwords)
- [ ] Regular security updates
- [ ] Database backups are automated
- [ ] Monitoring and alerting is set up

## 📊 **Monitoring and Analytics**

### **Backend Monitoring**

#### **PM2 Monitoring**
```bash
# Monitor processes
pm2 monit

# View logs
pm2 logs

# Monitor resources
pm2 status
```

#### **Application Monitoring**
- **Health Checks**: `/health` endpoint
- **Error Tracking**: Winston logging
- **Performance**: PM2 metrics
- **Uptime**: External monitoring service

### **iOS App Analytics**

#### **Firebase Analytics**
```swift
// Track user events
Analytics.logEvent("debt_added", parameters: [
    "amount": debt.amount,
    "type": debt.type
])
```

#### **Crash Reporting**
```swift
// Configure crash reporting
Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
```

## 🔄 **CI/CD Pipeline**

### **GitHub Actions**

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.5
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.KEY }}
        script: |
          cd /var/www/ascend-app/backend
          git pull origin main
          npm install --production
          pm2 restart ascend-backend
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Backend Issues**
```bash
# Check PM2 status
pm2 status

# View logs
pm2 logs ascend-backend

# Restart application
pm2 restart ascend-backend

# Check database connection
psql -h localhost -U ascend_user -d ascend_prod -c "SELECT 1;"
```

#### **iOS Issues**
```bash
# Clean build folder
xcodebuild clean -workspace RoundUpSavings.xcworkspace -scheme RoundUpSavings

# Reset iOS Simulator
xcrun simctl erase all

# Check provisioning profiles
security find-identity -v -p codesigning
```

### **Performance Optimization**

#### **Backend**
- Enable Redis caching
- Optimize database queries
- Use CDN for static assets
- Implement connection pooling

#### **iOS**
- Optimize image assets
- Implement lazy loading
- Use background fetch
- Optimize network requests

## 📈 **Scaling Considerations**

### **Backend Scaling**
- **Horizontal Scaling**: Multiple server instances
- **Load Balancing**: Nginx or AWS ALB
- **Database Scaling**: Read replicas, sharding
- **Caching**: Redis cluster

### **iOS Scaling**
- **CDN**: For static assets
- **API Versioning**: For backward compatibility
- **Feature Flags**: For gradual rollouts
- **A/B Testing**: For optimization

## 🎯 **Success Metrics**

### **Technical Metrics**
- **Uptime**: 99.9%+
- **Response Time**: < 200ms
- **Error Rate**: < 0.1%
- **App Store Rating**: 4.5+

### **Business Metrics**
- **User Acquisition**: Monthly growth
- **User Retention**: 30-day retention
- **Feature Adoption**: Key feature usage
- **Revenue**: Subscription growth

---

**🎉 Congratulations! Your Ascend app is now deployed and ready to help users achieve financial freedom!**

For support and updates, visit our [GitHub repository](https://github.com/yourusername/ascend-app).
