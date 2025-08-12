import UIKit

class DebtConsolidationViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let currentDebtsView = CurrentDebtsView()
    private let consolidationOptionsView = ConsolidationOptionsView()
    private let comparisonView = ConsolidationComparisonView()
    
    private let calculateButton = UIButton(type: .system)
    private let applyButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var debts: [Debt] = []
    private var consolidationOptions: [ConsolidationOption] = []
    private var selectedOption: ConsolidationOption?
    private var comparisonResults: ConsolidationComparison?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AnalyticsService.shared.trackScreenView("DebtConsolidation")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderView()
        
        currentDebtsView.translatesAutoresizingMaskIntoConstraints = false
        currentDebtsView.delegate = self
        
        consolidationOptionsView.translatesAutoresizingMaskIntoConstraints = false
        consolidationOptionsView.delegate = self
        
        comparisonView.translatesAutoresizingMaskIntoConstraints = false
        
        calculateButton.translatesAutoresizingMaskIntoConstraints = false
        calculateButton.setTitle("Calculate Savings", for: .normal)
        calculateButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        calculateButton.setTitleColor(.white, for: .normal)
        calculateButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        calculateButton.layer.cornerRadius = 12
        calculateButton.addTarget(self, action: #selector(calculateTapped), for: .touchUpInside)
        
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.setTitle("Apply for Consolidation", for: .normal)
        applyButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        applyButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        applyButton.backgroundColor = UIColor(named: "PrimaryBlue")?.withAlphaComponent(0.1) ?? UIColor.systemBlue.withAlphaComponent(0.1)
        applyButton.layer.cornerRadius = 8
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        applyButton.isHidden = true
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        contentView.addSubview(headerView)
        contentView.addSubview(currentDebtsView)
        contentView.addSubview(consolidationOptionsView)
        contentView.addSubview(comparisonView)
        contentView.addSubview(calculateButton)
        contentView.addSubview(applyButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Debt Consolidation"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Combine multiple debts into one lower-rate loan"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .white
        subtitleLabel.alpha = 0.9
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupNavigationBar() {
        title = "Consolidation"
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            currentDebtsView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            currentDebtsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            currentDebtsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            consolidationOptionsView.topAnchor.constraint(equalTo: currentDebtsView.bottomAnchor, constant: 20),
            consolidationOptionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            consolidationOptionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            comparisonView.topAnchor.constraint(equalTo: consolidationOptionsView.bottomAnchor, constant: 20),
            comparisonView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            comparisonView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            calculateButton.topAnchor.constraint(equalTo: comparisonView.bottomAnchor, constant: 30),
            calculateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calculateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            calculateButton.heightAnchor.constraint(equalToConstant: 50),
            
            applyButton.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 16),
            applyButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            applyButton.heightAnchor.constraint(equalToConstant: 40),
            applyButton.widthAnchor.constraint(equalToConstant: 200),
            applyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            do {
                debts = try await FinancialDataService.shared.getDebts()
                consolidationOptions = try await FinancialDataService.shared.getConsolidationOptions()
                
                await MainActor.run {
                    currentDebtsView.configure(with: debts)
                    consolidationOptionsView.configure(with: consolidationOptions)
                    updateUI()
                }
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
    
    private func updateUI() {
        comparisonView.isHidden = comparisonResults == nil
        applyButton.isHidden = selectedOption == nil
    }
    
    // MARK: - Actions
    
    @objc private func calculateTapped() {
        guard let selectedOption = selectedOption else {
            showAlert(title: "Select Option", message: "Please select a consolidation option first.")
            return
        }
        
        loadingIndicator.startAnimating()
        calculateButton.isEnabled = false
        
        Task {
            do {
                comparisonResults = try await FinancialDataService.shared.calculateConsolidation(
                    debts: debts,
                    option: selectedOption
                )
                
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.calculateButton.isEnabled = true
                    self.comparisonView.configure(with: self.comparisonResults!)
                    self.updateUI()
                }
            } catch {
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.calculateButton.isEnabled = true
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func applyTapped() {
        guard let option = selectedOption else { return }
        
        let alert = UIAlertController(
            title: "Apply for Consolidation",
            message: "Would you like to apply for the \(option.name) consolidation loan?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { _ in
            self.startApplication(option: option)
        })
        
        present(alert, animated: true)
    }
    
    private func startApplication(option: ConsolidationOption) {
        // In a real app, this would navigate to the loan application flow
        let alert = UIAlertController(
            title: "Application Started",
            message: "You'll be redirected to complete your application for \(option.name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Calculation Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Current Debts Delegate

extension DebtConsolidationViewController: CurrentDebtsViewDelegate {
    func currentDebtsViewDidToggleDebt(_ debt: Debt, isSelected: Bool) {
        if let index = debts.firstIndex(where: { $0.id == debt.id }) {
            debts[index].isSelectedForConsolidation = isSelected
        }
    }
}

// MARK: - Consolidation Options Delegate

extension DebtConsolidationViewController: ConsolidationOptionsViewDelegate {
    func consolidationOptionsViewDidSelectOption(_ option: ConsolidationOption) {
        selectedOption = option
        AnalyticsService.shared.trackUserAction("consolidation_option_selected", properties: ["option": option.name])
    }
}

// MARK: - Supporting Types

struct ConsolidationOption: Codable, Identifiable {
    let id: String
    let name: String
    let type: ConsolidationType
    let apr: Double
    let term: Int // months
    let minAmount: Double
    let maxAmount: Double
    let originationFee: Double
    let creditScoreRequired: Int
    let features: [String]
    let pros: [String]
    let cons: [String]
}

enum ConsolidationType: String, CaseIterable {
    case personalLoan = "personal_loan"
    case balanceTransfer = "balance_transfer"
    case homeEquity = "home_equity"
    case debtManagement = "debt_management"
    
    var displayName: String {
        switch self {
        case .personalLoan: return "Personal Loan"
        case .balanceTransfer: return "Balance Transfer"
        case .homeEquity: return "Home Equity"
        case .debtManagement: return "Debt Management"
        }
    }
}

struct ConsolidationComparison: Codable {
    let currentTotal: Double
    let currentMonthlyPayment: Double
    let currentTotalInterest: Double
    let currentPayoffTime: Int
    
    let consolidatedTotal: Double
    let consolidatedMonthlyPayment: Double
    let consolidatedTotalInterest: Double
    let consolidatedPayoffTime: Int
    
    let monthlySavings: Double
    let totalSavings: Double
    let timeSaved: Int // months
    let recommendations: [String]
}

// MARK: - Current Debts View

protocol CurrentDebtsViewDelegate: AnyObject {
    func currentDebtsViewDidToggleDebt(_ debt: Debt, isSelected: Bool)
}

class CurrentDebtsView: UIView {
    
    weak var delegate: CurrentDebtsViewDelegate?
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    
    private var debts: [Debt] = []
    
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
        titleLabel.text = "Select Debts to Consolidate"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ConsolidationDebtCell.self, forCellReuseIdentifier: "ConsolidationDebtCell")
        tableView.isScrollEnabled = false
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.configure(
            title: "No Debts Available",
            message: "Add some debts to see consolidation options",
            buttonTitle: "Add Debt",
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
    
    func configure(with debts: [Debt]) {
        self.debts = debts
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !debts.isEmpty
        tableView.isHidden = debts.isEmpty
    }
}

extension CurrentDebtsView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return debts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConsolidationDebtCell", for: indexPath) as! ConsolidationDebtCell
        cell.configure(with: debts[indexPath.row])
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

extension CurrentDebtsView: ConsolidationDebtCellDelegate {
    func consolidationDebtCellDidToggleSelection(_ debt: Debt, isSelected: Bool) {
        delegate?.currentDebtsViewDidToggleDebt(debt, isSelected: isSelected)
    }
}

// MARK: - Consolidation Debt Cell

protocol ConsolidationDebtCellDelegate: AnyObject {
    func consolidationDebtCellDidToggleSelection(_ debt: Debt, isSelected: Bool)
}

class ConsolidationDebtCell: UITableViewCell {
    
    weak var delegate: ConsolidationDebtCellDelegate?
    private var debt: Debt?
    
    private let containerView = UIView()
    private let selectionSwitch = UISwitch()
    private let nameLabel = UILabel()
    private let balanceLabel = UILabel()
    private let aprLabel = UILabel()
    
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
        
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        balanceLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        aprLabel.translatesAutoresizingMaskIntoConstraints = false
        aprLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        aprLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        aprLabel.alpha = 0.7
        
        contentView.addSubview(containerView)
        containerView.addSubview(selectionSwitch)
        containerView.addSubview(nameLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(aprLabel)
        
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
            
            balanceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            balanceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            balanceLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            aprLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 4),
            aprLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            aprLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            aprLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with debt: Debt) {
        self.debt = debt
        nameLabel.text = debt.name
        balanceLabel.text = String(format: "$%.2f", debt.currentBalance)
        aprLabel.text = String(format: "%.1f%% APR", debt.apr)
        selectionSwitch.isOn = debt.isSelectedForConsolidation
    }
    
    @objc private func switchChanged() {
        guard let debt = debt else { return }
        delegate?.consolidationDebtCellDidToggleSelection(debt, isSelected: selectionSwitch.isOn)
    }
}

// MARK: - Consolidation Options View

protocol ConsolidationOptionsViewDelegate: AnyObject {
    func consolidationOptionsViewDidSelectOption(_ option: ConsolidationOption)
}

class ConsolidationOptionsView: UIView {
    
    weak var delegate: ConsolidationOptionsViewDelegate?
    
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var selectedOption: ConsolidationOption?
    private var options: [ConsolidationOption] = []
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 120)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 120)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
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
        titleLabel.text = "Consolidation Options"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ConsolidationOptionCell.self, forCellWithReuseIdentifier: "ConsolidationOptionCell")
        collectionView.showsHorizontalScrollIndicator = false
        
        addSubview(titleLabel)
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            collectionView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    func configure(with options: [ConsolidationOption]) {
        self.options = options
        collectionView.reloadData()
    }
}

extension ConsolidationOptionsView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return options.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ConsolidationOptionCell", for: indexPath) as! ConsolidationOptionCell
        let option = options[indexPath.item]
        cell.configure(with: option, isSelected: option.id == selectedOption?.id)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let option = options[indexPath.item]
        selectedOption = option
        collectionView.reloadData()
        delegate?.consolidationOptionsViewDidSelectOption(option)
    }
}

