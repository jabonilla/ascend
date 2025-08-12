import Foundation

struct APIConstants {
    // MARK: - Base Configuration
    
    #if DEBUG
    static let baseURL = "http://localhost:3000"
    #else
    static let baseURL = "https://api.ascend-financial.com" // Production URL
    #endif
    
    static let apiVersion = "v1"
    static let timeoutInterval: TimeInterval = 30
    static let maxRetries = 3
    
    // MARK: - Endpoints
    
    struct Endpoints {
        // Authentication
        static let register = "/api/auth/register"
        static let login = "/api/auth/login"
        static let refresh = "/api/auth/refresh"
        static let logout = "/api/auth/logout"
        static let forgotPassword = "/api/auth/forgot-password"
        static let resetPassword = "/api/auth/reset-password"
        static let validateToken = "/api/auth/validate"
        
        // User Management
        static let userProfile = "/api/users/profile"
        static let updateProfile = "/api/users/profile"
        static let changePassword = "/api/users/change-password"
        static let deleteAccount = "/api/users/account"
        
        // Debt Management
        static let debts = "/api/debts"
        static let debt = "/api/debts/{id}"
        static let debtStats = "/api/debts/stats"
        
        // Payment Management
        static let payments = "/api/payments"
        static let payment = "/api/payments/{id}"
        static let schedulePayment = "/api/payments/schedule"
        static let cancelPayment = "/api/payments/{id}/cancel"
        static let paymentStats = "/api/payments/stats"
        
        // AI Optimization
        static let optimization = "/api/optimization"
        static let generateStrategy = "/api/optimization/strategy"
        static let projections = "/api/optimization/projections"
        static let insights = "/api/optimization/insights"
        
        // Debt Discovery
        static let discoveryDebts = "/api/discovery/debts"
        static let discoveryAnalyze = "/api/discovery/analyze"
        static let discoveryImport = "/api/discovery/import"
        
        // Payoff Calculator
        static let calculator = "/api/calculator"
        static let calculatePayoff = "/api/calculator/payoff"
        static let savedScenarios = "/api/calculator/scenarios"
        static let saveScenario = "/api/calculator/scenarios"
        
        // Debt Consolidation
        static let consolidationOptions = "/api/consolidation/options"
        static let consolidationCalculate = "/api/consolidation/calculate"
        static let consolidationApply = "/api/consolidation/apply"
        
        // Plaid Integration
        static let plaidLinkToken = "/api/plaid/link-token"
        static let plaidExchangeToken = "/api/plaid/exchange-token"
        static let plaidAccounts = "/api/plaid/accounts"
        static let plaidTransactions = "/api/plaid/transactions"
        static let plaidSync = "/api/plaid/sync"
        static let plaidDisconnect = "/api/plaid/disconnect"
        
        // Analytics
        static let analyticsProgress = "/api/analytics/progress"
        static let analyticsInsights = "/api/analytics/insights"
        static let analyticsTrends = "/api/analytics/trends"
        
        // Community
        static let communityChallenges = "/api/community/challenges"
        static let communityGroups = "/api/community/groups"
        static let communityLeaderboard = "/api/community/leaderboard"
        static let communityAchievements = "/api/community/achievements"
        
        // Notifications
        static let notifications = "/api/notifications"
        static let notificationSettings = "/api/notifications/settings"
        static let markRead = "/api/notifications/{id}/read"
        
        // Webhooks
        static let webhooks = "/api/webhooks"
        static let plaidWebhook = "/api/webhooks/plaid"
        static let paymentWebhook = "/api/webhooks/payment"
    }
    
    // MARK: - Headers
    
    struct Headers {
        static let contentType = "Content-Type"
        static let authorization = "Authorization"
        static let accept = "Accept"
        static let userAgent = "User-Agent"
        static let acceptLanguage = "Accept-Language"
        static let cacheControl = "Cache-Control"
        static let ifModifiedSince = "If-Modified-Since"
        static let eTag = "ETag"
        
        static let contentTypeValue = "application/json"
        static let acceptValue = "application/json"
        static let userAgentValue = "Ascend-iOS/1.0"
        static let acceptLanguageValue = "en-US,en;q=0.9"
    }
    
    // MARK: - Error Codes
    
    struct ErrorCodes {
        static let badRequest = 400
        static let unauthorized = 401
        static let forbidden = 403
        static let notFound = 404
        static let methodNotAllowed = 405
        static let tooManyRequests = 429
        static let internalServerError = 500
        static let badGateway = 502
        static let serviceUnavailable = 503
        static let gatewayTimeout = 504
    }
    
    // MARK: - Request Configuration
    
    struct Request {
        static let timeoutInterval: TimeInterval = 30
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
        static let exponentialBackoff = true
    }
    
    // MARK: - Cache Configuration
    
    struct Cache {
        static let maxAge: TimeInterval = 300 // 5 minutes
        static let maxSize = 50 * 1024 * 1024 // 50 MB
        static let enableDiskCache = true
        static let enableMemoryCache = true
    }
    
    // MARK: - Rate Limiting
    
    struct RateLimit {
        static let requestsPerMinute = 60
        static let requestsPerHour = 1000
        static let burstLimit = 10
        static let retryAfterHeader = "Retry-After"
    }
    
    // MARK: - Features
    
    struct Features {
        static let enablePlaid = true
        static let enableAI = true
        static let enableNotifications = true
        static let enableAnalytics = true
        static let enableOfflineMode = true
        static let enableBiometrics = true
    }
    
    // MARK: - Environment
    
    struct Environment {
        static let isProduction = false
        static let enableLogging = true
        static let enableCrashReporting = true
        static let enableAnalytics = true
    }
}

// MARK: - API Response Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: APIError?
    let meta: APIMeta?
}

struct APIError: Codable {
    let message: String
    let code: String
    let details: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case message, code, details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decode(String.self, forKey: .message)
        code = try container.decode(String.self, forKey: .code)
        details = try container.decodeIfPresent([String: Any].self, forKey: .details)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(details, forKey: .details)
    }
}

struct APIMeta: Codable {
    let pagination: PaginationInfo?
    let timestamp: String
    let version: String
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrev: Bool
}

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let pagination: PaginationInfo
}

// MARK: - Request Models

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RegisterRequest: Codable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let phone: String?
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ResetPasswordRequest: Codable {
    let token: String
    let password: String
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

struct EmptyResponse: Codable {}

// MARK: - Extensions

extension APIConstants {
    static func buildURL(for endpoint: String, parameters: [String: String]? = nil) -> URL? {
        var urlString = baseURL + endpoint
        
        if let parameters = parameters, !parameters.isEmpty {
            let queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            var components = URLComponents(string: urlString)
            components?.queryItems = queryItems
            return components?.url
        }
        
        return URL(string: urlString)
    }
    
    static func getHeaders(includeAuth: Bool = true, accessToken: String? = nil) -> [String: String] {
        var headers: [String: String] = [
            Headers.contentType: Headers.contentTypeValue,
            Headers.accept: Headers.acceptValue,
            Headers.userAgent: Headers.userAgentValue,
            Headers.acceptLanguage: Headers.acceptLanguageValue
        ]
        
        if includeAuth, let token = accessToken {
            headers[Headers.authorization] = "Bearer \(token)"
        }
        
        return headers
    }
    
    static func shouldRetry(for statusCode: Int) -> Bool {
        return statusCode >= 500 || statusCode == 429
    }
    
    static func getRetryDelay(attempt: Int) -> TimeInterval {
        if Request.exponentialBackoff {
            return Request.retryDelay * pow(2.0, Double(attempt - 1))
        }
        return Request.retryDelay
    }
}
