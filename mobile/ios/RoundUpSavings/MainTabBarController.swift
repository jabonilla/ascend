import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
        setupViewControllers()
    }
    
    private func setupTabBar() {
        tabBar.tintColor = UIColor(named: "PrimaryBlue")
        tabBar.unselectedItemTintColor = UIColor.systemGray
        tabBar.backgroundColor = UIColor.systemBackground
    }
    
    private func setupViewControllers() {
        let dashboardVC = DashboardViewController()
        let dashboardNav = UINavigationController(rootViewController: dashboardVC)
        dashboardNav.tabBarItem = UITabBarItem(
            title: "Dashboard",
            image: UIImage(systemName: "chart.line.uptrend.xyaxis"),
            selectedImage: UIImage(systemName: "chart.line.uptrend.xyaxis.fill")
        )
        
        let debtsVC = DebtsViewController()
        let debtsNav = UINavigationController(rootViewController: debtsVC)
        debtsNav.tabBarItem = UITabBarItem(
            title: "Debts",
            image: UIImage(systemName: "creditcard"),
            selectedImage: UIImage(systemName: "creditcard.fill")
        )
        
        let paymentsVC = PaymentsViewController()
        let paymentsNav = UINavigationController(rootViewController: paymentsVC)
        paymentsNav.tabBarItem = UITabBarItem(
            title: "Payments",
            image: UIImage(systemName: "dollarsign.circle"),
            selectedImage: UIImage(systemName: "dollarsign.circle.fill")
        )
        
        let communityVC = CommunityViewController()
        let communityNav = UINavigationController(rootViewController: communityVC)
        communityNav.tabBarItem = UITabBarItem(
            title: "Community",
            image: UIImage(systemName: "person.3"),
            selectedImage: UIImage(systemName: "person.3.fill")
        )
        
        let profileVC = ProfileViewController()
        let profileNav = UINavigationController(rootViewController: profileVC)
        profileNav.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person.circle"),
            selectedImage: UIImage(systemName: "person.circle.fill")
        )
        
        viewControllers = [dashboardNav, debtsNav, paymentsNav, communityNav, profileNav]
    }
}
