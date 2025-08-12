import UIKit

protocol QuickActionsCardViewDelegate: AnyObject {
    func quickActionsCardViewDidTapAddDebt()
    func quickActionsCardViewDidTapSchedulePayment()
    func quickActionsCardViewDidTapConnectBank()
}

class QuickActionsCardView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: QuickActionsCardViewDelegate?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    
    private let addDebtButton = QuickActionButton()
    private let schedulePaymentButton = QuickActionButton()
    private let connectBankButton = QuickActionButton()
    
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
        titleLabel.text = "Quick Actions"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Stack view
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        
        // Setup buttons
        setupButtons()
        
        stackView.addArrangedSubview(addDebtButton)
        stackView.addArrangedSubview(schedulePaymentButton)
        stackView.addArrangedSubview(connectBankButton)
        
        addSubview(titleLabel)
        addSubview(stackView)
        
        setupConstraints()
    }
    
    private func setupButtons() {
        addDebtButton.configure(
            title: "Add Debt",
            icon: "plus.circle.fill",
            color: UIColor(named: "PrimaryBlue") ?? .systemBlue
        )
        addDebtButton.addTarget(self, action: #selector(addDebtTapped), for: .touchUpInside)
        
        schedulePaymentButton.configure(
            title: "Schedule Payment",
            icon: "calendar.badge.plus",
            color: UIColor(named: "SecondaryLime") ?? .systemGreen
        )
        schedulePaymentButton.addTarget(self, action: #selector(schedulePaymentTapped), for: .touchUpInside)
        
        connectBankButton.configure(
            title: "Connect Bank",
            icon: "building.columns.fill",
            color: UIColor(named: "AccentLavender") ?? .systemPurple
        )
        connectBankButton.addTarget(self, action: #selector(connectBankTapped), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func addDebtTapped() {
        delegate?.quickActionsCardViewDidTapAddDebt()
    }
    
    @objc private func schedulePaymentTapped() {
        delegate?.quickActionsCardViewDidTapSchedulePayment()
    }
    
    @objc private func connectBankTapped() {
        delegate?.quickActionsCardViewDidTapConnectBank()
    }
}

// MARK: - Quick Action Button

class QuickActionButton: UIButton {
    
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
        backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        layer.cornerRadius = 12
        
        // Icon image view
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Medium", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
    
    func configure(title: String, icon: String, color: UIColor) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.backgroundColor = color
        iconImageView.layer.cornerRadius = 12
    }
}
