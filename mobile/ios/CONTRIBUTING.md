# 🤝 Contributing to Ascend

Thank you for your interest in contributing to Ascend! We're excited to have you join our community of developers working to transform financial futures through AI-powered debt management.

## 📋 **Types of Contributions**

We welcome all types of contributions:

- 🐛 **Bug Reports**: Help us identify and fix issues
- 💡 **Feature Requests**: Suggest new features and improvements
- 📝 **Documentation**: Improve our docs and guides
- 🔧 **Code Contributions**: Submit pull requests with fixes or features
- 🧪 **Testing**: Help us test and improve reliability
- 🌍 **Localization**: Help translate the app to new languages

## 🚀 **Getting Started**

### **Prerequisites**

Before contributing, make sure you have:

- **iOS Development**: Xcode 15.0+, iOS 15.0+
- **Backend Development**: Node.js 18.0+, PostgreSQL 12+
- **Git**: Latest version of Git
- **GitHub Account**: For pull requests and issues

### **Development Setup**

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/yourusername/ascend-app.git
   cd ascend-app
   ```

2. **Set Up Backend**
   ```bash
   cd backend
   npm install
   cp .env.example .env
   # Edit .env with your API keys
   npm run dev
   ```

3. **Set Up iOS App**
   ```bash
   cd mobile/ios
   open RoundUpSavings.xcodeproj
   # Build and run in Xcode
   ```

4. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

## 📝 **Code Style Guidelines**

### **Swift (iOS)**
- Use Swift 5.0+ features
- Follow Apple's Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Use SwiftLint for code formatting

```swift
// Good
func calculateDebtPayoff(debt: Debt, payment: Double) -> Date {
    // Calculate payoff date based on payment amount
    let remainingBalance = debt.balance - payment
    return Date().addingTimeInterval(remainingBalance / payment * 30 * 24 * 60 * 60)
}

// Bad
func calc(d: Debt, p: Double) -> Date {
    return Date()
}
```

### **JavaScript (Backend)**
- Use ES6+ features
- Follow Airbnb JavaScript Style Guide
- Use meaningful variable and function names
- Add JSDoc comments for functions
- Use ESLint and Prettier

```javascript
// Good
/**
 * Calculate debt payoff strategy
 * @param {Array} debts - Array of debt objects
 * @param {string} strategy - Payoff strategy type
 * @returns {Object} Optimized payoff plan
 */
const calculatePayoffStrategy = (debts, strategy) => {
  // Implementation
};

// Bad
const calc = (d, s) => {
  // Implementation
};
```

## 🏗️ **Architecture Patterns**

### **iOS App (MVVM)**
- **Models**: Data structures and business logic
- **Views**: UI components and user interaction
- **ViewModels**: Business logic and data binding
- **Services**: Network calls and external integrations

### **Backend (MVC)**
- **Models**: Database schemas and business logic
- **Controllers**: Request handling and response formatting
- **Routes**: API endpoint definitions
- **Services**: Business logic and external integrations

## 🧪 **Testing Guidelines**

### **Backend Testing**
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

### **iOS Testing**
- Write unit tests for business logic
- Write UI tests for critical user flows
- Test both success and error scenarios
- Maintain >80% code coverage

## 📤 **Submitting Changes**

### **1. Make Your Changes**
- Write clear, focused commits
- Test your changes thoroughly
- Update documentation if needed
- Follow the code style guidelines

### **2. Commit Your Changes**
```bash
# Use conventional commit messages
git commit -m "feat: add debt consolidation calculator"
git commit -m "fix: resolve authentication token refresh issue"
git commit -m "docs: update API documentation"
```

**Commit Message Format:**
```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### **3. Push and Create Pull Request**
```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub with:
- Clear title and description
- Link to related issues
- Screenshots for UI changes
- Test results

## 🐛 **Reporting Bugs**

### **Bug Report Template**
```markdown
**Bug Description**
A clear description of what the bug is.

**Steps to Reproduce**
1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- iOS Version: [e.g., 15.0]
- Device: [e.g., iPhone 13]
- App Version: [e.g., 1.0.0]
- Backend Version: [e.g., 1.0.0]

**Screenshots**
If applicable, add screenshots.

**Additional Context**
Any other context about the problem.
```

## 💡 **Requesting Features**

### **Feature Request Template**
```markdown
**Feature Description**
A clear description of the feature you'd like to see.

**Problem Statement**
What problem does this feature solve?

**Proposed Solution**
How would you like this feature to work?

**Alternative Solutions**
Any alternative solutions you've considered.

**Additional Context**
Any other context or screenshots.
```

## 🔍 **Review Process**

### **Pull Request Review**
1. **Automated Checks**: CI/CD pipeline runs tests
2. **Code Review**: Team members review your code
3. **Testing**: Changes are tested in staging
4. **Approval**: Changes are approved and merged

### **Review Checklist**
- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No breaking changes (or properly documented)
- [ ] Security considerations addressed

## 🏆 **Recognition**

### **Contributor Recognition**
- Contributors are listed in our README
- Significant contributions get special recognition
- Regular contributors may be invited to join the core team

### **Contributor Levels**
- **🌱 Newcomer**: First contribution
- **🌿 Regular**: Multiple contributions
- **🌳 Veteran**: Significant contributions
- **🏆 Core Team**: Maintainer level

## 📞 **Getting Help**

### **Community Support**
- **GitHub Discussions**: [Ask questions](https://github.com/yourusername/ascend-app/discussions)
- **Discord**: Join our community server
- **Email**: dev@ascend-financial.com

### **Development Resources**
- **API Documentation**: [docs.ascend-financial.com](https://docs.ascend-financial.com)
- **Design System**: [design.ascend-financial.com](https://design.ascend-financial.com)
- **Architecture Guide**: [ARCHITECTURE.md](ARCHITECTURE.md)

## 📄 **Code of Conduct**

We are committed to providing a welcoming and inclusive environment for all contributors. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) before participating.

## 🎯 **Project Goals**

Our mission is to help people achieve financial freedom through intelligent debt management. When contributing, please keep these goals in mind:

- **User-First**: Always prioritize user experience
- **Security**: Maintain the highest security standards
- **Accessibility**: Ensure the app is accessible to everyone
- **Performance**: Keep the app fast and efficient
- **Privacy**: Protect user data and privacy

---

**Thank you for contributing to Ascend! Together, we're transforming financial futures through AI-powered debt management.** 🚀
