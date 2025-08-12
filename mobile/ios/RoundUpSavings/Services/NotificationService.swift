import Foundation
import UserNotifications
import CoreData

class NotificationService {
    static let shared = NotificationService()
    
    private let coreDataManager = CoreDataManager.shared
    private let center = UNUserNotificationCenter.current()
    
    private init() {}
    
    // MARK: - Permission Management
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    func checkPermissions() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Payment Reminders
    
    func schedulePaymentReminder(for payment: Payment) {
        let content = UNMutableNotificationContent()
        content.title = "Payment Due"
        content.body = "Your payment of \(payment.formattedAmount) for \(payment.debtId) is due today"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "PAYMENT_REMINDER"
        
        // Schedule for the day before
        let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: payment.scheduledDate) ?? payment.scheduledDate
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate), repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "payment_reminder_\(payment.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling payment reminder: \(error)")
            }
        }
    }
    
    func schedulePaymentConfirmation(for payment: Payment) {
        let content = UNMutableNotificationContent()
        content.title = "Payment Confirmed"
        content.body = "Your payment of \(payment.formattedAmount) has been processed successfully"
        content.sound = .default
        content.categoryIdentifier = "PAYMENT_CONFIRMATION"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "payment_confirmation_\(payment.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling payment confirmation: \(error)")
            }
        }
    }
    
    // MARK: - Milestone Notifications
    
    func scheduleMilestoneNotification(type: MilestoneType, amount: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Milestone Achieved! 🎉"
        
        switch type {
        case .debtPaidOff:
            content.body = "Congratulations! You've paid off a debt of \(formatCurrency(amount))"
        case .interestSaved:
            content.body = "You've saved \(formatCurrency(amount)) in interest payments!"
        case .payoffDate:
            content.body = "You're ahead of schedule! Your payoff date moved up by \(Int(amount)) months"
        case .paymentStreak:
            content.body = "Amazing! You've made \(Int(amount)) consecutive payments"
        }
        
        content.sound = .default
        content.categoryIdentifier = "MILESTONE"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "milestone_\(type.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling milestone notification: \(error)")
            }
        }
    }
    
    // MARK: - Achievement Notifications
    
    func scheduleAchievementNotification(achievement: Achievement) {
        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = "\(achievement.name): \(achievement.description)"
        content.sound = .default
        content.categoryIdentifier = "ACHIEVEMENT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "achievement_\(achievement.id)",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling achievement notification: \(error)")
            }
        }
    }
    
    // MARK: - Weekly Progress Reports
    
    func scheduleWeeklyProgressReport() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Progress Report"
        content.body = "Check out your debt payoff progress this week!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REPORT"
        
        // Schedule for every Sunday at 9 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "weekly_progress_report",
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling weekly progress report: \(error)")
            }
        }
    }
    
    // MARK: - Custom Reminders
    
    func scheduleCustomReminder(title: String, body: String, date: Date, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "CUSTOM_REMINDER"
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling custom reminder: \(error)")
            }
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let paymentReminderAction = UNNotificationAction(
            identifier: "VIEW_PAYMENT",
            title: "View Payment",
            options: [.foreground]
        )
        
        let paymentConfirmationAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )
        
        let milestoneAction = UNNotificationAction(
            identifier: "SHARE_MILESTONE",
            title: "Share",
            options: [.foreground]
        )
        
        let achievementAction = UNNotificationAction(
            identifier: "VIEW_ACHIEVEMENT",
            title: "View Achievement",
            options: [.foreground]
        )
        
        let weeklyReportAction = UNNotificationAction(
            identifier: "VIEW_REPORT",
            title: "View Report",
            options: [.foreground]
        )
        
        let paymentReminderCategory = UNNotificationCategory(
            identifier: "PAYMENT_REMINDER",
            actions: [paymentReminderAction],
            intentIdentifiers: [],
            options: []
        )
        
        let paymentConfirmationCategory = UNNotificationCategory(
            identifier: "PAYMENT_CONFIRMATION",
            actions: [paymentConfirmationAction],
            intentIdentifiers: [],
            options: []
        )
        
        let milestoneCategory = UNNotificationCategory(
            identifier: "MILESTONE",
            actions: [milestoneAction],
            intentIdentifiers: [],
            options: []
        )
        
        let achievementCategory = UNNotificationCategory(
            identifier: "ACHIEVEMENT",
            actions: [achievementAction],
            intentIdentifiers: [],
            options: []
        )
        
        let weeklyReportCategory = UNNotificationCategory(
            identifier: "WEEKLY_REPORT",
            actions: [weeklyReportAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            paymentReminderCategory,
            paymentConfirmationCategory,
            milestoneCategory,
            achievementCategory,
            weeklyReportCategory
        ])
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return await center.deliveredNotifications()
    }
    
    func clearDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
    
    // MARK: - Local Notification Storage
    
    func saveLocalNotification(_ notification: LocalNotification) {
        coreDataManager.saveNotification(notification)
    }
    
    func getLocalNotifications() -> [LocalNotification] {
        return coreDataManager.getNotifications()
    }
    
    func markNotificationAsRead(_ notificationId: String) {
        coreDataManager.markNotificationAsRead(notificationId)
    }
    
    func getUnreadNotificationCount() -> Int {
        let notifications = getLocalNotifications()
        return notifications.filter { !$0.isRead }.count
    }
    
    // MARK: - Smart Notifications
    
    func scheduleSmartNotifications(for user: User) {
        // Schedule based on user behavior and preferences
        scheduleWeeklyProgressReport()
        
        // Schedule payment reminders for upcoming payments
        let payments = coreDataManager.getPayments()
        let upcomingPayments = payments.filter { $0.scheduledDate > Date() && $0.status == .scheduled }
        
        for payment in upcomingPayments {
            schedulePaymentReminder(for: payment)
        }
    }
    
    // MARK: - Notification Analytics
    
    func trackNotificationOpen(_ notificationId: String, type: String) {
        // Track notification engagement for analytics
        AnalyticsService.shared.trackEvent("notification_opened", properties: [
            "notification_id": notificationId,
            "notification_type": type
        ])
    }
    
    // MARK: - Utility Methods
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Supporting Types

