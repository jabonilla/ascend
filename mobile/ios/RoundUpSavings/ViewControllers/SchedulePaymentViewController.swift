import UIKit

protocol SchedulePaymentViewControllerDelegate: AnyObject {
    func schedulePaymentViewControllerDidSchedulePayment(_ payment: Payment)
}

class SchedulePaymentViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: SchedulePaymentViewControllerDelegate?
    private var debts: [Debt] = []
    private var selectedDebt: Debt?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let debtSelectionView = DebtSelectionView()
    private let amountView = AmountInputView()
    private let dateView = DateSelectionView()
    private let frequencyView = FrequencySelectionView()
    private let automationView = AutomationView()
    
    private let scheduleButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Data
    
    private var selectedAmount: Double = 0
    private var selectedDate = Date()
    private var selectedFrequency: PaymentFrequency = .oneTime
    private var isAutomated = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        loadDebts()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Debt selection
        debtSelectionView.delegate = self
        debtSelectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Amount input
        amountView.delegate = self
        amountView.translatesAutoresizingMaskIntoConstraints = false
        
        // Date selection
        dateView.delegate = self
        dateView.translatesAutoresizingMaskIntoConstraints = false
        
        // Frequency selection
        frequencyView.delegate = self
        frequencyView.translatesAutoresizingMaskIntoConstraints = false
        
        // Automation
        automationView.delegate = self
        automationView.translatesAutoresizingMaskIntoConstraints = false
        
        // Schedule button
        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        scheduleButton.setTitle("Schedule Payment", for: .normal)
        scheduleButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        scheduleButton.setTitleColor(.white, for: .normal)
        scheduleButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        scheduleButton.layer.cornerRadius = 12
        scheduleButton.addTarget(self, action: #selector(scheduleTapped), for: .touchUpInside)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        // Add subviews
        contentView.addSubview(debtSelectionView)
        contentView.addSubview(amountView)
        contentView.addSubview(dateView)
        contentView.addSubview(frequencyView)
        contentView.addSubview(automationView)
        contentView.addSubview(scheduleButton)
        view.addSubview(loadingIndicator)
    }
    
    private func setupNavigationBar() {
        title = "Schedule Payment"
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
            
            // Debt selection
            debtSelectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            debtSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            debtSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Amount input
            amountView.topAnchor.constraint(equalTo: debtSelectionView.bottomAnchor, constant: 20),
            amountView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            amountView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Date selection
            dateView.topAnchor.constraint(equalTo: amountView.bottomAnchor, constant: 20),
            dateView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dateView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Frequency selection
            frequencyView.topAnchor.constraint(equalTo: dateView.bottomAnchor, constant: 20),
            frequencyView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            frequencyView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Automation
            automationView.topAnchor.constraint(equalTo: frequencyView.bottomAnchor, constant: 20),
            automationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            automationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Schedule button
            scheduleButton.topAnchor.constraint(equalTo: automationView.bottomAnchor, constant: 30),
            scheduleButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scheduleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scheduleButton.heightAnchor.constraint(equalToConstant: 50),
            scheduleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadDebts() {
        Task {
            do {
                debts = try await FinancialDataService.shared.fetchDebts()
                DispatchQueue.main.async {
                    self.debtSelectionView.configure(with: self.debts)
                }
            } catch {
                showError(error)
            }
        }
    }
    
    // MARK: - Validation
    
    private func validateForm() -> Bool {
        guard selectedDebt != nil else {
            showAlert(title: "Error", message: "Please select a debt")
            return false
        }
        
        guard selectedAmount > 0 else {
            showAlert(title: "Error", message: "Please enter a valid amount")
            return false
        }
        
        return true
    }
    
    private func createPayment() -> Payment? {
        guard validateForm(), let debt = selectedDebt else { return nil }
        
        return Payment(
            id: UUID().uuidString,
            userId: AuthenticationService.shared.getCurrentUser()?.id ?? "",
            debtId: debt.id,
            amount: selectedAmount,
            scheduledDate: selectedDate,
            status: .scheduled,
            frequency: selectedFrequency,
            isAutomated: isAutomated,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // MARK: - Actions
    
    @objc private func scheduleTapped() {
        guard let payment = createPayment() else { return }
        
        loadingIndicator.startAnimating()
        scheduleButton.isEnabled = false
        
        Task {
            do {
                let savedPayment = try await FinancialDataService.shared.schedulePayment(payment)
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.scheduleButton.isEnabled = true
                    self.delegate?.schedulePaymentViewControllerDidSchedulePayment(savedPayment)
                    self.dismiss(animated: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.scheduleButton.isEnabled = true
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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

// MARK: - Debt Selection Delegate

extension SchedulePaymentViewController: DebtSelectionViewDelegate {
    func debtSelectionViewDidSelectDebt(_ debt: Debt) {
        selectedDebt = debt
        amountView.setMinimumAmount(debt.minimumPayment)
        amountView.setSuggestedAmount(debt.minimumPayment)
    }
}

// MARK: - Amount Input Delegate

extension SchedulePaymentViewController: AmountInputViewDelegate {
    func amountInputViewDidChangeAmount(_ amount: Double) {
        selectedAmount = amount
    }
}

// MARK: - Date Selection Delegate

extension SchedulePaymentViewController: DateSelectionViewDelegate {
    func dateSelectionViewDidSelectDate(_ date: Date) {
        selectedDate = date
    }
}

// MARK: - Frequency Selection Delegate

extension SchedulePaymentViewController: FrequencySelectionViewDelegate {
    func frequencySelectionViewDidSelectFrequency(_ frequency: PaymentFrequency) {
        selectedFrequency = frequency
    }
}

// MARK: - Automation Delegate

extension SchedulePaymentViewController: AutomationViewDelegate {
    func automationViewDidToggleAutomation(_ isEnabled: Bool) {
        isAutomated = isEnabled
    }
}

// MARK: - Supporting Views

protocol DebtSelectionViewDelegate: AnyObject {
    func debtSelectionViewDidSelectDebt(_ debt: Debt)
}

class DebtSelectionView: UIView {
    
    weak var delegate: DebtSelectionViewDelegate?
    
    private let titleLabel = UILabel()
    private let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var debts: [Debt] = []
    private var selectedIndex: Int?
    
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
        titleLabel.text = "Select Debt"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(DebtSelectionCell.self, forCellWithReuseIdentifier: "DebtSelectionCell")
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: 200, height: 80)
            layout.minimumInteritemSpacing = 12
            layout.minimumLineSpacing = 12
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        }
        
        addSubview(titleLabel)
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 100),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with debts: [Debt]) {
        self.debts = debts
        collectionView.reloadData()
    }
}

extension DebtSelectionView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return debts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DebtSelectionCell", for: indexPath) as! DebtSelectionCell
        cell.configure(with: debts[indexPath.row], isSelected: selectedIndex == indexPath.row)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        collectionView.reloadData()
        delegate?.debtSelectionViewDidSelectDebt(debts[indexPath.row])
    }
}

class DebtSelectionCell: UICollectionViewCell {
    
    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let balanceLabel = UILabel()
    private let checkmarkView = UIImageView()
    
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
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor.clear.cgColor
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        nameLabel.numberOfLines = 1
        
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        balanceLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkView.tintColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        checkmarkView.isHidden = true
        
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(checkmarkView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: checkmarkView.leadingAnchor, constant: -8),
            
            balanceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            balanceLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            balanceLabel.trailingAnchor.constraint(equalTo: checkmarkView.leadingAnchor, constant: -8),
            
            checkmarkView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkmarkView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with debt: Debt, isSelected: Bool) {
        nameLabel.text = debt.name
        balanceLabel.text = String(format: "$%.2f", debt.currentBalance)
        
        if isSelected {
            containerView.layer.borderColor = UIColor(named: "PrimaryBlue")?.cgColor
            checkmarkView.isHidden = false
        } else {
            containerView.layer.borderColor = UIColor.clear.cgColor
            checkmarkView.isHidden = true
        }
    }
}

