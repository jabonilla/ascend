# 🤝 Contributing to Ascend

Thank you for your interest in contributing to Ascend! We're excited to have you join our community of developers working to transform financial futures through AI-powered debt management.

## 🎯 How to Contribute

### **Types of Contributions**

We welcome contributions in many forms:

- 🐛 **Bug Reports**: Help us identify and fix issues
- 💡 **Feature Requests**: Suggest new features and improvements
- 📝 **Documentation**: Improve our docs and guides
- 🔧 **Code Contributions**: Submit pull requests with fixes or features
- 🧪 **Testing**: Help us test and improve the app
- 🌍 **Localization**: Help translate the app to new languages

## 🚀 Getting Started

### **Prerequisites**

- **iOS Development**: Xcode 15.0+, iOS 15.0+
- **Backend Development**: Node.js 18.0+, PostgreSQL 12+
- **Git**: Basic Git knowledge
- **APIs**: Plaid, OpenAI accounts (for testing)

### **1. Fork the Repository**

1. Go to [Ascend App Repository](https://github.com/yourusername/ascend-app)
2. Click the "Fork" button in the top right
3. Clone your forked repository:

```bash
git clone https://github.com/yourusername/ascend-app.git
cd ascend-app
```

### **2. Set Up Development Environment**

#### **Backend Setup**
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your API keys
npm run dev
```

#### **iOS Setup**
```bash
cd mobile/ios
pod install
open RoundUpSavings.xcworkspace
```

### **3. Create a Feature Branch**

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

## 📝 Development Guidelines

### **Code Style**

#### **Swift (iOS)**
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Implement proper error handling
- Add comprehensive documentation comments
- Use SwiftLint for code formatting

#### **JavaScript (Backend)**
- Follow [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- Use meaningful variable and function names
- Implement proper error handling
- Add JSDoc comments for functions
- Use ESLint and Prettier for formatting

### **Architecture Patterns**

#### **iOS App**
- **MVVM**: Model-View-ViewModel for UI logic
- **Service Layer**: Business logic separation
- **Protocol-Oriented**: Swift protocol usage
- **Dependency Injection**: Service dependencies

#### **Backend API**
- **RESTful Design**: Follow REST principles
- **Middleware Pattern**: Reusable middleware functions
- **Service Layer**: Business logic separation
- **Repository Pattern**: Data access abstraction

### **Testing**

#### **iOS Testing**
```bash
# Unit Tests
xcodebuild test -workspace RoundUpSavings.xcworkspace -scheme RoundUpSavings -destination 'platform=iOS Simulator,name=iPhone 15'

# UI Tests
xcodebuild test -workspace RoundUpSavings.xcworkspace -scheme RoundUpSavingsUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### **Backend Testing**
```bash
cd backend
npm test
npm run test:coverage
```

### **Commit Messages**

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

feat(auth): add biometric authentication support
fix(api): resolve token refresh issue
docs(readme): update installation instructions
style(ui): improve button styling
refactor(services): simplify authentication logic
test(api): add comprehensive API tests
chore(deps): update dependencies
```

## 🔄 Pull Request Process

### **1. Before Submitting**

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation is updated
- [ ] No breaking changes (or clearly documented)

### **2. Create Pull Request**

1. Push your branch to your fork
2. Create a pull request against the `main` branch
3. Fill out the pull request template
4. Add relevant labels and assignees

### **3. Pull Request Template**

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
Add screenshots for UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No console errors
```

### **4. Review Process**

- Maintainers will review your PR
- Address any feedback or requested changes
- Once approved, your PR will be merged

## 🐛 Bug Reports

### **Before Reporting**

1. Check existing issues for duplicates
2. Try to reproduce the issue
3. Gather relevant information

### **Bug Report Template**

```markdown
## Bug Description
Clear description of the issue

## Steps to Reproduce
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- iOS Version: 15.0
- Device: iPhone 15
- App Version: 1.0.0
- Backend Version: 1.0.0

## Additional Information
Screenshots, logs, etc.
```

## 💡 Feature Requests

### **Feature Request Template**

```markdown
## Feature Description
Clear description of the feature

## Problem Statement
What problem does this solve?

## Proposed Solution
How should this work?

## Alternative Solutions
Other approaches considered

## Additional Context
Screenshots, mockups, etc.
```

## 🏷️ Issue Labels

We use the following labels to organize issues:

- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Improvements to documentation
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention is needed
- `priority: high`: High priority issues
- `priority: low`: Low priority issues
- `iOS`: iOS app related
- `backend`: Backend API related
- `security`: Security related issues

## 🎉 Recognition

### **Contributors**

We recognize contributors in several ways:

- **Contributors List**: All contributors listed in README
- **Release Notes**: Contributors credited in releases
- **Hall of Fame**: Special recognition for significant contributions

### **Contributor Levels**

- **🌱 Newcomer**: First contribution
- **🌿 Regular**: Multiple contributions
- **🌳 Core**: Significant contributions
- **🏆 Maintainer**: Repository maintainer

## 📞 Getting Help

### **Community Channels**

- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ascend-app/discussions)
- **Issues**: [GitHub Issues](https://github.com/yourusername/ascend-app/issues)
- **Email**: contributors@ascend-financial.com

### **Development Resources**

- **API Documentation**: [docs.ascend-financial.com](https://docs.ascend-financial.com)
- **Design System**: [design.ascend-financial.com](https://design.ascend-financial.com)
- **Architecture Guide**: [architecture.ascend-financial.com](https://architecture.ascend-financial.com)

## 📄 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read our [Code of Conduct](CODE_OF_CONDUCT.md) to understand our community standards.

## 📜 License

By contributing to Ascend, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to Ascend! Together, we're transforming financial futures through AI-powered debt management.** 🚀
