import Foundation

class FinancialDataService {
    static let shared = FinancialDataService()
    
    private var debts: [Debt] = []
    private var payments: [Payment] = []
    private let authService = AuthenticationService.shared
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func initialize() {
        loadCachedData()
    }
    
    // MARK: - Enhanced Networking
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        retryCount: Int = 3
    ) async throws -> T {
        guard let headers = authService.getAuthHeaders() else {
            throw FinancialDataError.notAuthenticated
        }
        
        let url = URL(string: "\(APIConstants.baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(headers["Authorization"]!)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FinancialDataError.networkError
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(T.self, from: data)
            case 401:
                throw FinancialDataError.notAuthenticated
            case 403:
                throw FinancialDataError.forbidden
            case 404:
                throw FinancialDataError.notFound
            case 422:
                throw FinancialDataError.validationError
            case 500...599:
                throw FinancialDataError.serverError
            default:
                throw FinancialDataError.unknownError
            }
        } catch {
            if retryCount > 0 && shouldRetry(error: error) {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(3 - retryCount))) * 1_000_000_000)
                return try await makeRequest(endpoint: endpoint, method: method, body: body, retryCount: retryCount - 1)
            }
            throw error
        }
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.networkConnectionLost, .notConnectedToInternet, .timedOut].contains(urlError.code)
        }
        return false
    }
    
    // MARK: - Debt Management
    
    func getDebts() async throws -> [Debt] {
        let debts: [Debt] = try await makeRequest(endpoint: "/debts")
        self.debts = debts
        cacheDebts(debts)
        return debts
    }
    
    func fetchDebts() async throws -> [Debt] {
        return try await getDebts()
    }
    
    func addDebt(_ debt: Debt) async throws -> Debt {
        let debtData = try JSONEncoder().encode(debt)
        let debtDict = try JSONSerialization.jsonObject(with: debtData) as? [String: Any] ?? [:]
        
        let newDebt: Debt = try await makeRequest(
            endpoint: "/debts",
            method: .POST,
            body: debtDict
        )
        
        debts.append(newDebt)
        cacheDebts(debts)
        return newDebt
    }
    
    func updateDebt(_ debt: Debt) async throws -> Debt {
        let debtData = try JSONEncoder().encode(debt)
        let debtDict = try JSONSerialization.jsonObject(with: debtData) as? [String: Any] ?? [:]
        
        let updatedDebt: Debt = try await makeRequest(
            endpoint: "/debts/\(debt.id)",
            method: .PUT,
            body: debtDict
        )
        
        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index] = updatedDebt
            cacheDebts(debts)
        }
        
        return updatedDebt
    }
    
    func deleteDebt(_ debtId: String) async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/debts/\(debtId)",
            method: .DELETE
        )
        
        debts.removeAll { $0.id == debtId }
        cacheDebts(debts)
    }
    
    // MARK: - Payment Management
    
    func getPayments() async throws -> [Payment] {
        let payments: [Payment] = try await makeRequest(endpoint: "/payments")
        self.payments = payments
        cachePayments(payments)
        return payments
    }
    
    func fetchPayments() async throws -> [Payment] {
        return try await getPayments()
    }
    
    func schedulePayment(_ payment: Payment) async throws -> Payment {
        let paymentData = try JSONEncoder().encode(payment)
        let paymentDict = try JSONSerialization.jsonObject(with: paymentData) as? [String: Any] ?? [:]
        
        let scheduledPayment: Payment = try await makeRequest(
            endpoint: "/payments/schedule",
            method: .POST,
            body: paymentDict
        )
        
        payments.append(scheduledPayment)
        cachePayments(payments)
        return scheduledPayment
    }
    
    func cancelPayment(_ paymentId: String) async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/payments/\(paymentId)/cancel",
            method: .POST
        )
        
        if let index = payments.firstIndex(where: { $0.id == paymentId }) {
            payments.remove(at: index)
            cachePayments(payments)
        }
    }
    
    // MARK: - AI Optimization
    
    func generateOptimizationStrategy() async throws -> OptimizationStrategy {
        let strategy: OptimizationStrategy = try await makeRequest(
            endpoint: "/optimize/calculate",
            method: .POST
        )
        return strategy
    }
    
    func getProjections() async throws -> [MonthlyProjection] {
        let projections: [MonthlyProjection] = try await makeRequest(endpoint: "/optimize/projections")
        return projections
    }
    
    // MARK: - Debt Discovery
    
    func discoverDebts() async throws -> [DiscoveredDebt] {
        let discoveredDebts: [DiscoveredDebt] = try await makeRequest(endpoint: "/discovery/debts")
        return discoveredDebts
    }
    
    func analyzeDebts(_ debts: [DiscoveredDebt]) async throws -> DebtAnalysis {
        let debtsData = try JSONEncoder().encode(debts)
        let debtsArray = try JSONSerialization.jsonObject(with: debtsData) as? [[String: Any]] ?? []
        
        let analysis: DebtAnalysis = try await makeRequest(
            endpoint: "/discovery/analyze",
            method: .POST,
            body: ["debts": debtsArray]
        )
        return analysis
    }
    
    func importDiscoveredDebts(_ debts: [DiscoveredDebt]) async throws {
        let debtsData = try JSONEncoder().encode(debts)
        let debtsArray = try JSONSerialization.jsonObject(with: debtsData) as? [[String: Any]] ?? []
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/discovery/import",
            method: .POST,
            body: ["debts": debtsArray]
        )
    }
    
    // MARK: - Payoff Calculator
    
    func calculatePayoffPlan(
        debts: [Debt],
        scenario: PayoffScenario,
        input: CalculatorInput
    ) async throws -> PayoffCalculation {
        let requestBody: [String: Any] = [
            "debts": debts.map { debt in
                [
                    "id": debt.id,
                    "name": debt.name,
                    "currentBalance": debt.currentBalance,
                    "apr": debt.apr,
                    "minimumPayment": debt.minimumPayment
                ]
            },
            "scenario": scenario.rawValue,
            "extraPayment": input.extraPayment,
            "targetPayoffDate": input.targetPayoffDate?.timeIntervalSince1970,
            "debtPriorities": input.debtPriorities
        ]
        
        let calculation: PayoffCalculation = try await makeRequest(
            endpoint: "/calculator/payoff",
            method: .POST,
            body: requestBody
        )
        return calculation
    }
    
    func saveScenario(_ scenario: SavedScenario) async throws {
        let scenarioData = try JSONEncoder().encode(scenario)
        let scenarioDict = try JSONSerialization.jsonObject(with: scenarioData) as? [String: Any] ?? [:]
        
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/scenarios",
            method: .POST,
            body: scenarioDict
        )
    }
    
    func getSavedScenarios() async throws -> [SavedScenario] {
        let scenarios: [SavedScenario] = try await makeRequest(endpoint: "/scenarios")
        return scenarios
    }
    
    // MARK: - Debt Consolidation
    
    func getConsolidationOptions() async throws -> [ConsolidationOption] {
        let options: [ConsolidationOption] = try await makeRequest(endpoint: "/consolidation/options")
        return options
    }
    
    func calculateConsolidation(
        debts: [Debt],
        option: ConsolidationOption
    ) async throws -> ConsolidationComparison {
        let requestBody: [String: Any] = [
            "debts": debts.map { debt in
                [
                    "id": debt.id,
                    "name": debt.name,
                    "currentBalance": debt.currentBalance,
                    "apr": debt.apr,
                    "minimumPayment": debt.minimumPayment
                ]
            },
            "consolidationOption": [
                "id": option.id,
                "name": option.name,
                "apr": option.apr,
                "term": option.term,
                "originationFee": option.originationFee
            ]
        ]
        
        let comparison: ConsolidationComparison = try await makeRequest(
            endpoint: "/consolidation/calculate",
            method: .POST,
            body: requestBody
        )
        return comparison
    }
    
    // MARK: - Bank Account Aggregation
    
    func createPlaidLinkToken() async throws -> PlaidLinkToken {
        let linkToken: PlaidLinkToken = try await makeRequest(
            endpoint: "/plaid/link-token",
            method: .POST
        )
        return linkToken
    }
    
    func connectBankAccount() async throws -> PlaidLinkToken {
        return try await createPlaidLinkToken()
    }
    
    func exchangePlaidToken(_ publicToken: String) async throws {
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/plaid/exchange-token",
            method: .POST,
            body: ["public_token": publicToken]
        )
    }
    
    // MARK: - Analytics
    
    func getProgressMetrics() async throws -> ProgressMetrics {
        let metrics: ProgressMetrics = try await makeRequest(endpoint: "/analytics/progress")
        return metrics
    }
    
    func getInsights() async throws -> [Insight] {
        let insights: [Insight] = try await makeRequest(endpoint: "/analytics/insights")
        return insights
    }
    
    // MARK: - Caching
    
    private func cacheDebts(_ debts: [Debt]) {
        if let data = try? JSONEncoder().encode(debts) {
            UserDefaults.standard.set(data, forKey: "cached_debts")
        }
    }
    
    private func cachePayments(_ payments: [Payment]) {
        if let data = try? JSONEncoder().encode(payments) {
            UserDefaults.standard.set(data, forKey: "cached_payments")
        }
    }
    
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "cached_debts"),
           let debts = try? JSONDecoder().decode([Debt].self, from: data) {
            self.debts = debts
        }
        
        if let data = UserDefaults.standard.data(forKey: "cached_payments"),
           let payments = try? JSONDecoder().decode([Payment].self, from: data) {
            self.payments = payments
        }
    }
}

