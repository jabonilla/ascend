import UIKit
import CoreData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // Configure window
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Initialize all services
        initializeServices()
        
        // Configure app appearance
        configureAppearance()
        
        // Check authentication status and set up initial view controller
        checkAuthenticationStatus()
        
        window?.makeKeyAndVisible()
        
        return true
    }
    
    private func initializeServices() {
        // Initialize Core Data
        _ = CoreDataManager.shared.persistentContainer
        
        // Initialize authentication service
        AuthenticationService.shared.initialize()
        
        // Initialize financial data service
        FinancialDataService.shared.initialize()
        
        // Initialize network manager
        _ = NetworkManager.shared
        
        // Initialize Plaid service
        PlaidService.shared.configure()
        
        // Initialize notification service
        Task {
            await initializeNotificationService()
        }
        
        // Initialize analytics service
        AnalyticsService.shared.initialize()
        
        // Initialize theme service
        ThemeService.shared.updateAppearance()
        
        // Set up notification categories
        NotificationService.shared.setupNotificationCategories()
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared
        
        // Observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
        
        // Observe new debts discovered
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(newDebtsDiscovered),
            name: .newDebtsDiscovered,
            object: nil
        )
    }
    
    private func initializeNotificationService() async {
        let granted = await NotificationService.shared.requestPermissions()
        if granted {
            print("Notification permissions granted")
        } else {
            print("Notification permissions denied")
        }
    }
    
    private func configureAppearance() {
        // Theme service will handle most appearance configuration
        // Additional custom configurations can be added here
        
        // Configure custom fonts if needed
        if let customFont = UIFont(name: "Satoshi-Bold", size: 18) {
            UINavigationBar.appearance().titleTextAttributes = [
                .font: customFont
            ]
        }
    }
    
    private func checkAuthenticationStatus() {
        // Check if user has completed onboarding
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if !hasCompletedOnboarding {
            // Show onboarding
            let onboardingVC = OnboardingViewController()
            onboardingVC.delegate = self
            window?.rootViewController = onboardingVC
        } else if AuthenticationService.shared.isAuthenticated {
            // User is authenticated, show main app
            let mainViewController = MainTabBarController()
            window?.rootViewController = mainViewController
            
            // Schedule smart notifications for authenticated user
            if let user = AuthenticationService.shared.getCurrentUser() {
                NotificationService.shared.scheduleSmartNotifications(for: user)
            }
        } else {
            // User needs to authenticate
            let authVC = AuthenticationViewController()
            authVC.delegate = self
            window?.rootViewController = authVC
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func themeDidChange(_ notification: Notification) {
        // Reconfigure appearance when theme changes
        configureAppearance()
        
        // Update all view controllers
        updateViewControllersForTheme()
    }
    
    @objc private func newDebtsDiscovered(_ notification: Notification) {
        if let newDebts = notification.object as? [DiscoveredDebt] {
            // Show notification to user about discovered debts
            let content = UNMutableNotificationContent()
            content.title = "New Debts Discovered"
            content.body = "We found \(newDebts.count) new debt(s) in your accounts"
            content.sound = .default
            content.categoryIdentifier = "DEBT_DISCOVERY"
            
            let request = UNNotificationRequest(
                identifier: "debt_discovery_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func updateViewControllersForTheme() {
        // Update all visible view controllers for theme changes
        if let rootViewController = window?.rootViewController {
            updateViewControllerForTheme(rootViewController)
        }
    }
    
    private func updateViewControllerForTheme(_ viewController: UIViewController) {
        // Update the current view controller
        viewController.view.applyTheme()
        
        // Update child view controllers
        for child in viewController.children {
            updateViewControllerForTheme(child)
        }
        
        // Update presented view controller
        if let presented = viewController.presentedViewController {
            updateViewControllerForTheme(presented)
        }
    }
    
    // MARK: - Core Data
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Save Core Data context when app terminates
        CoreDataManager.shared.saveContext()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save Core Data context when app enters background
        CoreDataManager.shared.saveContext()
    }
}

// MARK: - Onboarding Delegate

extension AppDelegate: OnboardingViewDelegate {
    func onboardingDidComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Show authentication screen
        let authVC = AuthenticationViewController()
        authVC.delegate = self
        window?.rootViewController = authVC
    }
    
    func onboardingDidSkip() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Show authentication screen
        let authVC = AuthenticationViewController()
        authVC.delegate = self
        window?.rootViewController = authVC
    }
}

// MARK: - Authentication Delegate

extension AppDelegate: AuthenticationViewControllerDelegate {
    func authenticationDidComplete() {
        // User successfully authenticated, show main app
        let mainViewController = MainTabBarController()
        
        // Animate transition
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.window?.rootViewController = mainViewController
        }, completion: nil)
        
        // Schedule smart notifications for the user
        if let user = AuthenticationService.shared.getCurrentUser() {
            NotificationService.shared.scheduleSmartNotifications(for: user)
        }
    }
    
    func authenticationDidFail() {
        // Handle authentication failure
        print("Authentication failed")
    }
}
