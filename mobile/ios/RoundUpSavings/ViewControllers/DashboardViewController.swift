import UIKit

class DashboardViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let welcomeLabel = UILabel()
    private let totalDebtLabel = UILabel()
    private let progressRingView = ProgressRingView()
    
    private let insightsCard = InsightsCardView()
    private let quickActionsCard = QuickActionsCardView()
    private let recentPaymentsCard = RecentPaymentsCardView()
    private let optimizationCard = OptimizationCardView()
    
    // MARK: - Data
    private var debts: [Debt] = []
    private var payments: [Payment] = []
    private var progressMetrics: ProgressMetrics?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        AnalyticsService.shared.trackScreenView("Dashboard")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Setup header
        setupHeaderView()
        
        // Setup cards
        setupInsightsCard()
        setupQuickActionsCard()
        setupRecentPaymentsCard()
        setupOptimizationCard()
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(insightsCard)
        contentView.addSubview(quickActionsCard)
        contentView.addSubview(recentPaymentsCard)
        contentView.addSubview(optimizationCard)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        // Welcome label
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        welcomeLabel.text = "Welcome back!"
        welcomeLabel.textColor = .white
        welcomeLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        
        // Total debt label
        totalDebtLabel.translatesAutoresizingMaskIntoConstraints = false
        totalDebtLabel.text = "$0"
        totalDebtLabel.textColor = .white
        totalDebtLabel.font = UIFont(name: "Satoshi-Bold", size: 32) ?? UIFont.boldSystemFont(ofSize: 32)
        
        // Progress ring
        progressRingView.translatesAutoresizingMaskIntoConstraints = false
        progressRingView.progress = 0.0
        progressRingView.ringColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        headerView.addSubview(welcomeLabel)
        headerView.addSubview(totalDebtLabel)
        headerView.addSubview(progressRingView)
    }
    
    private func setupInsightsCard() {
        insightsCard.translatesAutoresizingMaskIntoConstraints = false
        insightsCard.delegate = self
    }
    
    private func setupQuickActionsCard() {
        quickActionsCard.translatesAutoresizingMaskIntoConstraints = false
        quickActionsCard.delegate = self
    }
    
    private func setupRecentPaymentsCard() {
        recentPaymentsCard.translatesAutoresizingMaskIntoConstraints = false
        recentPaymentsCard.delegate = self
    }
    
    private func setupOptimizationCard() {
        optimizationCard.translatesAutoresizingMaskIntoConstraints = false
        optimizationCard.delegate = self
    }
    
    private func setupNavigationBar() {
        title = "Dashboard"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header view
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 200),
            
            // Welcome label
            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            // Total debt label
            totalDebtLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 8),
            totalDebtLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            // Progress ring
            progressRingView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            progressRingView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            progressRingView.widthAnchor.constraint(equalToConstant: 120),
            progressRingView.heightAnchor.constraint(equalToConstant: 120),
            
            // Insights card
            insightsCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            insightsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            insightsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Quick actions card
            quickActionsCard.topAnchor.constraint(equalTo: insightsCard.bottomAnchor, constant: 16),
            quickActionsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickActionsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Recent payments card
            recentPaymentsCard.topAnchor.constraint(equalTo: quickActionsCard.bottomAnchor, constant: 16),
            recentPaymentsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recentPaymentsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Optimization card
            optimizationCard.topAnchor.constraint(equalTo: recentPaymentsCard.bottomAnchor, constant: 16),
            optimizationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            optimizationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            optimizationCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await loadDebts()
            await loadPayments()
            await loadProgressMetrics()
            await loadInsights()
        }
    }
    
    private func loadDebts() async {
        do {
            debts = try await FinancialDataService.shared.fetchDebts()
            updateUI()
        } catch {
            showError(error)
        }
    }
    
    private func loadPayments() async {
        do {
            payments = try await FinancialDataService.shared.fetchPayments()
            updateUI()
        } catch {
            showError(error)
        }
    }
    
    private func loadProgressMetrics() async {
        do {
            progressMetrics = try await FinancialDataService.shared.getProgressMetrics()
            updateUI()
        } catch {
            showError(error)
        }
    }
    
    private func loadInsights() async {
        // Load AI insights
        insightsCard.loadInsights()
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            self.updateHeader()
            self.recentPaymentsCard.configure(with: self.payments)
            self.optimizationCard.configure(with: self.debts)
        }
    }
    
    private func updateHeader() {
        let totalDebt = debts.reduce(0) { $0 + $1.currentBalance }
        totalDebtLabel.text = String(format: "$%.0f", totalDebt)
        
        if let metrics = progressMetrics {
            progressRingView.progress = metrics.progressPercentage / 100.0
        }
        
        // Update welcome message with user name
        if let user = AuthenticationService.shared.getCurrentUser() {
            welcomeLabel.text = "Welcome back, \(user.firstName)!"
        }
    }
    
    // MARK: - Actions
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    private func showError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Error",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - Card Delegates

extension DashboardViewController: InsightsCardViewDelegate {
    func insightsCardViewDidTapInsight(_ insight: Insight) {
        // Handle insight tap
        AnalyticsService.shared.trackUserAction("insight_tapped", properties: ["insight_id": insight.id])
    }
}

extension DashboardViewController: QuickActionsCardViewDelegate {
    func quickActionsCardViewDidTapAddDebt() {
        let addDebtVC = AddDebtViewController()
        let nav = UINavigationController(rootViewController: addDebtVC)
        present(nav, animated: true)
    }
    
    func quickActionsCardViewDidTapSchedulePayment() {
        let schedulePaymentVC = SchedulePaymentViewController()
        let nav = UINavigationController(rootViewController: schedulePaymentVC)
        present(nav, animated: true)
    }
    
    func quickActionsCardViewDidTapConnectBank() {
        let connectBankVC = ConnectBankViewController()
        let nav = UINavigationController(rootViewController: connectBankVC)
        present(nav, animated: true)
    }
}

extension DashboardViewController: RecentPaymentsCardViewDelegate {
    func recentPaymentsCardViewDidTapPayment(_ payment: Payment) {
        let paymentDetailVC = PaymentDetailViewController(payment: payment)
        navigationController?.pushViewController(paymentDetailVC, animated: true)
    }
    
    func recentPaymentsCardViewDidTapViewAll() {
        tabBarController?.selectedIndex = 2 // Payments tab
    }
}

extension DashboardViewController: OptimizationCardViewDelegate {
    func optimizationCardViewDidTapOptimize() {
        let optimizationVC = OptimizationViewController()
        navigationController?.pushViewController(optimizationVC, animated: true)
    }
    
    func optimizationCardViewDidTapViewStrategy() {
        let strategyVC = StrategyDetailViewController()
        navigationController?.pushViewController(strategyVC, animated: true)
    }
}
