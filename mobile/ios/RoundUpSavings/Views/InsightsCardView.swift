import UIKit

protocol InsightsCardViewDelegate: AnyObject {
    func insightsCardViewDidTapInsight(_ insight: Insight)
}

class InsightsCardView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: InsightsCardViewDelegate?
    
    // MARK: - UI Components
    
    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Data
    
    private var insights: [Insight] = []
    private let layout = UICollectionViewFlowLayout()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
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
        titleLabel.text = "AI Insights"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Collection view
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(InsightCell.self, forCellWithReuseIdentifier: "InsightCell")
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        
        addSubview(titleLabel)
        addSubview(collectionView)
        addSubview(loadingIndicator)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            // Collection view
            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 120),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // MARK: - Public Methods
    
    func loadInsights() {
        loadingIndicator.startAnimating()
        
        // Simulate loading insights from API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.insights = self.generateMockInsights()
            self.loadingIndicator.stopAnimating()
            self.collectionView.reloadData()
        }
    }
    
    // MARK: - Private Methods
    
    private func generateMockInsights() -> [Insight] {
        return [
            Insight(
                id: "1",
                title: "High Interest Alert",
                message: "Your credit card has 22% APR. Consider paying extra to save $1,200 annually.",
                type: .warning,
                priority: .high
            ),
            Insight(
                id: "2",
                title: "Payment Optimization",
                message: "Paying $200 extra on your student loan could save you 8 months of payments.",
                type: .recommendation,
                priority: .medium
            ),
            Insight(
                id: "3",
                title: "Great Progress!",
                message: "You've paid off 15% of your total debt this month. Keep it up!",
                type: .celebration,
                priority: .low
            )
        ]
    }
}

// MARK: - UICollectionViewDataSource

extension InsightsCardView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return insights.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InsightCell", for: indexPath) as! InsightCell
        cell.configure(with: insights[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension InsightsCardView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let insight = insights[indexPath.item]
        delegate?.insightsCardViewDidTapInsight(insight)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension InsightsCardView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 280, height: 100)
    }
}

// MARK: - Insight Model

struct Insight {
    let id: String
    let title: String
    let message: String
    let type: InsightType
    let priority: InsightPriority
    
    enum InsightType {
        case warning
        case recommendation
        case celebration
        case education
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle"
            case .recommendation: return "lightbulb"
            case .celebration: return "party.popper"
            case .education: return "book"
            }
        }
        
        var color: UIColor {
            switch self {
            case .warning: return UIColor(named: "WarningOrange") ?? .systemOrange
            case .recommendation: return UIColor(named: "PrimaryBlue") ?? .systemBlue
            case .celebration: return UIColor(named: "SecondaryLime") ?? .systemGreen
            case .education: return UIColor(named: "AccentLavender") ?? .systemPurple
            }
        }
    }
    
    enum InsightPriority {
        case high
        case medium
        case low
    }
}

// MARK: - Insight Cell

class InsightCell: UICollectionViewCell {
    
    // MARK: - UI Components
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
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
        backgroundColor = .clear
        
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
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        titleLabel.numberOfLines = 1
        
        // Message label
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        messageLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        messageLabel.numberOfLines = 2
        
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        contentView.addSubview(containerView)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Icon image view
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Message label
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with insight: Insight) {
        titleLabel.text = insight.title
        messageLabel.text = insight.message
        
        iconImageView.image = UIImage(systemName: insight.type.icon)
        iconImageView.backgroundColor = insight.type.color
        iconImageView.layer.cornerRadius = 12
    }
}
