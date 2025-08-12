import UIKit

class OptimizationViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let strategyCard = StrategyComparisonCard()
    private let projectionsCard = ProjectionsCard()
    private let recommendationsCard = RecommendationsCard()
    
    private let optimizeButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var debts: [Debt] = []
    private var optimizationStrategy: OptimizationStrategy?
    private var projections: [MonthlyProjection] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        AnalyticsService.shared.trackScreenView("Optimization")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header
        setupHeaderView()
        
        // Cards
        setupStrategyCard()
        setupProjectionsCard()
        setupRecommendationsCard()
        
        // Optimize button
        optimizeButton.translatesAutoresizingMaskIntoConstraints = false
        optimizeButton.setTitle("Generate Optimization", for: .normal)
        optimizeButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        optimizeButton.setTitleColor(.white, for: .normal)
        optimizeButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        optimizeButton.layer.cornerRadius = 12
        optimizeButton.addTarget(self, action: #selector(optimizeTapped), for: .touchUpInside)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(strategyCard)
        contentView.addSubview(projectionsCard)
        contentView.addSubview(recommendationsCard)
        contentView.addSubview(optimizeButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "AI Optimization"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Get the most efficient debt payoff strategy"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupStrategyCard() {
        strategyCard.translatesAutoresizingMaskIntoConstraints = false
        strategyCard.delegate = self
    }
    
    private func setupProjectionsCard() {
        projectionsCard.translatesAutoresizingMaskIntoConstraints = false
        projectionsCard.delegate = self
    }
    
    private func setupRecommendationsCard() {
        recommendationsCard.translatesAutoresizingMaskIntoConstraints = false
        recommendationsCard.delegate = self
    }
    
    private func setupNavigationBar() {
        title = "Optimization"
        navigationController?.navigationBar.prefersLargeTitles = false
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
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // Strategy card
            strategyCard.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            strategyCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            strategyCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Projections card
            projectionsCard.topAnchor.constraint(equalTo: strategyCard.bottomAnchor, constant: 16),
            projectionsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            projectionsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Recommendations card
            recommendationsCard.topAnchor.constraint(equalTo: projectionsCard.bottomAnchor, constant: 16),
            recommendationsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            recommendationsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Optimize button
            optimizeButton.topAnchor.constraint(equalTo: recommendationsCard.bottomAnchor, constant: 24),
            optimizeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            optimizeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            optimizeButton.heightAnchor.constraint(equalToConstant: 50),
            optimizeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await loadDebts()
            await loadOptimization()
            await loadProjections()
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
    
    private func loadOptimization() async {
        do {
            optimizationStrategy = try await FinancialDataService.shared.generateOptimizationStrategy()
            updateUI()
        } catch {
            showError(error)
        }
    }
    
    private func loadProjections() async {
        do {
            projections = try await FinancialDataService.shared.getProjections()
            updateUI()
        } catch {
            showError(error)
        }
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            self.strategyCard.configure(with: self.optimizationStrategy, debts: self.debts)
            self.projectionsCard.configure(with: self.projections)
            self.recommendationsCard.configure(with: self.debts)
        }
    }
    
    // MARK: - Actions
    
    @objc private func optimizeTapped() {
        loadingIndicator.startAnimating()
        optimizeButton.isEnabled = false
        
        Task {
            do {
                optimizationStrategy = try await FinancialDataService.shared.generateOptimizationStrategy()
                projections = try await FinancialDataService.shared.getProjections()
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.optimizeButton.isEnabled = true
                    self.updateUI()
                    self.showSuccessMessage()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.optimizeButton.isEnabled = true
                    self.showError(error)
                }
            }
        }
    }
    
    private func showSuccessMessage() {
        let alert = UIAlertController(
            title: "Optimization Complete!",
            message: "Your AI-powered debt payoff strategy has been generated. Check out the recommendations below.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Great!", style: .default))
        present(alert, animated: true)
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

extension OptimizationViewController: StrategyComparisonCardDelegate {
    func strategyComparisonCardDidTapStrategy(_ strategy: OptimizationStrategy) {
        let strategyDetailVC = StrategyDetailViewController()
        strategyDetailVC.strategy = strategy
        navigationController?.pushViewController(strategyDetailVC, animated: true)
    }
}

extension OptimizationViewController: ProjectionsCardDelegate {
    func projectionsCardDidTapProjection(_ projection: MonthlyProjection) {
        // Handle projection tap
        AnalyticsService.shared.trackUserAction("projection_tapped", properties: ["month": projection.month])
    }
}

extension OptimizationViewController: RecommendationsCardDelegate {
    func recommendationsCardDidTapRecommendation(_ recommendation: String) {
        // Handle recommendation tap
        AnalyticsService.shared.trackUserAction("recommendation_tapped", properties: ["recommendation": recommendation])
    }
}

// MARK: - Strategy Comparison Card

protocol StrategyComparisonCardDelegate: AnyObject {
    func strategyComparisonCardDidTapStrategy(_ strategy: OptimizationStrategy)
}

class StrategyComparisonCard: UIView {
    
