# 🚀 Ascend App Deployment Guide: Supabase + Railway

## 📋 **Prerequisites**
- GitHub account with the Ascend repository
- Supabase account (free tier available)
- Railway account (free tier available)

## 🎯 **Step 1: Set Up Supabase**

### **1.1 Create Supabase Project**
1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Sign in with GitHub
4. Click "New Project"
5. Choose your organization
6. Enter project details:
   - **Name**: `ascend-app`
   - **Database Password**: Generate a strong password
   - **Region**: Choose closest to your users
7. Click "Create new project"

### **1.2 Get Supabase Credentials**
1. Go to **Settings** → **API**
2. Copy these values:
   - **Project URL** (e.g., `https://your-project.supabase.co`)
   - **Anon public key** (starts with `eyJ...`)
   - **Service role key** (starts with `eyJ...`)

### **1.3 Set Up Database Schema**
1. Go to **SQL Editor**
2. Copy the contents of `supabase-schema.sql`
3. Paste and run the SQL commands
4. Verify tables are created in **Table Editor**

## 🚂 **Step 2: Deploy to Railway**

### **2.1 Connect GitHub to Railway**
1. Go to [railway.app](https://railway.app)
2. Sign in with GitHub
3. Click "New Project"
4. Select "Deploy from GitHub repo"
5. Choose your `ascend` repository
6. Select the `backend` folder

### **2.2 Configure Environment Variables**
In Railway dashboard, go to **Variables** and add:

```env
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

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

# Email Configuration
SENDGRID_API_KEY=your-sendgrid-api-key
EMAIL_FROM=noreply@ascend-financial.com

# CORS Configuration
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

### **2.3 Deploy**
1. Railway will automatically detect the Node.js project
2. It will install dependencies and start the server
3. Check the **Deployments** tab for status
4. Your API will be available at: `https://your-app-name.railway.app`

## 🔧 **Step 3: Update iOS App**

### **3.1 Update API Endpoints**
In your iOS project, update `APIConstants.swift`:

```swift
#if DEBUG
    static let baseURL = "http://localhost:3000"
#else
    static let baseURL = "https://your-app-name.railway.app"
#endif
```

### **3.2 Add Supabase Client**
Install Supabase Swift SDK:
```bash
# In your iOS project directory
pod init
```

Add to `Podfile`:
```ruby
pod 'Supabase'
```

Then:
```bash
pod install
```

## 🧪 **Step 4: Test Everything**

### **4.1 Test Backend API**
```bash
# Test health endpoint
curl https://your-app-name.railway.app/health

# Test registration
curl -X POST https://your-app-name.railway.app/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","firstName":"Test","lastName":"User"}'
```

### **4.2 Test iOS App**
1. Open `RoundUpSavings.xcworkspace` in Xcode
2. Build and run on simulator
3. Test registration and login
4. Test debt management features

## 🔄 **Step 5: Continuous Deployment**

### **5.1 Automatic Deployments**
Railway automatically deploys when you push to GitHub:
```bash
git add .
git commit -m "Update API endpoints"
git push origin main
```

### **5.2 Environment Management**
- **Development**: Use local environment
- **Staging**: Create staging branch and Railway project
- **Production**: Use main branch and production Railway project

## 📊 **Step 6: Monitoring**

### **6.1 Railway Monitoring**
- Check **Metrics** tab for performance
- Monitor **Logs** for errors
- Set up alerts for downtime

### **6.2 Supabase Monitoring**
- Check **Database** → **Logs** for queries
- Monitor **Auth** → **Users** for signups
- Check **Storage** usage

## 🚨 **Troubleshooting**

### **Common Issues**

#### **Backend Won't Start**
```bash
# Check Railway logs
# Verify environment variables
# Ensure PORT is set correctly
```

#### **Database Connection Issues**
```bash
# Verify Supabase URL and keys
# Check RLS policies
# Test connection in Supabase dashboard
```

#### **iOS App Can't Connect**
```bash
# Verify API URL is correct
# Check CORS settings
# Test API endpoints manually
```

## 🎉 **Success!**

Your Ascend app is now deployed with:
- ✅ **Supabase** for database and authentication
- ✅ **Railway** for backend hosting
- ✅ **Automatic deployments** from GitHub
- ✅ **Real-time features** ready
- ✅ **Scalable architecture**

## 📈 **Next Steps**

1. **Set up custom domain** in Railway
2. **Configure SSL certificates**
3. **Set up monitoring and alerts**
4. **Prepare for App Store submission**
5. **Plan for scaling**

---

**🎯 Your Ascend app is now live and ready to help users achieve financial freedom!**