// MARK: - Supporting Types

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

struct EmptyResponse: Codable {}

struct OptimizationStrategy: Codable {
    let id: String
    let userId: String
    let name: String
    let type: StrategyType
    let monthlyPayment: Double
    let projectedPayoffDate: Date
    let totalInterestSaved: Double
    let monthsSaved: Int
    let debtPaymentOrder: [String]
    let isActive: Bool
    
    enum StrategyType: String, Codable {
        case avalanche = "avalanche"
        case snowball = "snowball"
        case hybrid = "hybrid"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .avalanche: return "Avalanche Method"
            case .snowball: return "Snowball Method"
            case .hybrid: return "Hybrid Method"
            case .custom: return "Custom Strategy"
            }
        }
    }
}

struct MonthlyProjection: Codable {
    let month: Date
    let totalBalance: Double
    let totalInterestPaid: Double
    let debtBreakdown: [String: Double]
}

struct ProgressMetrics: Codable {
    let totalDebt: Double
    let totalPaid: Double
    let interestSaved: Double
    let monthsAhead: Int
    let progressPercentage: Double
}

struct PlaidLinkToken: Codable {
    let token: String
    let expiration: Date
}

struct Insight: Codable {
    let id: String
    let type: InsightType
    let title: String
    let message: String
    let action: String?
    let priority: InsightPriority
    let createdAt: Date
    