// MARK: - Amount Input View

protocol AmountInputViewDelegate: AnyObject {
    func amountInputViewDidChangeAmount(_ amount: Double)
}

class AmountInputView: UIView {
    
    weak var delegate: AmountInputViewDelegate?
    
    private let titleLabel = UILabel()
    private let amountTextField = UITextField()
    private let suggestedAmountsStackView = UIStackView()
    private var currentAmount: Double = 0
    
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
        titleLabel.text = "Payment Amount"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.placeholder = "$0.00"
        amountTextField.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        amountTextField.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        amountTextField.keyboardType = .decimalPad
        amountTextField.textAlignment = .center
        amountTextField.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        amountTextField.layer.cornerRadius = 12
        amountTextField.delegate = self
        
        suggestedAmountsStackView.translatesAutoresizingMaskIntoConstraints = false
        suggestedAmountsStackView.axis = .horizontal
        suggestedAmountsStackView.distribution = .fillEqually
        suggestedAmountsStackView.spacing = 12
        
        addSubview(titleLabel)
        addSubview(amountTextField)
        addSubview(suggestedAmountsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            amountTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            amountTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            amountTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            amountTextField.heightAnchor.constraint(equalToConstant: 60),
            
            suggestedAmountsStackView.topAnchor.constraint(equalTo: amountTextField.bottomAnchor, constant: 16),
            suggestedAmountsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            suggestedAmountsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            suggestedAmountsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func setMinimumAmount(_ amount: Double) {
        addSuggestedAmount(amount, title: "Min")
    }
    
    func setSuggestedAmount(_ amount: Double) {
        addSuggestedAmount(amount, title: "Suggested")
    }
    
    private func addSuggestedAmount(_ amount: Double, title: String) {
        let button = UIButton(type: .system)
        button.setTitle("\(title)\n$\(String(format: "%.0f", amount))", for: .normal)
        button.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        button.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        button.layer.cornerRadius = 8
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(suggestedAmountTapped(_:)), for: .touchUpInside)
        button.tag = Int(amount)
        
        suggestedAmountsStackView.addArrangedSubview(button)
    }
    
