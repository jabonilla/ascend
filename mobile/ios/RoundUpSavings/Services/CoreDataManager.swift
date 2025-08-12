import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Ascend")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Save Context
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - User Operations
    
    func saveUser(_ user: User) {
        let fetchRequest: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", user.id)
        
        do {
            let existingUsers = try context.fetch(fetchRequest)
            let cdUser: CDUser
            
            if let existingUser = existingUsers.first {
                cdUser = existingUser
            } else {
                cdUser = CDUser(context: context)
                cdUser.id = user.id
            }
            
            cdUser.email = user.email
            cdUser.firstName = user.firstName
            cdUser.lastName = user.lastName
            cdUser.phone = user.phone
            cdUser.createdAt = user.createdAt
            cdUser.updatedAt = user.updatedAt
            
            saveContext()
        } catch {
            print("Error saving user: \(error)")
        }
    }
    
    func getUser() -> User? {
        let fetchRequest: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let cdUsers = try context.fetch(fetchRequest)
            guard let cdUser = cdUsers.first else { return nil }
            
            return User(
                id: cdUser.id ?? "",
                email: cdUser.email ?? "",
                firstName: cdUser.firstName ?? "",
                lastName: cdUser.lastName ?? "",
                phone: cdUser.phone,
                createdAt: cdUser.createdAt ?? Date(),
                updatedAt: cdUser.updatedAt ?? Date()
            )
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
    func deleteUser() {
        let fetchRequest: NSFetchRequest<CDUser> = CDUser.fetchRequest()
        
        do {
            let cdUsers = try context.fetch(fetchRequest)
            for cdUser in cdUsers {
                context.delete(cdUser)
            }
            saveContext()
        } catch {
            print("Error deleting user: \(error)")
        }
    }
    
    // MARK: - Debt Operations
    
    func saveDebts(_ debts: [Debt]) {
        for debt in debts {
            saveDebt(debt)
        }
    }
    
    func saveDebt(_ debt: Debt) {
        let fetchRequest: NSFetchRequest<CDDebt> = CDDebt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", debt.id)
        
        do {
            let existingDebts = try context.fetch(fetchRequest)
            let cdDebt: CDDebt
            
            if let existingDebt = existingDebts.first {
                cdDebt = existingDebt
            } else {
                cdDebt = CDDebt(context: context)
                cdDebt.id = debt.id
            }
            
            cdDebt.userId = debt.userId
            cdDebt.name = debt.name
            cdDebt.type = debt.type.rawValue
            cdDebt.currentBalance = debt.currentBalance
            cdDebt.originalBalance = debt.originalBalance
            cdDebt.apr = debt.apr
            cdDebt.minimumPayment = debt.minimumPayment
            cdDebt.dueDate = debt.dueDate
            cdDebt.accountNumber = debt.accountNumber
            cdDebt.institution = debt.institution
            cdDebt.createdAt = debt.createdAt
            cdDebt.updatedAt = debt.updatedAt
            
            saveContext()
        } catch {
            print("Error saving debt: \(error)")
        }
    }
    
    func getDebts() -> [Debt] {
        let fetchRequest: NSFetchRequest<CDDebt> = CDDebt.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cdDebts = try context.fetch(fetchRequest)
            return cdDebts.compactMap { cdDebt in
                guard let id = cdDebt.id,
                      let name = cdDebt.name,
                      let typeString = cdDebt.type,
                      let type = DebtType(rawValue: typeString) else { return nil }
                
                return Debt(
                    id: id,
                    userId: cdDebt.userId ?? "",
                    name: name,
                    type: type,
                    currentBalance: cdDebt.currentBalance,
                    originalBalance: cdDebt.originalBalance,
                    apr: cdDebt.apr,
                    minimumPayment: cdDebt.minimumPayment,
                    dueDate: cdDebt.dueDate ?? Date(),
                    accountNumber: cdDebt.accountNumber,
                    institution: cdDebt.institution,
                    createdAt: cdDebt.createdAt ?? Date(),
                    updatedAt: cdDebt.updatedAt ?? Date()
                )
            }
        } catch {
            print("Error fetching debts: \(error)")
            return []
        }
    }
    
    func deleteDebt(_ debtId: String) {
        let fetchRequest: NSFetchRequest<CDDebt> = CDDebt.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", debtId)
        
        do {
            let cdDebts = try context.fetch(fetchRequest)
            for cdDebt in cdDebts {
                context.delete(cdDebt)
            }
            saveContext()
        } catch {
            print("Error deleting debt: \(error)")
        }
    }
    
    // MARK: - Payment Operations
    
    func savePayments(_ payments: [Payment]) {
        for payment in payments {
            savePayment(payment)
        }
    }
    
    func savePayment(_ payment: Payment) {
        let fetchRequest: NSFetchRequest<CDPayment> = CDPayment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", payment.id)
        
        do {
            let existingPayments = try context.fetch(fetchRequest)
            let cdPayment: CDPayment
            
            if let existingPayment = existingPayments.first {
                cdPayment = existingPayment
            } else {
                cdPayment = CDPayment(context: context)
                cdPayment.id = payment.id
            }
            
            cdPayment.userId = payment.userId
            cdPayment.debtId = payment.debtId
            cdPayment.amount = payment.amount
            cdPayment.scheduledDate = payment.scheduledDate
            cdPayment.executedDate = payment.executedDate
            cdPayment.status = payment.status.rawValue
            cdPayment.frequency = payment.frequency.rawValue
            cdPayment.isAutomated = payment.isAutomated
            cdPayment.paymentMethod = payment.paymentMethod
            cdPayment.confirmationNumber = payment.confirmationNumber
            cdPayment.createdAt = payment.createdAt
            cdPayment.updatedAt = payment.updatedAt
            
            saveContext()
        } catch {
            print("Error saving payment: \(error)")
        }
    }
    
    func getPayments() -> [Payment] {
        let fetchRequest: NSFetchRequest<CDPayment> = CDPayment.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: false)]
        
        do {
            let cdPayments = try context.fetch(fetchRequest)
            return cdPayments.compactMap { cdPayment in
                guard let id = cdPayment.id,
                      let statusString = cdPayment.status,
                      let status = Payment.PaymentStatus(rawValue: statusString),
                      let frequencyString = cdPayment.frequency,
                      let frequency = Payment.PaymentFrequency(rawValue: frequencyString),
                      let paymentMethod = cdPayment.paymentMethod else { return nil }
                
                return Payment(
                    id: id,
                    userId: cdPayment.userId ?? "",
                    debtId: cdPayment.debtId ?? "",
                    amount: cdPayment.amount,
                    scheduledDate: cdPayment.scheduledDate ?? Date(),
                    executedDate: cdPayment.executedDate,
                    status: status,
                    frequency: frequency,
                    isAutomated: cdPayment.isAutomated,
                    paymentMethod: paymentMethod,
                    confirmationNumber: cdPayment.confirmationNumber,
                    createdAt: cdPayment.createdAt ?? Date(),
                    updatedAt: cdPayment.updatedAt ?? Date()
                )
            }
        } catch {
            print("Error fetching payments: \(error)")
            return []
        }
    }
    
    func deletePayment(_ paymentId: String) {
        let fetchRequest: NSFetchRequest<CDPayment> = CDPayment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", paymentId)
        
        do {
            let cdPayments = try context.fetch(fetchRequest)
            for cdPayment in cdPayments {
                context.delete(cdPayment)
            }
            saveContext()
        } catch {
            print("Error deleting payment: \(error)")
        }
    }
    
    // MARK: - Scenario Operations
    
    func saveScenarios(_ scenarios: [SavedScenario]) {
        for scenario in scenarios {
            saveScenario(scenario)
        }
    }
    
    func saveScenario(_ scenario: SavedScenario) {
        let fetchRequest: NSFetchRequest<CDSavedScenario> = CDSavedScenario.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", scenario.id)
        
        do {
            let existingScenarios = try context.fetch(fetchRequest)
            let cdScenario: CDSavedScenario
            
            if let existingScenario = existingScenarios.first {
                cdScenario = existingScenario
            } else {
                cdScenario = CDSavedScenario(context: context)
                cdScenario.id = scenario.id
            }
            
            cdScenario.name = scenario.name
            cdScenario.description = scenario.description
            cdScenario.scenario = scenario.scenario.rawValue
            cdScenario.extraPayment = scenario.extraPayment
            cdScenario.monthlyPayment = scenario.calculation.monthlyPayment
            cdScenario.totalInterest = scenario.calculation.totalInterest
            cdScenario.totalPayoffTime = Int32(scenario.calculation.totalPayoffTime)
            cdScenario.createdAt = scenario.createdAt
            cdScenario.updatedAt = scenario.updatedAt
            
            saveContext()
        } catch {
            print("Error saving scenario: \(error)")
        }
    }
    
    func getScenarios() -> [SavedScenario] {
        let fetchRequest: NSFetchRequest<CDSavedScenario> = CDSavedScenario.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cdScenarios = try context.fetch(fetchRequest)
            return cdScenarios.compactMap { cdScenario in
                guard let id = cdScenario.id,
                      let name = cdScenario.name,
                      let description = cdScenario.description,
                      let scenarioString = cdScenario.scenario,
                      let scenario = PayoffScenario(rawValue: scenarioString) else { return nil }
                
                let calculation = PayoffCalculation(
                    totalPayoffTime: Int(cdScenario.totalPayoffTime),
                    totalInterest: cdScenario.totalInterest,
                    monthlyPayment: cdScenario.monthlyPayment,
                    monthlyBreakdown: [],
                    debtPayoffOrder: [],
                    savings: nil
                )
                
                return SavedScenario(
                    id: id,
                    name: name,
                    description: description,
                    scenario: scenario,
                    extraPayment: cdScenario.extraPayment,
                    calculation: calculation,
                    debts: [],
                    createdAt: cdScenario.createdAt ?? Date(),
                    updatedAt: cdScenario.updatedAt ?? Date()
                )
            }
        } catch {
            print("Error fetching scenarios: \(error)")
            return []
        }
    }
    
    func deleteScenario(_ scenarioId: String) {
        let fetchRequest: NSFetchRequest<CDSavedScenario> = CDSavedScenario.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", scenarioId)
        
        do {
            let cdScenarios = try context.fetch(fetchRequest)
            for cdScenario in cdScenarios {
                context.delete(cdScenario)
            }
            saveContext()
        } catch {
            print("Error deleting scenario: \(error)")
        }
    }
    
    // MARK: - Optimization Strategy Operations
    
    func saveOptimizationStrategy(_ strategy: OptimizationStrategy) {
        let fetchRequest: NSFetchRequest<CDOptimizationStrategy> = CDOptimizationStrategy.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", strategy.id)
        
        do {
            let existingStrategies = try context.fetch(fetchRequest)
            let cdStrategy: CDOptimizationStrategy
            
            if let existingStrategy = existingStrategies.first {
                cdStrategy = existingStrategy
            } else {
                cdStrategy = CDOptimizationStrategy(context: context)
                cdStrategy.id = strategy.id
            }
            
            cdStrategy.userId = strategy.userId
            cdStrategy.name = strategy.name
            cdStrategy.type = strategy.type.rawValue
            cdStrategy.monthlyPayment = strategy.monthlyPayment
            cdStrategy.projectedPayoffDate = strategy.projectedPayoffDate
            cdStrategy.totalInterestSaved = strategy.totalInterestSaved
            cdStrategy.monthsSaved = Int32(strategy.monthsSaved)
            cdStrategy.debtPaymentOrder = strategy.debtPaymentOrder
            cdStrategy.isActive = strategy.isActive
            cdStrategy.createdAt = Date()
            cdStrategy.updatedAt = Date()
            
            saveContext()
        } catch {
            print("Error saving optimization strategy: \(error)")
        }
    }
    
    func getOptimizationStrategies() -> [OptimizationStrategy] {
        let fetchRequest: NSFetchRequest<CDOptimizationStrategy> = CDOptimizationStrategy.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cdStrategies = try context.fetch(fetchRequest)
            return cdStrategies.compactMap { cdStrategy in
                guard let id = cdStrategy.id,
                      let userId = cdStrategy.userId,
                      let name = cdStrategy.name,
                      let typeString = cdStrategy.type,
                      let type = OptimizationStrategy.StrategyType(rawValue: typeString),
                      let debtPaymentOrder = cdStrategy.debtPaymentOrder as? [String] else { return nil }
                
                return OptimizationStrategy(
                    id: id,
                    userId: userId,
                    name: name,
                    type: type,
                    monthlyPayment: cdStrategy.monthlyPayment,
                    projectedPayoffDate: cdStrategy.projectedPayoffDate ?? Date(),
                    totalInterestSaved: cdStrategy.totalInterestSaved,
                    monthsSaved: Int(cdStrategy.monthsSaved),
                    debtPaymentOrder: debtPaymentOrder,
                    isActive: cdStrategy.isActive
                )
            }
        } catch {
            print("Error fetching optimization strategies: \(error)")
            return []
        }
    }
    
    // MARK: - Insight Operations
    
    func saveInsights(_ insights: [Insight]) {
        // Clear existing insights
        deleteAllInsights()
        
        for insight in insights {
            saveInsight(insight)
        }
    }
    
    func saveInsight(_ insight: Insight) {
        let cdInsight = CDInsight(context: context)
        cdInsight.id = insight.id
        cdInsight.type = insight.type.rawValue
        cdInsight.title = insight.title
        cdInsight.message = insight.message
        cdInsight.action = insight.action
        cdInsight.priority = insight.priority.rawValue
        cdInsight.createdAt = insight.createdAt
        
        saveContext()
    }
    
    func getInsights() -> [Insight] {
        let fetchRequest: NSFetchRequest<CDInsight> = CDInsight.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cdInsights = try context.fetch(fetchRequest)
            return cdInsights.compactMap { cdInsight in
                guard let id = cdInsight.id,
                      let typeString = cdInsight.type,
                      let type = Insight.InsightType(rawValue: typeString),
                      let title = cdInsight.title,
                      let message = cdInsight.message,
                      let priorityString = cdInsight.priority,
                      let priority = Insight.InsightPriority(rawValue: priorityString),
                      let createdAt = cdInsight.createdAt else { return nil }
                
                return Insight(
                    id: id,
                    type: type,
                    title: title,
                    message: message,
                    action: cdInsight.action,
                    priority: priority,
                    createdAt: createdAt
                )
            }
        } catch {
            print("Error fetching insights: \(error)")
            return []
        }
    }
    
    func deleteAllInsights() {
        let fetchRequest: NSFetchRequest<CDInsight> = CDInsight.fetchRequest()
        
        do {
            let cdInsights = try context.fetch(fetchRequest)
            for cdInsight in cdInsights {
                context.delete(cdInsight)
            }
            saveContext()
        } catch {
            print("Error deleting insights: \(error)")
        }
    }
    
    // MARK: - Notification Operations
    
    func saveNotification(_ notification: LocalNotification) {
        let cdNotification = CDNotification(context: context)
        cdNotification.id = notification.id
        cdNotification.title = notification.title
        cdNotification.body = notification.body
        cdNotification.type = notification.type.rawValue
        cdNotification.isRead = false
        cdNotification.createdAt = Date()
        
        saveContext()
    }
    
    func getNotifications() -> [LocalNotification] {
        let fetchRequest: NSFetchRequest<CDNotification> = CDNotification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let cdNotifications = try context.fetch(fetchRequest)
            return cdNotifications.compactMap { cdNotification in
                guard let id = cdNotification.id,
                      let title = cdNotification.title,
                      let body = cdNotification.body,
                      let typeString = cdNotification.type,
                      let type = LocalNotification.NotificationType(rawValue: typeString) else { return nil }
                
                return LocalNotification(
                    id: id,
                    title: title,
                    body: body,
                    type: type,
                    isRead: cdNotification.isRead,
                    createdAt: cdNotification.createdAt ?? Date()
                )
            }
        } catch {
            print("Error fetching notifications: \(error)")
            return []
        }
    }
    
    func markNotificationAsRead(_ notificationId: String) {
        let fetchRequest: NSFetchRequest<CDNotification> = CDNotification.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", notificationId)
        
        do {
            let cdNotifications = try context.fetch(fetchRequest)
            if let cdNotification = cdNotifications.first {
                cdNotification.isRead = true
                saveContext()
            }
        } catch {
            print("Error marking notification as read: \(error)")
        }
    }
    
    // MARK: - Data Synchronization
    
    func syncData() {
        // This method will be called when the app comes back online
        // to sync local changes with the server
        print("Data synchronization started")
        
        // TODO: Implement sync logic with NetworkManager
        // 1. Get local changes
        // 2. Send to server
        // 3. Get server changes
        // 4. Update local data
    }
    
    func clearAllData() {
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity.name!)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                print("Error clearing \(entity.name ?? "unknown") data: \(error)")
            }
        }
        
        saveContext()
    }
}

// MARK: - Supporting Types

struct LocalNotification {
    let id: String
    let title: String
    let body: String
    let type: NotificationType
    let isRead: Bool
    let createdAt: Date
    
    enum NotificationType: String, CaseIterable {
        case payment = "payment"
        case milestone = "milestone"
        case achievement = "achievement"
        case reminder = "reminder"
        case system = "system"
    }
}
