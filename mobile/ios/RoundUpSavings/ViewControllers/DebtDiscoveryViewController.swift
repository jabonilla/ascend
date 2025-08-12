import UIKit

class DebtDiscoveryViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressView = UIProgressView()
    
    private let discoveryStatusView = DiscoveryStatusView()
    private let discoveredDebtsView = DiscoveredDebtsView()
    private let analysisView = DebtAnalysisView()
    
    private let continueButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var discoveredDebts: [DiscoveredDebt] = []
    private var analysisResults: DebtAnalysis?
    private var isAnalyzing = false
    private var currentStep: DiscoveryStep = .initializing
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startDiscovery()
        AnalyticsService.shared.trackScreenView("DebtDiscovery")
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
        
        // Discovery status
        discoveryStatusView.translatesAutoresizingMaskIntoConstraints = false
        discoveryStatusView.delegate = self
        
        // Discovered debts
        discoveredDebtsView.translatesAutoresizingMaskIntoConstraints = false
        discoveredDebtsView.delegate = self
        
        // Analysis view
        analysisView.translatesAutoresizingMaskIntoConstraints = false
        
        // Continue button
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.setTitle("Add Discovered Debts", for: .normal)
        continueButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        continueButton.layer.cornerRadius = 12
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.isEnabled = false
        
        // Skip button
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("Skip Discovery", for: .normal)
        skipButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        skipButton.setTitleColor(UIColor(named: "AccentLavender") ?? .darkGray, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(discoveryStatusView)
        contentView.addSubview(discoveredDebtsView)
        contentView.addSubview(analysisView)
        contentView.addSubview(continueButton)
        contentView.addSubview(skipButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Discovering Your Debts"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "We're analyzing your accounts to find and categorize your debts"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .white
        subtitleLabel.alpha = 0.9
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.progress = 0.0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        headerView.addSubview(progressView)
    }
    
    private func setupNavigationBar() {
        title = "Debt Discovery"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
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
            headerView.heightAnchor.constraint(equalToConstant: 140),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // Discovery status
            discoveryStatusView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            discoveryStatusView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            discoveryStatusView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Discovered debts
            discoveredDebtsView.topAnchor.constraint(equalTo: discoveryStatusView.bottomAnchor, constant: 20),
            discoveredDebtsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            discoveredDebtsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Analysis view
            analysisView.topAnchor.constraint(equalTo: discoveredDebtsView.bottomAnchor, constant: 20),
            analysisView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            analysisView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: analysisView.bottomAnchor, constant: 30),
            continueButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Discovery Process
    
    private func startDiscovery() {
        isAnalyzing = true
        loadingIndicator.startAnimating()
        
        Task {
            await performDiscovery()
        }
    }
    
    private func performDiscovery() async {
        // Step 1: Initialize
        await updateStep(.initializing, progress: 0.1)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Step 2: Connecting to accounts
        await updateStep(.connecting, progress: 0.3)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Step 3: Analyzing transactions
        await updateStep(.analyzing, progress: 0.6)
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Step 4: Discovering debts
        await updateStep(.discovering, progress: 0.8)
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Step 5: Complete
        await updateStep(.complete, progress: 1.0)
        
        // Load discovered debts
        await loadDiscoveredDebts()
        await performAnalysis()
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.loadingIndicator.stopAnimating()
            self.continueButton.isEnabled = true
        }
    }
    
    private func updateStep(_ step: DiscoveryStep, progress: Float) async {
        await MainActor.run {
            currentStep = step
            progressView.setProgress(progress, animated: true)
            discoveryStatusView.updateStep(step)
            
            switch step {
            case .initializing:
                titleLabel.text = "Initializing Discovery"
                subtitleLabel.text = "Setting up secure connection to your accounts"
            case .connecting:
                titleLabel.text = "Connecting to Accounts"
                subtitleLabel.text = "Securely accessing your bank accounts"
            case .analyzing:
                titleLabel.text = "Analyzing Transactions"
                subtitleLabel.text = "Scanning your transaction history for debt patterns"
            case .discovering:
                titleLabel.text = "Discovering Debts"
                subtitleLabel.text = "Identifying and categorizing your debts"
            case .complete:
                titleLabel.text = "Discovery Complete!"
                subtitleLabel.text = "We found \(discoveredDebts.count) potential debts in your accounts"
            }
        }
    }
    
    private func loadDiscoveredDebts() async {
        do {
            discoveredDebts = try await FinancialDataService.shared.discoverDebts()
            await MainActor.run {
                discoveredDebtsView.configure(with: discoveredDebts)
            }
        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }
    
    private func performAnalysis() async {
        do {
            analysisResults = try await FinancialDataService.shared.analyzeDebts(discoveredDebts)
            await MainActor.run {
                analysisView.configure(with: analysisResults)
            }
        } catch {
            await MainActor.run {
                showError(error)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func continueTapped() {
        guard !discoveredDebts.isEmpty else {
            showAlert(title: "No Debts Found", message: "We couldn't find any debts in your accounts. You can add them manually later.")
            return
        }
        
        Task {
            do {
                try await FinancialDataService.shared.importDiscoveredDebts(discoveredDebts)
                
                DispatchQueue.main.async {
                    self.showSuccessMessage()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func skipTapped() {
        AnalyticsService.shared.trackUserAction("debt_discovery_skipped")
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showSuccessMessage() {
        let alert = UIAlertController(
            title: "Debts Added Successfully!",
            message: "We've added \(discoveredDebts.count) debts to your account. You can now track and optimize your debt payoff strategy.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Discovery Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Discovery Status Delegate

extension DebtDiscoveryViewController: DiscoveryStatusViewDelegate {
    func discoveryStatusViewDidTapRetry() {
        startDiscovery()
    }
}

// MARK: - Discovered Debts Delegate

extension DebtDiscoveryViewController: DiscoveredDebtsViewDelegate {
    func discoveredDebtsViewDidToggleDebt(_ debt: DiscoveredDebt, isSelected: Bool) {
        if let index = discoveredDebts.firstIndex(where: { $0.id == debt.id }) {
            discoveredDebts[index].isSelected = isSelected
        }
    }
}

// MARK: - Supporting Types

enum DiscoveryStep {
    case initializing
    case connecting
    case analyzing
    case discovering
    case complete
    
    var title: String {
        switch self {
        case .initializing: return "Initializing"
        case .connecting: return "Connecting to Accounts"
        case .analyzing: return "Analyzing Transactions"
        case .discovering: return "Discovering Debts"
        case .complete: return "Complete"
        }
    }
    
    var description: String {
        switch self {
        case .initializing: return "Setting up secure connection"
        case .connecting: return "Accessing your bank accounts"
        case .analyzing: return "Scanning transaction history"
        case .discovering: return "Identifying debt patterns"
        case .complete: return "Discovery finished"
        }
    }
    
    var icon: String {
        switch self {
        case .initializing: return "gear"
        case .connecting: return "link"
        case .analyzing: return "magnifyingglass"
        case .discovering: return "creditcard"
        case .complete: return "checkmark.circle.fill"
        }
    }
}

struct DiscoveredDebt: Codable, Identifiable {
    let id: String
    let name: String
    let type: DebtType
    let currentBalance: Double
    let originalBalance: Double
    let apr: Double
    let minimumPayment: Double
    let dueDate: Date
    let accountNumber: String
    let institution: String
    let confidence: Double
    var isSelected: Bool = true
}

struct DebtAnalysis: Codable {
    let totalDebt: Double
    let averageAPR: Double
    let highestAPR: Double
    let monthlyPayments: Double
    let payoffTime: Int // months
    let totalInterest: Double
    let recommendations: [String]
}

// MARK: - Discovery Status View

protocol DiscoveryStatusViewDelegate: AnyObject {
    func discoveryStatusViewDidTapRetry()
}

class DiscoveryStatusView: UIView {
    
    weak var delegate: DiscoveryStatusViewDelegate?
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let iconImageView = UIImageView()
    private let retryButton = UIButton(type: .system)
    
    private var currentStep: DiscoveryStep = .initializing
    
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
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        descriptionLabel.alpha = 0.7
        descriptionLabel.numberOfLines = 0
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("Retry", for: .normal)
        retryButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        retryButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.isHidden = true
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(iconImageView)
        addSubview(retryButton)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: retryButton.leadingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            retryButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            retryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }
    
    func updateStep(_ step: DiscoveryStep) {
        currentStep = step
        titleLabel.text = step.title
        descriptionLabel.text = step.description
        iconImageView.image = UIImage(systemName: step.icon)
        
        if step == .complete {
            iconImageView.tintColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        } else {
            iconImageView.tintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        }
    }
    
    @objc private func retryTapped() {
        delegate?.discoveryStatusViewDidTapRetry()
    }
}

// MARK: - Discovered Debts View

protocol DiscoveredDebtsViewDelegate: AnyObject {
    func discoveredDebtsViewDidToggleDebt(_ debt: DiscoveredDebt, isSelected: Bool)
}

class DiscoveredDebtsView: UIView {
    
    weak var delegate: DiscoveredDebtsViewDelegate?
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    
    private var debts: [DiscoveredDebt] = []
    
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
        titleLabel.text = "Discovered Debts"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DiscoveredDebtCell.self, forCellReuseIdentifier: "DiscoveredDebtCell")
        tableView.isScrollEnabled = false
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.configure(
            title: "No Debts Found",
            message: "We couldn't find any debts in your accounts",
            buttonTitle: "Add Manually",
            icon: "creditcard"
        )
        emptyStateView.isHidden = true
        
        addSubview(titleLabel)
        addSubview(tableView)
        addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            emptyStateView.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40)
        ])
    }
    
    func configure(with debts: [DiscoveredDebt]) {
        self.debts = debts
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !debts.isEmpty
        tableView.isHidden = debts.isEmpty
    }
}

extension DiscoveredDebtsView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return debts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoveredDebtCell", for: indexPath) as! DiscoveredDebtCell
        cell.configure(with: debts[indexPath.row])
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

extension DiscoveredDebtsView: DiscoveredDebtCellDelegate {
    func discoveredDebtCellDidToggleSelection(_ debt: DiscoveredDebt, isSelected: Bool) {
        delegate?.discoveredDebtsViewDidToggleDebt(debt, isSelected: isSelected)
    }
}

// MARK: - Discovered Debt Cell

protocol DiscoveredDebtCellDelegate: AnyObject {
    func discoveredDebtCellDidToggleSelection(_ debt: DiscoveredDebt, isSelected: Bool)
}

class DiscoveredDebtCell: UITableViewCell {
    
    weak var delegate: DiscoveredDebtCellDelegate?
    private var debt: DiscoveredDebt?
    
    private let containerView = UIView()
    private let selectionSwitch = UISwitch()
    private let nameLabel = UILabel()
    private let institutionLabel = UILabel()
    private let balanceLabel = UILabel()
    private let confidenceLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        containerView.layer.cornerRadius = 12
        
        selectionSwitch.translatesAutoresizingMaskIntoConstraints = false
        selectionSwitch.onTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        selectionSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        institutionLabel.translatesAutoresizingMaskIntoConstraints = false
        institutionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        institutionLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        institutionLabel.alpha = 0.7
        
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        balanceLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        confidenceLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        contentView.addSubview(containerView)
        containerView.addSubview(selectionSwitch)
        containerView.addSubview(nameLabel)
        containerView.addSubview(institutionLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(confidenceLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            selectionSwitch.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            selectionSwitch.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: selectionSwitch.leadingAnchor, constant: -16),
            
            institutionLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            institutionLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            institutionLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            balanceLabel.topAnchor.constraint(equalTo: institutionLabel.bottomAnchor, constant: 8),
            balanceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            balanceLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            confidenceLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            confidenceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            confidenceLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            confidenceLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with debt: DiscoveredDebt) {
        self.debt = debt
        nameLabel.text = debt.name
        institutionLabel.text = debt.institution
        balanceLabel.text = String(format: "$%.2f", debt.currentBalance)
        confidenceLabel.text = String(format: "%.0f%% confidence", debt.confidence * 100)
        selectionSwitch.isOn = debt.isSelected
    }
    
    @objc private func switchChanged() {
        guard let debt = debt else { return }
        delegate?.discoveredDebtCellDidToggleSelection(debt, isSelected: selectionSwitch.isOn)
    }
}

// MARK: - Debt Analysis View

class DebtAnalysisView: UIView {
    
    private let titleLabel = UILabel()
    private let analysisStackView = UIStackView()
    
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
        titleLabel.text = "Analysis Summary"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        analysisStackView.translatesAutoresizingMaskIntoConstraints = false
        analysisStackView.axis = .vertical
        analysisStackView.spacing = 12
        
        addSubview(titleLabel)
        addSubview(analysisStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            analysisStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            analysisStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            analysisStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            analysisStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with analysis: DebtAnalysis?) {
        // Clear existing analysis items
        analysisStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard let analysis = analysis else { return }
        
        let analysisItems = [
            ("Total Debt", String(format: "$%.2f", analysis.totalDebt)),
            ("Average APR", String(format: "%.1f%%", analysis.averageAPR)),
            ("Monthly Payments", String(format: "$%.2f", analysis.monthlyPayments)),
            ("Payoff Time", "\(analysis.payoffTime) months"),
            ("Total Interest", String(format: "$%.2f", analysis.totalInterest))
        ]
        
        for (title, value) in analysisItems {
            let itemView = AnalysisItemView(title: title, value: value)
            analysisStackView.addArrangedSubview(itemView)
        }
        
        // Add recommendations
        if !analysis.recommendations.isEmpty {
            let recommendationsView = RecommendationsView(recommendations: analysis.recommendations)
            analysisStackView.addArrangedSubview(recommendationsView)
        }
    }
}

// MARK: - Analysis Item View

class AnalysisItemView: UIView {
    
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    
    init(title: String, value: String) {
        super.init(frame: .zero)
        setupView()
        configure(title: title, value: value)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.alpha = 0.7
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        valueLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        addSubview(titleLabel)
        addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}

// MARK: - Recommendations View

class RecommendationsView: UIView {
    
    private let titleLabel = UILabel()
    private let recommendationsStackView = UIStackView()
    
    init(recommendations: [String]) {
        super.init(frame: .zero)
        setupView()
        configure(with: recommendations)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Recommendations"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        recommendationsStackView.translatesAutoresizingMaskIntoConstraints = false
        recommendationsStackView.axis = .vertical
        recommendationsStackView.spacing = 8
        
        addSubview(titleLabel)
        addSubview(recommendationsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            recommendationsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            recommendationsStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            recommendationsStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            recommendationsStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with recommendations: [String]) {
        for recommendation in recommendations {
            let recommendationView = RecommendationItemView(recommendation: recommendation)
            recommendationsStackView.addArrangedSubview(recommendationView)
        }
    }
}

// MARK: - Recommendation Item View

class RecommendationItemView: UIView {
    
    private let iconImageView = UIImageView()
    private let recommendationLabel = UILabel()
    
    init(recommendation: String) {
        super.init(frame: .zero)
        setupView()
        configure(with: recommendation)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "lightbulb.fill")
        iconImageView.tintColor = UIColor(named: "WarningOrange") ?? .systemOrange
        iconImageView.contentMode = .scaleAspectFit
        
        recommendationLabel.translatesAutoresizingMaskIntoConstraints = false
        recommendationLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        recommendationLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        recommendationLabel.numberOfLines = 0
        
        addSubview(iconImageView)
        addSubview(recommendationLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            recommendationLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            recommendationLabel.topAnchor.constraint(equalTo: topAnchor),
            recommendationLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            recommendationLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with recommendation: String) {
        recommendationLabel.text = recommendation
    }
}
