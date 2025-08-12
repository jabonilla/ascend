import UIKit

protocol OptimizationCardViewDelegate: AnyObject {
    func optimizationCardViewDidTapOptimize()
    func optimizationCardViewDidTapViewStrategy()
}

class OptimizationCardView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: OptimizationCardViewDelegate?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let optimizeButton = UIButton(type: .system)
    private let viewStrategyButton = UIButton(type: .system)
    private let savingsLabel = UILabel()
    
    // MARK: - Data
    
    private var debts: [Debt] = []
    
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
        titleLabel.text = "AI Optimization"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Description label
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = "Get personalized payment strategies to pay off debt faster and save on interest."
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        descriptionLabel.numberOfLines = 0
        
        // Savings label
        savingsLabel.translatesAutoresizingMaskIntoConstraints = false
        savingsLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        savingsLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        savingsLabel.textAlignment = .center
        
        // Optimize button
        optimizeButton.translatesAutoresizingMaskIntoConstraints = false
        optimizeButton.setTitle("Optimize Now", for: .normal)
        optimizeButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        optimizeButton.setTitleColor(.white, for: .normal)
        optimizeButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        optimizeButton.layer.cornerRadius = 12
        optimizeButton.addTarget(self, action: #selector(optimizeTapped), for: .touchUpInside)
        
        // View strategy button
        viewStrategyButton.translatesAutoresizingMaskIntoConstraints = false
        viewStrategyButton.setTitle("View Strategy", for: .normal)
        viewStrategyButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        viewStrategyButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        viewStrategyButton.backgroundColor = .clear
        viewStrategyButton.layer.borderWidth = 1
        viewStrategyButton.layer.borderColor = (UIColor(named: "PrimaryBlue") ?? .systemBlue).cgColor
        viewStrategyButton.layer.cornerRadius = 12
        viewStrategyButton.addTarget(self, action: #selector(viewStrategyTapped), for: .touchUpInside)
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(savingsLabel)
        addSubview(optimizeButton)
        addSubview(viewStrategyButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Description label
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Savings label
            savingsLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            savingsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            savingsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Optimize button
            optimizeButton.topAnchor.constraint(equalTo: savingsLabel.bottomAnchor, constant: 16),
            optimizeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            optimizeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            optimizeButton.heightAnchor.constraint(equalToConstant: 48),
            
            // View strategy button
            viewStrategyButton.topAnchor.constraint(equalTo: optimizeButton.bottomAnchor, constant: 12),
            viewStrategyButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            viewStrategyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            viewStrategyButton.heightAnchor.constraint(equalToConstant: 44),
            viewStrategyButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Public Methods
    
    func configure(with debts: [Debt]) {
        self.debts = debts
        updateSavingsLabel()
    }
    
    // MARK: - Private Methods
    
    private func updateSavingsLabel() {
        let totalDebt = debts.reduce(0) { $0 + $1.currentBalance }
        let estimatedSavings = totalDebt * 0.15 // 15% estimated savings
        savingsLabel.text = "Potential savings: $\(String(format: "%.0f", estimatedSavings))"
    }
    
    // MARK: - Actions
    
    @objc private func optimizeTapped() {
        delegate?.optimizationCardViewDidTapOptimize()
    }
    
    @objc private func viewStrategyTapped() {
        delegate?.optimizationCardViewDidTapViewStrategy()
    }
}
