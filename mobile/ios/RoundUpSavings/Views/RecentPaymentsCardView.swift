import UIKit

protocol RecentPaymentsCardViewDelegate: AnyObject {
    func recentPaymentsCardViewDidTapPayment(_ payment: Payment)
    func recentPaymentsCardViewDidTapViewAll()
}

class RecentPaymentsCardView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: RecentPaymentsCardViewDelegate?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let viewAllButton = UIButton(type: .system)
    private let tableView = UITableView()
    
    // MARK: - Data
    
    private var payments: [Payment] = []
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Recent Payments"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // View all button
        viewAllButton.translatesAutoresizingMaskIntoConstraints = false
        viewAllButton.setTitle("View All", for: .normal)
        viewAllButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        viewAllButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        viewAllButton.addTarget(self, action: #selector(viewAllTapped), for: .touchUpInside)
        
        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PaymentCell.self, forCellReuseIdentifier: "PaymentCell")
        
        addSubview(titleLabel)
        addSubview(viewAllButton)
        addSubview(tableView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            
            // View all button
            viewAllButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            viewAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Table view
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            tableView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    // MARK: - Public Methods
    
    func configure(with payments: [Payment]) {
        self.payments = Array(payments.prefix(3)) // Show only 3 most recent
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func viewAllTapped() {
        delegate?.recentPaymentsCardViewDidTapViewAll()
    }
}

// MARK: - UITableViewDataSource

extension RecentPaymentsCardView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return payments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PaymentCell", for: indexPath) as! PaymentCell
        cell.configure(with: payments[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension RecentPaymentsCardView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let payment = payments[indexPath.row]
        delegate?.recentPaymentsCardViewDidTapPayment(payment)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
}

// MARK: - Payment Cell

class PaymentCell: UITableViewCell {
    
    private let containerView = UIView()
    private let debtNameLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusLabel = UILabel()
    private let dateLabel = UILabel()
    
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
        containerView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        containerView.layer.cornerRadius = 8
        
        // Debt name label
        debtNameLabel.translatesAutoresizingMaskIntoConstraints = false
        debtNameLabel.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        debtNameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Amount label
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.font = UIFont(name: "Satoshi-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        amountLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        amountLabel.textAlignment = .right
        
        // Status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        statusLabel.textAlignment = .right
        
        // Date label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        dateLabel.textAlignment = .right
        
        containerView.addSubview(debtNameLabel)
        containerView.addSubview(amountLabel)
        containerView.addSubview(statusLabel)
        containerView.addSubview(dateLabel)
        contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Debt name label
            debtNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            debtNameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            debtNameLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.4),
            
            // Amount label
            amountLabel.leadingAnchor.constraint(equalTo: debtNameLabel.trailingAnchor, constant: 8),
            amountLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            amountLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.25),
            
            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: amountLabel.trailingAnchor, constant: 8),
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Date label
            dateLabel.leadingAnchor.constraint(equalTo: amountLabel.trailingAnchor, constant: 8),
            dateLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            dateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(with payment: Payment) {
        debtNameLabel.text = "Payment" // In real app, would get debt name
        amountLabel.text = payment.formattedAmount
        statusLabel.text = payment.status.displayName
        statusLabel.textColor = payment.status.color
        dateLabel.text = payment.formattedScheduledDate
    }
}
