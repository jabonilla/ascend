import Foundation

struct Debt: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let type: DebtType
    let currentBalance: Double
    let originalBalance: Double
    let apr: Double
    let minimumPayment: Double
    let dueDate: Int // Day of month
    let accountNumber: String? // Last 4 digits only
    let plaidAccountId: String?
    let isAutoSynced: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum DebtType: String, Codable, CaseIterable {
        case creditCard = "credit_card"
        case studentLoan = "student_loan"
        case personalLoan = "personal_loan"
        case autoLoan = "auto_loan"
        case mortgage = "mortgage"
        case bnpl = "bnpl"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .creditCard: return "Credit Card"
            case .studentLoan: return "Student Loan"
            case .personalLoan: return "Personal Loan"
            case .autoLoan: return "Auto Loan"
            case .mortgage: return "Mortgage"
            case .bnpl: return "Buy Now, Pay Later"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .creditCard: return "creditcard"
            case .studentLoan: return "graduationcap"
            case .personalLoan: return "person.crop.circle"
            case .autoLoan: return "car"
            case .mortgage: return "house"
            case .bnpl: return "cart"
            case .other: return "questionmark.circle"
            }
        }
    }
    
    var progressPercentage: Double {
        guard originalBalance > 0 else { return 0 }
        return ((originalBalance - currentBalance) / originalBalance) * 100
    }
    
    var remainingBalance: Double {
        return originalBalance - currentBalance
    }
    
    var monthlyInterest: Double {
        return currentBalance * (apr / 100) / 12
    }
    
    var isHighInterest: Bool {
        return apr > 15.0
    }
    
    var isLowBalance: Bool {
        return currentBalance < 1000
    }
}