enum MilestoneType: String, CaseIterable {
    case debtPaidOff = "debt_paid_off"
    case interestSaved = "interest_saved"
    case payoffDate = "payoff_date"
    case paymentStreak = "payment_streak"
}

// MARK: - Notification Extensions

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let category = response.notification.request.content.categoryIdentifier
        
        // Handle notification actions
        switch response.actionIdentifier {
        case "VIEW_PAYMENT":
            handlePaymentReminderAction(identifier: identifier)
        case "VIEW_DETAILS":
            handlePaymentConfirmationAction(identifier: identifier)
        case "SHARE_MILESTONE":
            handleMilestoneAction(identifier: identifier)
        case "VIEW_ACHIEVEMENT":
            handleAchievementAction(identifier: identifier)
        case "VIEW_REPORT":
            handleWeeklyReportAction(identifier: identifier)
        default:
            handleDefaultNotificationAction(identifier: identifier, category: category)
        }
        
        completionHandler()
    }
    
    private func handlePaymentReminderAction(identifier: String) {
        // Navigate to payment details
        NotificationCenter.default.post(name: .showPaymentDetails, object: identifier)
    }
    
    private func handlePaymentConfirmationAction(identifier: String) {
        // Navigate to payment confirmation
        NotificationCenter.default.post(name: .showPaymentConfirmation, object: identifier)
    }
    
    private func handleMilestoneAction(identifier: String) {
        // Show share sheet for milestone
        NotificationCenter.default.post(name: .shareMilestone, object: identifier)
    }
    
    private func handleAchievementAction(identifier: String) {
        // Navigate to achievement details
        NotificationCenter.default.post(name: .showAchievementDetails, object: identifier)
    }
    
    private func handleWeeklyReportAction(identifier: String) {
        // Navigate to weekly report
        NotificationCenter.default.post(name: .showWeeklyReport, object: identifier)
    }
    
    private func handleDefaultNotificationAction(identifier: String, category: String) {
        // Handle default notification tap
        trackNotificationOpen(identifier, type: category)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showPaymentDetails = Notification.Name("showPaymentDetails")
    static let showPaymentConfirmation = Notification.Name("showPaymentConfirmation")
    static let shareMilestone = Notification.Name("shareMilestone")
    static let showAchievementDetails = Notification.Name("showAchievementDetails")
    static let showWeeklyReport = Notification.Name("showWeeklyReport")
}
