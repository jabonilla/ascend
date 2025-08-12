import Foundation

struct User: Codable {
    let id: String
    let email: String
    let phone: String?
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
    let createdAt: Date
    let updatedAt: Date
    let emailVerified: Bool
    let phoneVerified: Bool
    let subscriptionTier: SubscriptionTier
    let onboardingCompleted: Bool
    
    enum SubscriptionTier: String, Codable, CaseIterable {
        case free = "free"
        case premium = "premium"
        case premiumPlus = "premium_plus"
        
        var displayName: String {
            switch self {
            case .free: return "Free"
            case .premium: return "Premium"
            case .premiumPlus: return "Premium Plus"
            }
        }
        
        var monthlyPrice: Double {
            switch self {
            case .free: return 0.0
            case .premium: return 9.99
            case .premiumPlus: return 19.99
            }
        }
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    var isPremium: Bool {
        return subscriptionTier != .free
    }
}
