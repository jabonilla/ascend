import Foundation

struct Payment: Codable, Identifiable {
    let id: String
    let userId: String
    let debtId: String
    let amount: Double
    let scheduledDate: Date
    let executedDate: Date?
    let status: PaymentStatus
    let frequency: PaymentFrequency
    let isAutomated: Bool
    let paymentMethod: String
    let confirmationNumber: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum PaymentStatus: String, Codable, CaseIterable {
        case scheduled = "scheduled"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        
        var displayName: String {
            switch self {
            case .scheduled: return "Scheduled"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
        
        var color: UIColor {
            switch self {
            case .scheduled: return UIColor.systemBlue
            case .processing: return UIColor.systemOrange
            case .completed: return UIColor.systemGreen
            case .failed: return UIColor.systemRed
            }
        }
    }
    
    enum PaymentFrequency: String, Codable, CaseIterable {
        case oneTime = "one_time"
        case monthly = "monthly"
        case weekly = "weekly"
        
        var displayName: String {
            switch self {
            case .oneTime: return "One Time"
            case .monthly: return "Monthly"
            case .weekly: return "Weekly"
            }
        }
    }
    
    var isCompleted: Bool {
        return status == .completed
    }
    
    var isPending: Bool {
        return status == .scheduled || status == .processing
    }
    
    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }
    
    var formattedScheduledDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: scheduledDate)
    }
}