// MARK: - Consolidation Option Cell

class ConsolidationOptionCell: UICollectionViewCell {
    
    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let aprLabel = UILabel()
    private let termLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        containerView.layer.cornerRadius = 12
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        nameLabel.numberOfLines = 2
        
        aprLabel.translatesAutoresizingMaskIntoConstraints = false
        aprLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        aprLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        termLabel.translatesAutoresizingMaskIntoConstraints = false
        termLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        termLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        termLabel.alpha = 0.7
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(aprLabel)
        containerView.addSubview(termLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            aprLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            aprLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            aprLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            termLabel.topAnchor.constraint(equalTo: aprLabel.bottomAnchor, constant: 4),
            termLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            termLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            termLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(with option: ConsolidationOption, isSelected: Bool) {
        nameLabel.text = option.name
        aprLabel.text = String(format: "%.1f%% APR", option.apr)
        termLabel.text = "\(option.term) months"
        
        if isSelected {
            containerView.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
            nameLabel.textColor = .white
            aprLabel.textColor = .white
            termLabel.textColor = .white
        } else {
            containerView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
            nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
            aprLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
            termLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        }
    }
}

// MARK: - Consolidation Comparison View

class ConsolidationComparisonView: UIView {
    
    private let titleLabel = UILabel()
    private let comparisonStackView = UIStackView()
    
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
        titleLabel.text = "Savings Comparison"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        comparisonStackView.translatesAutoresizingMaskIntoConstraints = false
        comparisonStackView.axis = .vertical
        comparisonStackView.spacing = 12
        
        addSubview(titleLabel)
        addSubview(comparisonStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            comparisonStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            comparisonStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            comparisonStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            comparisonStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with comparison: ConsolidationComparison) {
        comparisonStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let savings = [
            ("Monthly Savings", String(format: "$%.2f", comparison.monthlySavings)),
            ("Total Savings", String(format: "$%.2f", comparison.totalSavings)),
            ("Time Saved", "\(comparison.timeSaved) months"),
            ("New Monthly Payment", String(format: "$%.2f", comparison.consolidatedMonthlyPayment))
        ]
        
        for (title, value) in savings {
            let itemView = ComparisonItemView(title: title, value: value)
            comparisonStackView.addArrangedSubview(itemView)
        }
        
        for recommendation in comparison.recommendations {
            let recommendationView = RecommendationItemView(recommendation: recommendation)
            comparisonStackView.addArrangedSubview(recommendationView)
        }
    }
}

// MARK: - Comparison Item View

class ComparisonItemView: UIView {
    
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
        valueLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
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
