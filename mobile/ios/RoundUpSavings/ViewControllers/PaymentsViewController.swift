import UIKit

class PaymentsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let totalPaidLabel = UILabel()
    private let totalPaidAmountLabel = UILabel()
    private let thisMonthLabel = UILabel()
    private let thisMonthAmountLabel = UILabel()
    
    private let segmentedControl = UISegmentedControl()
    
    private let scheduledPaymentsView = ScheduledPaymentsView()
    private let paymentHistoryView = PaymentHistoryView()
    
    private let addPaymentButton = UIButton(type: .system)
    
    // MARK: - Data
    
    private var payments: [Payment] = []
    private var scheduledPayments: [Payment] = []
    private var completedPayments: [Payment] = []
    private var currentView: PaymentViewType = .scheduled
    
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
        AnalyticsService.shared.trackScreenView("Payments")
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
        
        // Segmented control
        setupSegmentedControl()
        
        // Payment views
        scheduledPaymentsView.translatesAutoresizingMaskIntoConstraints = false
        scheduledPaymentsView.delegate = self
        
        paymentHistoryView.translatesAutoresizingMaskIntoConstraints = false
        paymentHistoryView.delegate = self
        
        // Add payment button
        addPaymentButton.translatesAutoresizingMaskIntoConstraints = false
        addPaymentButton.setTitle("Schedule Payment", for: .normal)
        addPaymentButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        addPaymentButton.setTitleColor(.white, for: .normal)
        addPaymentButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        addPaymentButton.layer.cornerRadius = 12
        addPaymentButton.addTarget(self, action: #selector(addPaymentTapped), for: .touchUpInside)
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(segmentedControl)
        contentView.addSubview(scheduledPaymentsView)
        contentView.addSubview(paymentHistoryView)
        contentView.addSubview(addPaymentButton)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        totalPaidLabel.translatesAutoresizingMaskIntoConstraints = false
        totalPaidLabel.text = "Total Paid"
        totalPaidLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        totalPaidLabel.textColor = .white
        totalPaidLabel.alpha = 0.9
        
        totalPaidAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        totalPaidAmountLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        totalPaidAmountLabel.textColor = .white
        totalPaidAmountLabel.text = "$0.00"
        
        thisMonthLabel.translatesAutoresizingMaskIntoConstraints = false
        thisMonthLabel.text = "This Month"
        thisMonthLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        thisMonthLabel.textColor = .white
        thisMonthLabel.alpha = 0.9
        
        thisMonthAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        thisMonthAmountLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        thisMonthAmountLabel.textColor = .white
        thisMonthAmountLabel.text = "$0.00"
        
        headerView.addSubview(totalPaidLabel)
        headerView.addSubview(totalPaidAmountLabel)
        headerView.addSubview(thisMonthLabel)
        headerView.addSubview(thisMonthAmountLabel)
    }
    
    private func setupSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.insertSegment(withTitle: "Scheduled", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "History", at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = .white
        segmentedControl.selectedSegmentTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor(named: "AccentLavender") ?? .darkGray
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: .white
        ], for: .selected)
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
    }
    
    private func setupNavigationBar() {
        title = "Payments"
        navigationController?.navigationBar.prefersLargeTitles = true
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
            
            totalPaidLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            totalPaidLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            totalPaidAmountLabel.topAnchor.constraint(equalTo: totalPaidLabel.bottomAnchor, constant: 4),
            totalPaidAmountLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            
            thisMonthLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            thisMonthLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            thisMonthAmountLabel.topAnchor.constraint(equalTo: thisMonthLabel.bottomAnchor, constant: 4),
            thisMonthAmountLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // Segmented control
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 40),
            
            // Payment views
            scheduledPaymentsView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            scheduledPaymentsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scheduledPaymentsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            paymentHistoryView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            paymentHistoryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            paymentHistoryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            paymentHistoryView.isHidden = true,
            
            // Add payment button
            addPaymentButton.topAnchor.constraint(equalTo: scheduledPaymentsView.bottomAnchor, constant: 20),
            addPaymentButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            addPaymentButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addPaymentButton.heightAnchor.constraint(equalToConstant: 50),
            addPaymentButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await loadPayments()
            await updatePaymentStats()
        }
    }
    
    private func loadPayments() async {
        do {
            payments = try await FinancialDataService.shared.fetchPayments()
            
            // Separate payments by status
            scheduledPayments = payments.filter { $0.status == .scheduled }
            completedPayments = payments.filter { $0.status == .completed }
            
            DispatchQueue.main.async {
                self.scheduledPaymentsView.configure(with: self.scheduledPayments)
                self.paymentHistoryView.configure(with: self.completedPayments)
            }
        } catch {
            showError(error)
        }
    }
    
    private func updatePaymentStats() async {
        let totalPaid = completedPayments.reduce(0) { $0 + $1.amount }
        
        let calendar = Calendar.current
        let thisMonth = calendar.component(.month, from: Date())
        let thisYear = calendar.component(.year, from: Date())
        
        let thisMonthPayments = completedPayments.filter { payment in
            let paymentMonth = calendar.component(.month, from: payment.executedDate ?? payment.scheduledDate)
            let paymentYear = calendar.component(.year, from: payment.executedDate ?? payment.scheduledDate)
            return paymentMonth == thisMonth && paymentYear == thisYear
        }
        
        let thisMonthTotal = thisMonthPayments.reduce(0) { $0 + $1.amount }
        
        DispatchQueue.main.async {
            self.totalPaidAmountLabel.text = String(format: "$%.2f", totalPaid)
            self.thisMonthAmountLabel.text = String(format: "$%.2f", thisMonthTotal)
        }
    }
    
    // MARK: - Actions
    
    @objc private func segmentChanged() {
        currentView = segmentedControl.selectedSegmentIndex == 0 ? .scheduled : .history
        scheduledPaymentsView.isHidden = currentView == .history
        paymentHistoryView.isHidden = currentView == .scheduled
    }
    
    @objc private func addPaymentTapped() {
        let schedulePaymentVC = SchedulePaymentViewController()
        schedulePaymentVC.delegate = self
        let navController = UINavigationController(rootViewController: schedulePaymentVC)
        present(navController, animated: true)
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

// MARK: - Schedule Payment Delegate

extension PaymentsViewController: SchedulePaymentViewControllerDelegate {
    func schedulePaymentViewControllerDidSchedulePayment(_ payment: Payment) {
        loadData()
    }
}

// MARK: - Scheduled Payments Delegate

extension PaymentsViewController: ScheduledPaymentsViewDelegate {
    func scheduledPaymentsViewDidTapPayment(_ payment: Payment) {
        let paymentDetailVC = PaymentDetailViewController(payment: payment)
        navigationController?.pushViewController(paymentDetailVC, animated: true)
    }
    
    func scheduledPaymentsViewDidCancelPayment(_ payment: Payment) {
        let alert = UIAlertController(
            title: "Cancel Payment",
            message: "Are you sure you want to cancel this payment?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel))
        alert.addAction(UIAlertAction(title: "Yes, Cancel", style: .destructive) { _ in
            Task {
                do {
                    try await FinancialDataService.shared.cancelPayment(payment.id)
                    self.loadData()
                } catch {
                    self.showError(error)
                }
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Payment History Delegate

extension PaymentsViewController: PaymentHistoryViewDelegate {
    func paymentHistoryViewDidTapPayment(_ payment: Payment) {
        let paymentDetailVC = PaymentDetailViewController(payment: payment)
        navigationController?.pushViewController(paymentDetailVC, animated: true)
    }
}

// MARK: - Supporting Types

enum PaymentViewType {
    case scheduled
    case history
}

// MARK: - Scheduled Payments View

protocol ScheduledPaymentsViewDelegate: AnyObject {
    func scheduledPaymentsViewDidTapPayment(_ payment: Payment)
    func scheduledPaymentsViewDidCancelPayment(_ payment: Payment)
}

class ScheduledPaymentsView: UIView {
    
    weak var delegate: ScheduledPaymentsViewDelegate?
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    
    private var payments: [Payment] = []
    
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
        titleLabel.text = "Scheduled Payments"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ScheduledPaymentCell.self, forCellReuseIdentifier: "ScheduledPaymentCell")
        tableView.isScrollEnabled = false
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.configure(
            title: "No Scheduled Payments",
            message: "Schedule your first payment to get started",
            buttonTitle: "Schedule Payment",
            icon: "calendar.badge.plus"
        )
        emptyStateView.delegate = self
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
    
    func configure(with payments: [Payment]) {
        self.payments = payments
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !payments.isEmpty
        tableView.isHidden = payments.isEmpty
    }
}

extension ScheduledPaymentsView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return payments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScheduledPaymentCell", for: indexPath) as! ScheduledPaymentCell
        cell.configure(with: payments[indexPath.row])
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.scheduledPaymentsViewDidTapPayment(payments[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
}

extension ScheduledPaymentsView: ScheduledPaymentCellDelegate {
    func scheduledPaymentCellDidTapCancel(_ payment: Payment) {
        delegate?.scheduledPaymentsViewDidCancelPayment(payment)
    }
}

extension ScheduledPaymentsView: EmptyStateViewDelegate {
    func emptyStateViewDidTapButton() {
        // This would typically trigger the add payment flow
        // For now, we'll just track the action
        AnalyticsService.shared.trackUserAction("empty_state_schedule_payment_tapped")
    }
}

// MARK: - Payment History View

protocol PaymentHistoryViewDelegate: AnyObject {
    func paymentHistoryViewDidTapPayment(_ payment: Payment)
}

class PaymentHistoryView: UIView {
    
    weak var delegate: PaymentHistoryViewDelegate?
    
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    
    private var payments: [Payment] = []
    
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
        titleLabel.text = "Payment History"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PaymentHistoryCell.self, forCellReuseIdentifier: "PaymentHistoryCell")
        tableView.isScrollEnabled = false
        
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.configure(
            title: "No Payment History",
            message: "Your completed payments will appear here",
            buttonTitle: "Schedule Payment",
            icon: "checkmark.circle"
        )
        emptyStateView.delegate = self
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
    
    func configure(with payments: [Payment]) {
        self.payments = payments
        tableView.reloadData()
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !payments.isEmpty
        tableView.isHidden = payments.isEmpty
    }
}

extension PaymentHistoryView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return payments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PaymentHistoryCell", for: indexPath) as! PaymentHistoryCell
        cell.configure(with: payments[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.paymentHistoryViewDidTapPayment(payments[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

extension PaymentHistoryView: EmptyStateViewDelegate {
    func emptyStateViewDidTapButton() {
        AnalyticsService.shared.trackUserAction("empty_state_history_schedule_payment_tapped")
    }
}

// MARK: - Scheduled Payment Cell

protocol ScheduledPaymentCellDelegate: AnyObject {
    func scheduledPaymentCellDidTapCancel(_ payment: Payment)
}

class ScheduledPaymentCell: UITableViewCell {
    
    weak var delegate: ScheduledPaymentCellDelegate?
    private var payment: Payment?
    
    private let containerView = UIView()
    private let debtNameLabel = UILabel()
    private let amountLabel = UILabel()
    private let dateLabel = UILabel()
    private let statusLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    
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
        
        debtNameLabel.translatesAutoresizingMaskIntoConstraints = false
        debtNameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        debtNameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        amountLabel.textColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        dateLabel.alpha = 0.7
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = UIColor(named: "WarningOrange") ?? .systemOrange
        statusLabel.text = "SCHEDULED"
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        cancelButton.setTitleColor(UIColor.systemRed, for: .normal)
        cancelButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        cancelButton.layer.cornerRadius = 6
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        contentView.addSubview(containerView)
        containerView.addSubview(debtNameLabel)
        containerView.addSubview(amountLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            debtNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            debtNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            debtNameLabel.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -16),
            
            amountLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            amountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: debtNameLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            statusLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            cancelButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cancelButton.widthAnchor.constraint(equalToConstant: 60),
            cancelButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    func configure(with payment: Payment) {
        self.payment = payment
        
        // Load debt name
        Task {
            do {
                let debt = try await FinancialDataService.shared.fetchDebt(payment.debtId)
                DispatchQueue.main.async {
                    self.debtNameLabel.text = debt.name
                }
            } catch {
                DispatchQueue.main.async {
                    self.debtNameLabel.text = "Unknown Debt"
                }
            }
        }
        
        amountLabel.text = payment.formattedAmount
        dateLabel.text = payment.formattedScheduledDate
    }
    
    @objc private func cancelTapped() {
        guard let payment = payment else { return }
        delegate?.scheduledPaymentCellDidTapCancel(payment)
    }
}

// MARK: - Payment History Cell

class PaymentHistoryCell: UITableViewCell {
    
    private let containerView = UIView()
    private let debtNameLabel = UILabel()
    private let amountLabel = UILabel()
    private let dateLabel = UILabel()
    private let statusLabel = UILabel()
    
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
        
        debtNameLabel.translatesAutoresizingMaskIntoConstraints = false
        debtNameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        debtNameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        amountLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        dateLabel.alpha = 0.7
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        statusLabel.text = "COMPLETED"
        
        contentView.addSubview(containerView)
        containerView.addSubview(debtNameLabel)
        containerView.addSubview(amountLabel)
        containerView.addSubview(dateLabel)
        containerView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            debtNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            debtNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            debtNameLabel.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -16),
            
            amountLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            amountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: debtNameLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            statusLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16)
        ])
    }
    
    func configure(with payment: Payment) {
        // Load debt name
        Task {
            do {
                let debt = try await FinancialDataService.shared.fetchDebt(payment.debtId)
                DispatchQueue.main.async {
                    self.debtNameLabel.text = debt.name
                }
            } catch {
                DispatchQueue.main.async {
                    self.debtNameLabel.text = "Unknown Debt"
                }
            }
        }
        
        amountLabel.text = payment.formattedAmount
        dateLabel.text = payment.formattedScheduledDate
    }
}