    @objc private func suggestedAmountTapped(_ sender: UIButton) {
        let amount = Double(sender.tag)
        amountTextField.text = String(format: "%.2f", amount)
        currentAmount = amount
        delegate?.amountInputViewDidChangeAmount(amount)
    }
}

extension AmountInputView: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string) ?? ""
        
        if let amount = Double(newText) {
            currentAmount = amount
            delegate?.amountInputViewDidChangeAmount(amount)
        }
        
        return true
    }
}

// MARK: - Date Selection View

protocol DateSelectionViewDelegate: AnyObject {
    func dateSelectionViewDidSelectDate(_ date: Date)
}

class DateSelectionView: UIView {
    
    weak var delegate: DateSelectionViewDelegate?
    
    private let titleLabel = UILabel()
    private let datePicker = UIDatePicker()
    
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
        titleLabel.text = "Payment Date"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.minimumDate = Date()
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        addSubview(titleLabel)
        addSubview(datePicker)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            datePicker.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            datePicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            datePicker.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            datePicker.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func dateChanged() {
        delegate?.dateSelectionViewDidSelectDate(datePicker.date)
    }
}

// MARK: - Frequency Selection View

protocol FrequencySelectionViewDelegate: AnyObject {
    func frequencySelectionViewDidSelectFrequency(_ frequency: PaymentFrequency)
}

class FrequencySelectionView: UIView {
    
    weak var delegate: FrequencySelectionViewDelegate?
    
    private let titleLabel = UILabel()
    private let segmentedControl = UISegmentedControl()
    
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
        titleLabel.text = "Payment Frequency"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.insertSegment(withTitle: "One Time", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Monthly", at: 1, animated: false)
        segmentedControl.insertSegment(withTitle: "Weekly", at: 2, animated: false)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        segmentedControl.selectedSegmentTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        segmentedControl.addTarget(self, action: #selector(frequencyChanged), for: .valueChanged)
        
        addSubview(titleLabel)
        addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func frequencyChanged() {
        let frequencies: [PaymentFrequency] = [.oneTime, .monthly, .weekly]
        delegate?.frequencySelectionViewDidSelectFrequency(frequencies[segmentedControl.selectedSegmentIndex])
    }
}

// MARK: - Automation View

protocol AutomationViewDelegate: AnyObject {
    func automationViewDidToggleAutomation(_ isEnabled: Bool)
}

class AutomationView: UIView {
    
    weak var delegate: AutomationViewDelegate?
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let toggleSwitch = UISwitch()
    
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
        titleLabel.text = "Automate Payment"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = "Automatically process this payment on the scheduled date"
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        descriptionLabel.numberOfLines = 0
        
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.onTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(toggleSwitch)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -16),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            toggleSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }
    
    @objc private func toggleChanged() {
        delegate?.automationViewDidToggleAutomation(toggleSwitch.isOn)
    }
}

// MARK: - Supporting Types

enum PaymentFrequency: String, CaseIterable {
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
