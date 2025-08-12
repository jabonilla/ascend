import UIKit

class DebtsViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let tableView = UITableView()
    private let emptyStateView = EmptyStateView()
    private let addButton = UIBarButtonItem()
    
    // MARK: - Data
    
    private var debts: [Debt] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadDebts()
        AnalyticsService.shared.trackScreenView("Debts")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DebtCell.self, forCellReuseIdentifier: "DebtCell")
        
        // Empty state view
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.configure(
            title: "No Debts Added",
            message: "Add your first debt to get started with optimization",
            buttonTitle: "Add Debt",
            icon: "creditcard"
        )
        emptyStateView.delegate = self
        
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        
        setupConstraints()
    }
    
    private func setupNavigationBar() {
        title = "Debts"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        addButton.image = UIImage(systemName: "plus")
        addButton.target = self
        addButton.action = #selector(addDebtTapped)
        navigationItem.rightBarButtonItem = addButton
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Table view
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Empty state view
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadDebts() {
        Task {
            do {
                debts = try await FinancialDataService.shared.fetchDebts()
                updateUI()
            } catch {
                showError(error)
            }
        }
    }
    
    private func updateUI() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !debts.isEmpty
        tableView.isHidden = debts.isEmpty
    }
    
    // MARK: - Actions
    
    @objc private func addDebtTapped() {
        let addDebtVC = AddDebtViewController()
        addDebtVC.delegate = self
        let nav = UINavigationController(rootViewController: addDebtVC)
        present(nav, animated: true)
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

// MARK: - UITableViewDataSource

extension DebtsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return debts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DebtCell", for: indexPath) as! DebtCell
        cell.configure(with: debts[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension DebtsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let debt = debts[indexPath.row]
        let debtDetailVC = DebtDetailViewController(debt: debt)
        navigationController?.pushViewController(debtDetailVC, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let debt = debts[indexPath.row]
            deleteDebt(debt)
        }
    }
    
    private func deleteDebt(_ debt: Debt) {
        let alert = UIAlertController(
            title: "Delete Debt",
            message: "Are you sure you want to delete '\(debt.name)'?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            Task {
                do {
                    try await FinancialDataService.shared.deleteDebt(debt.id)
                    self.loadDebts()
                } catch {
                    self.showError(error)
                }
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - EmptyStateViewDelegate

extension DebtsViewController: EmptyStateViewDelegate {
    func emptyStateViewDidTapButton() {
        addDebtTapped()
    }
}

// MARK: - AddDebtViewControllerDelegate

extension DebtsViewController: AddDebtViewControllerDelegate {
    func addDebtViewControllerDidAddDebt(_ debt: Debt) {
        loadDebts()
    }
}

// MARK: - Debt Cell

class DebtCell: UITableViewCell {
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let balanceLabel = UILabel()
    private let aprLabel = UILabel()
    private let progressView = UIProgressView()
    
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
        
        // Container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        
        // Icon image view
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        iconImageView.layer.cornerRadius = 20
        
        // Name label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Balance label
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        balanceLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // APR label
        aprLabel.translatesAutoresizingMaskIntoConstraints = false
        aprLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        aprLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        progressView.trackTintColor = UIColor(named: "MistBackground") ?? .systemGray6
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(balanceLabel)
        containerView.addSubview(aprLabel)
        containerView.addSubview(progressView)
        contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Icon image view
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            // Name label
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Balance label
            balanceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            balanceLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            
            // APR label
            balanceLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            aprLabel.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor),
            aprLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])
    }
    
    func configure(with debt: Debt) {
        nameLabel.text = debt.name
        balanceLabel.text = String(format: "$%.2f", debt.currentBalance)
        aprLabel.text = String(format: "%.1f%% APR", debt.apr)
        
        iconImageView.image = UIImage(systemName: debt.type.icon)
        
        let progress = Float(debt.progressPercentage / 100.0)
        progressView.setProgress(progress, animated: false)
    }
}

// MARK: - Empty State View

protocol EmptyStateViewDelegate: AnyObject {
    func emptyStateViewDidTapButton()
}

class EmptyStateView: UIView {
    
    weak var delegate: EmptyStateViewDelegate?
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Icon image view
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.textAlignment = .center
        
        // Message label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        messageLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        // Action button
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // Message label
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // Action button
            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            actionButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 48),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(title: String, message: String, buttonTitle: String, icon: String) {
        titleLabel.text = title
        messageLabel.text = message
        actionButton.setTitle(buttonTitle, for: .normal)
        iconImageView.image = UIImage(systemName: icon)
    }
    
    @objc private func buttonTapped() {
        delegate?.emptyStateViewDidTapButton()
    }
}