    weak var delegate: StrategyComparisonCardDelegate?
    
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private let avalancheCard = StrategyCard()
    private let snowballCard = StrategyCard()
    private let hybridCard = StrategyCard()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Strategy Comparison"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        
        avalancheCard.configure(
            title: "Avalanche Method",
            subtitle: "Pay highest APR first",
            savings: "$2,400",
            timeSaved: "8 months",
            isRecommended: true
        )
        
        snowballCard.configure(
            title: "Snowball Method",
            subtitle: "Pay smallest balance first",
            savings: "$1,800",
            timeSaved: "6 months",
            isRecommended: false
        )
        
        hybridCard.configure(
            title: "Hybrid Method",
            subtitle: "Balanced approach",
            savings: "$2,100",
            timeSaved: "7 months",
            isRecommended: false
        )
        
        stackView.addArrangedSubview(avalancheCard)
        stackView.addArrangedSubview(snowballCard)
        stackView.addArrangedSubview(hybridCard)
        
        addSubview(titleLabel)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with strategy: OptimizationStrategy?, debts: [Debt]) {
        // Configure with actual strategy data
        if let strategy = strategy {
            // Update cards with real data
        }
    }
}

// MARK: - Strategy Card

class StrategyCard: UIView {
    
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let savingsLabel = UILabel()
    private let timeLabel = UILabel()
    private let recommendedBadge = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        layer.cornerRadius = 12
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        savingsLabel.translatesAutoresizingMaskIntoConstraints = false
        savingsLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        savingsLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        recommendedBadge.translatesAutoresizingMaskIntoConstraints = false
        recommendedBadge.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        recommendedBadge.textColor = .white
        recommendedBadge.backgroundColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        recommendedBadge.layer.cornerRadius = 8
        recommendedBadge.textAlignment = .center
        recommendedBadge.text = "RECOMMENDED"
        recommendedBadge.isHidden = true
        
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(savingsLabel)
        addSubview(timeLabel)
        addSubview(recommendedBadge)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            savingsLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            savingsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            
            timeLabel.centerYAnchor.constraint(equalTo: savingsLabel.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            
            recommendedBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            recommendedBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            recommendedBadge.widthAnchor.constraint(equalToConstant: 100),
            recommendedBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(title: String, subtitle: String, savings: String, timeSaved: String, isRecommended: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        savingsLabel.text = "Save \(savings)"
        timeLabel.text = "\(timeSaved) faster"
        recommendedBadge.isHidden = !isRecommended
    }
}

// MARK: - Projections Card

protocol ProjectionsCardDelegate: AnyObject {
    func projectionsCardDidTapProjection(_ projection: MonthlyProjection)
}

class ProjectionsCard: UIView {
    
    weak var delegate: ProjectionsCardDelegate?
    
    private let titleLabel = UILabel()
    private let chartView = ChartView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Monthly Projections"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        chartView.layer.cornerRadius = 12
        
        addSubview(titleLabel)
        addSubview(chartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            chartView.heightAnchor.constraint(equalToConstant: 200),
            chartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with projections: [MonthlyProjection]) {
        let dataPoints = projections.enumerated().map { index, projection in
            ChartDataPoint(
                label: projection.month,
                value: projection.remainingBalance
            )
        }
        chartView.configure(with: dataPoints, type: .line)
    }
}

// MARK: - Recommendations Card

protocol RecommendationsCardDelegate: AnyObject {
    func recommendationsCardDidTapRecommendation(_ recommendation: String)
}

class RecommendationsCard: UIView {
    
    weak var delegate: RecommendationsCardDelegate?
    
    private let titleLabel = UILabel()
    private let recommendationsLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "AI Recommendations"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        recommendationsLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationsLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        recommendationsLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        recommendationsLabel.numberOfLines = 0
        
        addSubview(titleLabel)
        addSubview(recommendationsLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            recommendationsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            recommendationsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            recommendationsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            recommendationsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with debts: [Debt]) {
        let recommendations = generateRecommendations(for: debts)
        recommendationsLabel.text = recommendations
    }
    
    private func generateRecommendations(for debts: [Debt]) -> String {
        var recommendations: [String] = []
        
        if let highInterestDebt = debts.first(where: { $0.apr > 15 }) {
            recommendations.append("• Focus on paying off \(highInterestDebt.name) first (APR: \(String(format: "%.1f", highInterestDebt.apr))%)")
        }
        
        if let lowBalanceDebt = debts.first(where: { $0.currentBalance < 1000 }) {
            recommendations.append("• Consider paying off \(lowBalanceDebt.name) quickly to reduce monthly payments")
        }
        
        let totalDebt = debts.reduce(0) { $0 + $1.currentBalance }
        if totalDebt > 50000 {
            recommendations.append("• Consider debt consolidation to lower your overall interest rate")
        }
        
        if recommendations.isEmpty {
            recommendations.append("• Continue making minimum payments on all debts")
            recommendations.append("• Consider increasing payments on your highest APR debt")
        }
        
        return recommendations.joined(separator: "\n")
    }
}
