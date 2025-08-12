import Foundation
import Plaid

class PlaidService {
    static let shared = PlaidService()
    
    private let networkManager = NetworkManager.shared
    private let keychainService = KeychainService()
    
    private init() {}
    
    // MARK: - Plaid Configuration
    
    func configure() {
        // Configure Plaid with your client credentials
        // This would typically be done in AppDelegate or a configuration file
        #if DEBUG
        // Use sandbox environment for development
        #else
        // Use production environment
        #endif
    }
    
    // MARK: - Link Token Management
    
    func createLinkToken() async throws -> PlaidLinkToken {
        let response: APIResponse<PlaidLinkToken> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidLinkToken,
            method: .POST,
            cachePolicy: .networkOnly
        )
        
        guard response.success, let linkToken = response.data else {
            throw PlaidError.linkTokenCreationFailed
        }
        
        return linkToken
    }
    
    func exchangePublicToken(_ publicToken: String) async throws {
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidExchangeToken,
            method: .POST,
            body: ["public_token": publicToken],
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw PlaidError.tokenExchangeFailed
        }
    }
    
    // MARK: - Account Management
    
    func getAccounts() async throws -> [PlaidAccount] {
        let response: APIResponse<[PlaidAccount]> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidAccounts,
            cachePolicy: .cacheFirst
        )
        
        guard response.success, let accounts = response.data else {
            throw PlaidError.accountsFetchFailed
        }
        
        return accounts
    }
    
    func getAccountBalance(_ accountId: String) async throws -> PlaidAccountBalance {
        let response: APIResponse<PlaidAccountBalance> = try await networkManager.request(
            endpoint: "\(APIConstants.Endpoints.plaidAccounts)/\(accountId)/balance",
            cachePolicy: .networkOnly
        )
        
        guard response.success, let balance = response.data else {
            throw PlaidError.balanceFetchFailed
        }
        
        return balance
    }
    
    // MARK: - Transaction Management
    
    func getTransactions(accountId: String, startDate: Date, endDate: Date) async throws -> [PlaidTransaction] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let parameters: [String: String] = [
            "account_id": accountId,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        
        let response: APIResponse<[PlaidTransaction]> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidTransactions,
            parameters: parameters,
            cachePolicy: .cacheFirst
        )
        
        guard response.success, let transactions = response.data else {
            throw PlaidError.transactionsFetchFailed
        }
        
        return transactions
    }
    
    func syncTransactions() async throws {
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidSync,
            method: .POST,
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw PlaidError.syncFailed
        }
    }
    
    // MARK: - Debt Discovery
    
    func discoverDebts() async throws -> [DiscoveredDebt] {
        let response: APIResponse<[DiscoveredDebt]> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.discoveryDebts,
            cachePolicy: .networkOnly
        )
        
        guard response.success, let debts = response.data else {
            throw PlaidError.debtDiscoveryFailed
        }
        
        return debts
    }
    
    func analyzeTransactionsForDebts(_ transactions: [PlaidTransaction]) async throws -> [DiscoveredDebt] {
        let response: APIResponse<[DiscoveredDebt]> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.discoveryAnalyze,
            method: .POST,
            body: ["transactions": transactions.map { $0.toDictionary() }],
            cachePolicy: .networkOnly
        )
        
        guard response.success, let debts = response.data else {
            throw PlaidError.debtAnalysisFailed
        }
        
        return debts
    }
    
    // MARK: - Institution Management
    
    func getInstitutions() async throws -> [PlaidInstitution] {
        let response: APIResponse<[PlaidInstitution]> = try await networkManager.request(
            endpoint: "/plaid/institutions",
            cachePolicy: .cacheFirst
        )
        
        guard response.success, let institutions = response.data else {
            throw PlaidError.institutionsFetchFailed
        }
        
        return institutions
    }
    
    func searchInstitutions(_ query: String) async throws -> [PlaidInstitution] {
        let response: APIResponse<[PlaidInstitution]> = try await networkManager.request(
            endpoint: "/plaid/institutions/search",
            parameters: ["query": query],
            cachePolicy: .networkOnly
        )
        
        guard response.success, let institutions = response.data else {
            throw PlaidError.institutionSearchFailed
        }
        
        return institutions
    }
    
    // MARK: - Webhook Handling
    
    func handleWebhook(_ webhookData: [String: Any]) async throws {
        guard let webhookType = webhookData["webhook_type"] as? String else {
            throw PlaidError.invalidWebhookData
        }
        
        switch webhookType {
        case "TRANSACTIONS":
            try await handleTransactionsWebhook(webhookData)
        case "ACCOUNTS":
            try await handleAccountsWebhook(webhookData)
        case "ITEM":
            try await handleItemWebhook(webhookData)
        default:
            print("Unknown webhook type: \(webhookType)")
        }
    }
    
    private func handleTransactionsWebhook(_ data: [String: Any]) async throws {
        // Handle transaction updates
        if let newTransactions = data["new_transactions"] as? Int, newTransactions > 0 {
            // Sync new transactions
            try await syncTransactions()
            
            // Analyze for new debts
            let transactions = try await getRecentTransactions()
            let newDebts = try await analyzeTransactionsForDebts(transactions)
            
            if !newDebts.isEmpty {
                // Notify user of discovered debts
                NotificationCenter.default.post(name: .newDebtsDiscovered, object: newDebts)
            }
        }
    }
    
    private func handleAccountsWebhook(_ data: [String: Any]) async throws {
        // Handle account updates
        if let accountIds = data["account_ids"] as? [String] {
            // Refresh account balances
            for accountId in accountIds {
                _ = try await getAccountBalance(accountId)
            }
        }
    }
    
    private func handleItemWebhook(_ data: [String: Any]) async throws {
        // Handle item-level updates
        if let error = data["error"] as? [String: Any] {
            // Handle Plaid errors
            print("Plaid error: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    private func getRecentTransactions() async throws -> [PlaidTransaction] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let accounts = try await getAccounts()
        var allTransactions: [PlaidTransaction] = []
        
        for account in accounts {
            let transactions = try await getTransactions(
                accountId: account.id,
                startDate: startDate,
                endDate: endDate
            )
            allTransactions.append(contentsOf: transactions)
        }
        
        return allTransactions
    }
    
    func disconnectAccount() async throws {
        let response: APIResponse<Never> = try await networkManager.request(
            endpoint: APIConstants.Endpoints.plaidDisconnect,
            method: .POST,
            cachePolicy: .networkOnly
        )
        
        guard response.success else {
            throw PlaidError.disconnectFailed
        }
        
        // Clear local Plaid data
        keychainService.deletePlaidToken()
    }
    
    func isConnected() -> Bool {
        return keychainService.getPlaidToken() != nil
    }
}

// MARK: - Supporting Types

struct PlaidLinkToken: Codable {
    let token: String
    let expiration: Date
}

struct PlaidAccount: Codable {
    let id: String
    let name: String
    let mask: String
    let type: AccountType
    let subtype: AccountSubtype
    let institution: PlaidInstitution
    let balances: PlaidAccountBalance
    
    enum AccountType: String, Codable {
        case depository = "depository"
        case credit = "credit"
        case loan = "loan"
        case investment = "investment"
        case other = "other"
    }
    
    enum AccountSubtype: String, Codable {
        case checking = "checking"
        case savings = "savings"
        case creditCard = "credit card"
        case personalLoan = "personal loan"
        case mortgage = "mortgage"
        case studentLoan = "student loan"
        case autoLoan = "auto loan"
        case other = "other"
    }
}

struct PlaidAccountBalance: Codable {
    let available: Double?
    let current: Double
    let limit: Double?
    let isoCurrencyCode: String
    let unofficialCurrencyCode: String?
}

struct PlaidTransaction: Codable {
    let id: String
    let accountId: String
    let amount: Double
    let date: Date
    let name: String
    let merchantName: String?
    let category: [String]
    let categoryId: String?
    let pending: Bool
    let paymentChannel: PaymentChannel
    let transactionType: TransactionType
    
    enum PaymentChannel: String, Codable {
        case online = "online"
        case inPerson = "in person"
        case phone = "phone"
        case paperCheck = "paper check"
        case bankTransfer = "bank transfer"
        case other = "other"
    }
    
    enum TransactionType: String, Codable {
        case special = "special"
        case place = "place"
        case digital = "digital"
        case unresolved = "unresolved"
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "account_id": accountId,
            "amount": amount,
            "date": ISO8601DateFormatter().string(from: date),
            "name": name,
            "merchant_name": merchantName ?? "",
            "category": category,
            "category_id": categoryId ?? "",
            "pending": pending,
            "payment_channel": paymentChannel.rawValue,
            "transaction_type": transactionType.rawValue
        ]
    }
}

