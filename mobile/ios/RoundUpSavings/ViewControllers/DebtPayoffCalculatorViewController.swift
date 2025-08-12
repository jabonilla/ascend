import UIKit

class DebtPayoffCalculatorViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let scenarioSelectorView = ScenarioSelectorView()
    private let calculatorView = CalculatorView()
    private let resultsView = ResultsView()
    private let comparisonView = ComparisonView()
    
    private let calculateButton = UIButton(type: .system)
    private let saveScenarioButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var debts: [Debt] = []
    private var currentScenario: PayoffScenario = .avalanche
    private var calculationResults: PayoffCalculation?
    private var savedScenarios: [SavedScenario] = []
    
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
        AnalyticsService.shared.trackScreenView("DebtPayoffCalculator")
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
        
        // Scenario selector
        scenarioSelectorView.translatesAutoresizingMaskIntoConstraints = false
        scenarioSelectorView.delegate = self
        
        // Calculator view
        calculatorView.translatesAutoresizingMaskIntoConstraints = false
        calculatorView.delegate = self
        
        // Results view
        resultsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Comparison view
        comparisonView.translatesAutoresizingMaskIntoConstraints = false
        
        // Calculate button
        calculateButton.translatesAutoresizingMaskIntoConstraints = false
        calculateButton.setTitle("Calculate Payoff Plan", for: .normal)
        calculateButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        calculateButton.setTitleColor(.white, for: .normal)
        calculateButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        calculateButton.layer.cornerRadius = 12
        calculateButton.addTarget(self, action: #selector(calculateTapped), for: .touchUpInside)
        
        // Save scenario button
        saveScenarioButton.translatesAutoresizingMaskIntoConstraints = false
        saveScenarioButton.setTitle("Save Scenario", for: .normal)
        saveScenarioButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        saveScenarioButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        saveScenarioButton.backgroundColor = UIColor(named: "PrimaryBlue")?.withAlphaComponent(0.1) ?? UIColor.systemBlue.withAlphaComponent(0.1)
        saveScenarioButton.layer.cornerRadius = 8
        saveScenarioButton.addTarget(self, action: #selector(saveScenarioTapped), for: .touchUpInside)
        saveScenarioButton.isHidden = true
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(scenarioSelectorView)
        contentView.addSubview(calculatorView)
        contentView.addSubview(resultsView)
        contentView.addSubview(comparisonView)
        contentView.addSubview(calculateButton)
        contentView.addSubview(saveScenarioButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Debt Payoff Calculator"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Compare different payoff strategies and see your debt-free timeline"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .white
        subtitleLabel.alpha = 0.9
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupNavigationBar() {
        title = "Payoff Calculator"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Saved",
            style: .plain,
            target: self,
            action: #selector(savedScenariosTapped)
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
            headerView.heightAnchor.constraint(equalToConstant: 100),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // Scenario selector
            scenarioSelectorView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            scenarioSelectorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scenarioSelectorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Calculator view
            calculatorView.topAnchor.constraint(equalTo: scenarioSelectorView.bottomAnchor, constant: 20),
            calculatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calculatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Results view
            resultsView.topAnchor.constraint(equalTo: calculatorView.bottomAnchor, constant: 20),
            resultsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            resultsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Comparison view
            comparisonView.topAnchor.constraint(equalTo: resultsView.bottomAnchor, constant: 20),
            comparisonView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            comparisonView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Calculate button
            calculateButton.topAnchor.constraint(equalTo: comparisonView.bottomAnchor, constant: 30),
            calculateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            calculateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            calculateButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Save scenario button
            saveScenarioButton.topAnchor.constraint(equalTo: calculateButton.bottomAnchor, constant: 16),
            saveScenarioButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            saveScenarioButton.heightAnchor.constraint(equalToConstant: 40),
            saveScenarioButton.widthAnchor.constraint(equalToConstant: 120),
            saveScenarioButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            do {
                debts = try await FinancialDataService.shared.getDebts()
                savedScenarios = try await FinancialDataService.shared.getSavedScenarios()
                
                await MainActor.run {
                    calculatorView.configure(with: debts)
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
        resultsView.isHidden = calculationResults == nil
        comparisonView.isHidden = calculationResults == nil
        saveScenarioButton.isHidden = calculationResults == nil
    }
    
    // MARK: - Actions
    
    @objc private func calculateTapped() {
        guard !debts.isEmpty else {
            showAlert(title: "No Debts", message: "Please add some debts first to use the calculator.")
            return
        }
        
        let calculatorInput = calculatorView.getCalculatorInput()
        
        loadingIndicator.startAnimating()
        calculateButton.isEnabled = false
        
        Task {
            do {
                calculationResults = try await FinancialDataService.shared.calculatePayoffPlan(
                    debts: debts,
                    scenario: currentScenario,
                    input: calculatorInput
                )
                
                await MainActor.run {
                    self.loadingIndicator.stopAnimating()
                    self.calculateButton.isEnabled = true
                    self.resultsView.configure(with: self.calculationResults!)
                    self.comparisonView.configure(with: self.calculationResults!)
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
    
    @objc private func saveScenarioTapped() {
        guard let results = calculationResults else { return }
        
        let alert = UIAlertController(title: "Save Scenario", message: "Give this scenario a name:", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "e.g., Aggressive Payoff Plan"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let name = alert.textFields?.first?.text ?? "Unnamed Scenario"
            self.saveScenario(name: name, results: results)
        })
        
        present(alert, animated: true)
    }
    
    @objc private func savedScenariosTapped() {
        let savedVC = SavedScenariosViewController()
        savedVC.delegate = self
        let nav = UINavigationController(rootViewController: savedVC)
        present(nav, animated: true)
    }
    
    private func saveScenario(name: String, results: PayoffCalculation) {
        let scenario = SavedScenario(
            id: UUID().uuidString,
            name: name,
            scenario: currentScenario,
            calculation: results,
            createdAt: Date()
        )
        
        Task {
            do {
                try await FinancialDataService.shared.saveScenario(scenario)
                savedScenarios.append(scenario)
                
                await MainActor.run {
                    self.showSuccessMessage("Scenario saved successfully!")
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
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

// MARK: - Scenario Selector Delegate

extension DebtPayoffCalculatorViewController: ScenarioSelectorViewDelegate {
    func scenarioSelectorViewDidSelectScenario(_ scenario: PayoffScenario) {
        currentScenario = scenario
        AnalyticsService.shared.trackUserAction("calculator_scenario_selected", properties: ["scenario": scenario.rawValue])
    }
}

// MARK: - Calculator Delegate

extension DebtPayoffCalculatorViewController: CalculatorViewDelegate {
    func calculatorViewDidUpdateInput() {
        // Recalculate if we have results
        if calculationResults != nil {
            calculateTapped()
        }
    }
}

// MARK: - Saved Scenarios Delegate

extension DebtPayoffCalculatorViewController: SavedScenariosViewControllerDelegate {
    func savedScenariosViewControllerDidSelectScenario(_ scenario: SavedScenario) {
        currentScenario = scenario.scenario
        calculationResults = scenario.calculation
        
        scenarioSelectorView.selectScenario(scenario.scenario)
        resultsView.configure(with: scenario.calculation)
        comparisonView.configure(with: scenario.calculation)
        updateUI()
        
        dismiss(animated: true)
    }
}

// MARK: - Supporting Types

enum PayoffScenario: String, CaseIterable {
    case avalanche = "avalanche"
    case snowball = "snowball"
    case hybrid = "hybrid"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .avalanche: return "Avalanche Method"
        case .snowball: return "Snowball Method"
        case .hybrid: return "Hybrid Approach"
        case .custom: return "Custom Strategy"
        }
    }
    
    var description: String {
        switch self {
        case .avalanche: return "Pay off highest APR first"
        case .snowball: return "Pay off smallest balance first"
        case .hybrid: return "Balance between APR and balance"
        case .custom: return "Custom payment allocation"
        }
    }
    
    var icon: String {
        switch self {
        case .avalanche: return "arrow.up.circle.fill"
        case .snowball: return "snowflake"
        case .hybrid: return "circle.hexagongrid.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

struct PayoffCalculation: Codable {
    let scenario: PayoffScenario
    let totalDebt: Double
    let totalInterest: Double
    let payoffTime: Int // months
    let monthlyPayment: Double
    let debtOrder: [String] // debt IDs in payoff order
    let monthlyProjections: [MonthlyProjection]
    let savings: Double // compared to minimum payments
    let recommendations: [String]
}

struct SavedScenario: Codable, Identifiable {
    let id: String
    let name: String
    let scenario: PayoffScenario
    let calculation: PayoffCalculation
    let createdAt: Date
}

struct CalculatorInput {
    let extraPayment: Double
    let targetPayoffDate: Date?
    let debtPriorities: [String: Int] // debt ID to priority
}

// MARK: - Scenario Selector View

protocol ScenarioSelectorViewDelegate: AnyObject {
    func scenarioSelectorViewDidSelectScenario(_ scenario: PayoffScenario)
}

class ScenarioSelectorView: UIView {
    
    weak var delegate: ScenarioSelectorViewDelegate?
    
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var selectedScenario: PayoffScenario = .avalanche
    
    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 80)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 80)
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
        titleLabel.text = "Choose Strategy"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ScenarioCell.self, forCellWithReuseIdentifier: "ScenarioCell")
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
            collectionView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    func selectScenario(_ scenario: PayoffScenario) {
        selectedScenario = scenario
        collectionView.reloadData()
    }
}

extension ScenarioSelectorView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return PayoffScenario.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScenarioCell", for: indexPath) as! ScenarioCell
        let scenario = PayoffScenario.allCases[indexPath.item]
        cell.configure(with: scenario, isSelected: scenario == selectedScenario)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let scenario = PayoffScenario.allCases[indexPath.item]
        selectedScenario = scenario
        collectionView.reloadData()
        delegate?.scenarioSelectorViewDidSelectScenario(scenario)
    }
}

// MARK: - Scenario Cell

class ScenarioCell: UICollectionViewCell {
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
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
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with scenario: PayoffScenario, isSelected: Bool) {
        iconImageView.image = UIImage(systemName: scenario.icon)
        titleLabel.text = scenario.displayName
        
        if isSelected {
            containerView.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
            iconImageView.tintColor = .white
            titleLabel.textColor = .white
        } else {
            containerView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
            iconImageView.tintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
            titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        }
    }
}

// MARK: - Calculator View

protocol CalculatorViewDelegate: AnyObject {
    func calculatorViewDidUpdateInput()
}

class CalculatorView: UIView {
    
    weak var delegate: CalculatorViewDelegate?
    
    private let titleLabel = UILabel()
    private let extraPaymentField = UITextField()
    private let targetDateField = UITextField()
    private let datePicker = UIDatePicker()
    
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
        titleLabel.text = "Calculator Inputs"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Extra payment field
        extraPaymentField.translatesAutoresizingMaskIntoConstraints = false
        extraPaymentField.placeholder = "Extra monthly payment"
        extraPaymentField.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        extraPaymentField.borderStyle = .roundedRect
        extraPaymentField.keyboardType = .decimalPad
        extraPaymentField.addTarget(self, action: #selector(textFieldChanged), for: .editingChanged)
        
        // Target date field
        targetDateField.translatesAutoresizingMaskIntoConstraints = false
        targetDateField.placeholder = "Target payoff date (optional)"
        targetDateField.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        targetDateField.borderStyle = .roundedRect
        targetDateField.isEnabled = false
        
        // Date picker
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.minimumDate = Date()
        datePicker.preferredDatePickerStyle = .compact
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        addSubview(titleLabel)
        addSubview(extraPaymentField)
        addSubview(targetDateField)
        addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            extraPaymentField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            extraPaymentField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            extraPaymentField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            extraPaymentField.heightAnchor.constraint(equalToConstant: 44),
            
            targetDateField.topAnchor.constraint(equalTo: extraPaymentField.bottomAnchor, constant: 16),
            targetDateField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            targetDateField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            targetDateField.heightAnchor.constraint(equalToConstant: 44),
            
            datePicker.topAnchor.constraint(equalTo: targetDateField.bottomAnchor, constant: 16),
            datePicker.centerXAnchor.constraint(equalTo: centerXAnchor),
            datePicker.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with debts: [Debt]) {
        self.debts = debts
    }
    
    func getCalculatorInput() -> CalculatorInput {
        let extraPayment = Double(extraPaymentField.text ?? "0") ?? 0
        let targetDate = datePicker.date > Date() ? datePicker.date : nil
        
        return CalculatorInput(
            extraPayment: extraPayment,
            targetPayoffDate: targetDate,
            debtPriorities: [:]
        )
    }
    
    @objc private func textFieldChanged() {
        delegate?.calculatorViewDidUpdateInput()
    }
    
    @objc private func dateChanged() {
        delegate?.calculatorViewDidUpdateInput()
    }
}

// MARK: - Results View

class ResultsView: UIView {
    
    private let titleLabel = UILabel()
    private let resultsStackView = UIStackView()
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
        titleLabel.text = "Payoff Results"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        resultsStackView.translatesAutoresizingMaskIntoConstraints = false
        resultsStackView.axis = .vertical
        resultsStackView.spacing = 12
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.backgroundColor = .clear
        
        addSubview(titleLabel)
        addSubview(resultsStackView)
        addSubview(chartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            resultsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            resultsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            resultsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            chartView.topAnchor.constraint(equalTo: resultsStackView.bottomAnchor, constant: 20),
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            chartView.heightAnchor.constraint(equalToConstant: 200),
            chartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with calculation: PayoffCalculation) {
        // Clear existing results
        resultsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let results = [
            ("Total Debt", String(format: "$%.2f", calculation.totalDebt)),
            ("Total Interest", String(format: "$%.2f", calculation.totalInterest)),
            ("Payoff Time", "\(calculation.payoffTime) months"),
            ("Monthly Payment", String(format: "$%.2f", calculation.monthlyPayment)),
            ("Interest Savings", String(format: "$%.2f", calculation.savings))
        ]
        
        for (title, value) in results {
            let itemView = ResultItemView(title: title, value: value)
            resultsStackView.addArrangedSubview(itemView)
        }
        
        // Configure chart
        let chartData = calculation.monthlyProjections.enumerated().map { index, projection in
            ChartDataPoint(label: "Month \(index + 1)", value: projection.remainingBalance)
        }
        chartView.configure(with: chartData, type: .line)
    }
}

// MARK: - Result Item View

class ResultItemView: UIView {
    
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
        valueLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
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

// MARK: - Comparison View

class ComparisonView: UIView {
    
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
        titleLabel.text = "Strategy Comparison"
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
    
    func configure(with calculation: PayoffCalculation) {
        // Clear existing comparison
        comparisonStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add recommendations
        for recommendation in calculation.recommendations {
            let recommendationView = RecommendationItemView(recommendation: recommendation)
            comparisonStackView.addArrangedSubview(recommendationView)
        }
    }
}

// MARK: - Saved Scenarios View Controller

protocol SavedScenariosViewControllerDelegate: AnyObject {
    func savedScenariosViewControllerDidSelectScenario(_ scenario: SavedScenario)
}

class SavedScenariosViewController: UIViewController {
    
    weak var delegate: SavedScenariosViewControllerDelegate?
    
    private let tableView = UITableView()
    private var scenarios: [SavedScenario] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadScenarios()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        title = "Saved Scenarios"
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SavedScenarioCell.self, forCellReuseIdentifier: "SavedScenarioCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadScenarios() {
        Task {
            do {
                scenarios = try await FinancialDataService.shared.getSavedScenarios()
                await MainActor.run {
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension SavedScenariosViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scenarios.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SavedScenarioCell", for: indexPath) as! SavedScenarioCell
        cell.configure(with: scenarios[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.savedScenariosViewControllerDidSelectScenario(scenarios[indexPath.row])
    }
}

// MARK: - Saved Scenario Cell

class SavedScenarioCell: UITableViewCell {
    
    private let nameLabel = UILabel()
    private let scenarioLabel = UILabel()
    private let dateLabel = UILabel()
    private let resultsLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        scenarioLabel.translatesAutoresizingMaskIntoConstraints = false
        scenarioLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        scenarioLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        dateLabel.alpha = 0.7
        
        resultsLabel.translatesAutoresizingMaskIntoConstraints = false
        resultsLabel.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        resultsLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        contentView.addSubview(nameLabel)
        contentView.addSubview(scenarioLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(resultsLabel)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            scenarioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            scenarioLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            scenarioLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: scenarioLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            resultsLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            resultsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with scenario: SavedScenario) {
        nameLabel.text = scenario.name
        scenarioLabel.text = scenario.scenario.displayName
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        dateLabel.text = formatter.string(from: scenario.createdAt)
        
        resultsLabel.text = String(format: "$%.0f saved", scenario.calculation.savings)
    }
}