    enum InsightType: String, Codable {
        case payment = "payment"
        case optimization = "optimization"
        case consolidation = "consolidation"
        case milestone = "milestone"
        case warning = "warning"
    }
    
    enum InsightPriority: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
}

enum FinancialDataError: Error, LocalizedError {
    case notAuthenticated
    case forbidden
    case notFound
    case validationError
    case serverError
    case networkError
    case unknownError
    case fetchFailed
    case addFailed
    case updateFailed
    case deleteFailed
    case scheduleFailed
    case optimizationFailed
    case plaidConnectionFailed
    case plaidExchangeFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to access financial data."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .validationError:
            return "The provided data is invalid. Please check your input."
        case .serverError:
            return "Server error. Please try again later."
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        case .fetchFailed:
            return "Failed to fetch data. Please try again."
        case .addFailed:
            return "Failed to add item. Please try again."
        case .updateFailed:
            return "Failed to update item. Please try again."
        case .deleteFailed:
            return "Failed to delete item. Please try again."
        case .scheduleFailed:
            return "Failed to schedule payment. Please try again."
        case .optimizationFailed:
            return "Failed to generate optimization strategy. Please try again."
        case .plaidConnectionFailed:
            return "Failed to connect bank account. Please try again."
        case .plaidExchangeFailed:
            return "Failed to complete bank connection. Please try again."
        }
    }
}