struct PlaidInstitution: Codable {
    let id: String
    let name: String
    let logo: String?
    let primaryColor: String?
    let url: String?
    let products: [String]
}

enum PlaidError: Error, LocalizedError {
    case linkTokenCreationFailed
    case tokenExchangeFailed
    case accountsFetchFailed
    case balanceFetchFailed
    case transactionsFetchFailed
    case syncFailed
    case debtDiscoveryFailed
    case debtAnalysisFailed
    case institutionsFetchFailed
    case institutionSearchFailed
    case disconnectFailed
    case invalidWebhookData
    
    var errorDescription: String? {
        switch self {
        case .linkTokenCreationFailed:
            return "Failed to create Plaid link token. Please try again."
        case .tokenExchangeFailed:
            return "Failed to complete bank connection. Please try again."
        case .accountsFetchFailed:
            return "Failed to fetch bank accounts. Please try again."
        case .balanceFetchFailed:
            return "Failed to fetch account balance. Please try again."
        case .transactionsFetchFailed:
            return "Failed to fetch transactions. Please try again."
        case .syncFailed:
            return "Failed to sync with bank. Please try again."
        case .debtDiscoveryFailed:
            return "Failed to discover debts. Please try again."
        case .debtAnalysisFailed:
            return "Failed to analyze transactions for debts. Please try again."
        case .institutionsFetchFailed:
            return "Failed to fetch financial institutions. Please try again."
        case .institutionSearchFailed:
            return "Failed to search institutions. Please try again."
        case .disconnectFailed:
            return "Failed to disconnect bank account. Please try again."
        case .invalidWebhookData:
            return "Invalid webhook data received."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newDebtsDiscovered = Notification.Name("newDebtsDiscovered")
    static let plaidConnectionSuccess = Notification.Name("plaidConnectionSuccess")
    static let plaidConnectionFailed = Notification.Name("plaidConnectionFailed")
}
