import UIKit
import WebKit

class BankConnectionViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    private let benefitsView = ConnectionBenefitsView()
    private let securityView = SecurityInfoView()
    
    private let connectButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let webView = WKWebView()
    
    // MARK: - Data
    
    private var linkToken: PlaidLinkToken?
    private var isConnecting = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        setupWebView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AnalyticsService.shared.trackScreenView("BankConnection")
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
        
        // Benefits view
        benefitsView.translatesAutoresizingMaskIntoConstraints = false
        
        // Security view
        securityView.translatesAutoresizingMaskIntoConstraints = false
        
        // Connect button
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.setTitle("Connect Bank Account", for: .normal)
        connectButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        connectButton.layer.cornerRadius = 12
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        
        // Skip button
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("Skip for now", for: .normal)
        skipButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        skipButton.setTitleColor(UIColor(named: "AccentLavender") ?? .darkGray, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = UIColor(named: "PrimaryBlue") ?? .systemBlue
        
        // Web view (hidden initially)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isHidden = true
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(benefitsView)
        contentView.addSubview(securityView)
        contentView.addSubview(connectButton)
        contentView.addSubview(skipButton)
        view.addSubview(loadingIndicator)
        view.addSubview(webView)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Connect Your Bank"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Securely connect your accounts to automatically discover and track your debts"
        subtitleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .white
        subtitleLabel.alpha = 0.9
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupNavigationBar() {
        title = "Bank Connection"
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
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // Benefits view
            benefitsView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            benefitsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            benefitsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Security view
            securityView.topAnchor.constraint(equalTo: benefitsView.bottomAnchor, constant: 20),
            securityView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            securityView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Connect button
            connectButton.topAnchor.constraint(equalTo: securityView.bottomAnchor, constant: 30),
            connectButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            connectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Web view
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupWebView() {
        webView.configuration.preferences.javaScriptEnabled = true
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    }
    
    // MARK: - Actions
    
    @objc private func connectTapped() {
        guard !isConnecting else { return }
        
        isConnecting = true
        loadingIndicator.startAnimating()
        connectButton.isEnabled = false
        
        Task {
            do {
                linkToken = try await FinancialDataService.shared.createPlaidLinkToken()
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.connectButton.isEnabled = true
                    self.isConnecting = false
                    self.startPlaidLink()
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.connectButton.isEnabled = true
                    self.isConnecting = false
                    self.showError(error)
                }
            }
        }
    }
    
    @objc private func skipTapped() {
        AnalyticsService.shared.trackUserAction("bank_connection_skipped")
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func startPlaidLink() {
        guard let linkToken = linkToken else { return }
        
        // Create Plaid Link configuration
        let linkConfiguration = PlaidLinkConfiguration(
            token: linkToken.token,
            onSuccess: { [weak self] publicToken, metadata in
                self?.handlePlaidSuccess(publicToken: publicToken, metadata: metadata)
            },
            onExit: { [weak self] error, metadata in
                self?.handlePlaidExit(error: error, metadata: metadata)
            }
        )
        
        // Show Plaid Link
        showPlaidLink(with: linkConfiguration)
    }
    
    private func showPlaidLink(with configuration: PlaidLinkConfiguration) {
        // In a real implementation, this would use the Plaid Link SDK
        // For now, we'll simulate the flow
        
        webView.isHidden = false
        scrollView.isHidden = true
        
        // Simulate Plaid Link web interface
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
                .container { max-width: 400px; margin: 0 auto; background: white; border-radius: 12px; padding: 24px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { text-align: center; margin-bottom: 24px; }
                .title { font-size: 24px; font-weight: bold; color: #333; margin-bottom: 8px; }
                .subtitle { font-size: 16px; color: #666; }
                .bank-list { margin: 20px 0; }
                .bank-item { display: flex; align-items: center; padding: 16px; border: 1px solid #e0e0e0; border-radius: 8px; margin-bottom: 12px; cursor: pointer; }
                .bank-item:hover { background: #f8f9fa; }
                .bank-logo { width: 40px; height: 40px; background: #007AFF; border-radius: 8px; margin-right: 16px; }
                .bank-name { font-weight: 600; color: #333; }
                .success { background: #34C759; color: white; padding: 16px; border-radius: 8px; text-align: center; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="title">Select Your Bank</div>
                    <div class="subtitle">Choose the bank you'd like to connect</div>
                </div>
                <div class="bank-list">
                    <div class="bank-item" onclick="selectBank('chase')">
                        <div class="bank-logo"></div>
                        <div class="bank-name">Chase Bank</div>
                    </div>
                    <div class="bank-item" onclick="selectBank('wells')">
                        <div class="bank-logo"></div>
                        <div class="bank-name">Wells Fargo</div>
                    </div>
                    <div class="bank-item" onclick="selectBank('bofa')">
                        <div class="bank-logo"></div>
                        <div class="bank-name">Bank of America</div>
                    </div>
                </div>
            </div>
            <script>
                function selectBank(bank) {
                    document.body.innerHTML = '<div class="container"><div class="success">Successfully connected to ' + bank + '!</div></div>';
                    setTimeout(() => {
                        window.webkit.messageHandlers.plaidSuccess.postMessage({bank: bank});
                    }, 2000);
                }
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    private func handlePlaidSuccess(publicToken: String, metadata: [String: Any]) {
        AnalyticsService.shared.trackUserAction("plaid_connection_success", properties: metadata)
        
        Task {
            do {
                try await FinancialDataService.shared.exchangePlaidToken(publicToken)
                
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
    
    private func handlePlaidExit(error: Error?, metadata: [String: Any]) {
        webView.isHidden = true
        scrollView.isHidden = false
        
        if let error = error {
            AnalyticsService.shared.trackUserAction("plaid_connection_error", properties: ["error": error.localizedDescription])
            showError(error)
        } else {
            AnalyticsService.shared.trackUserAction("plaid_connection_cancelled")
        }
    }
    
    private func showSuccessMessage() {
        let alert = UIAlertController(
            title: "Bank Connected!",
            message: "Your bank account has been successfully connected. We're now analyzing your accounts to discover any debts.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Great!", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Connection Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension BankConnectionViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle Plaid Link navigation
        decisionHandler(.allow)
    }
}

// MARK: - Connection Benefits View

class ConnectionBenefitsView: UIView {
    
    private let titleLabel = UILabel()
    private let benefitsStackView = UIStackView()
    
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
        titleLabel.text = "Why Connect Your Bank?"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        benefitsStackView.translatesAutoresizingMaskIntoConstraints = false
        benefitsStackView.axis = .vertical
        benefitsStackView.spacing = 16
        
        let benefits = [
            ("Automatic Debt Discovery", "We'll automatically find and categorize your debts from your accounts"),
            ("Real-time Updates", "Get instant updates when payments are processed or balances change"),
            ("Smart Recommendations", "Receive personalized debt payoff strategies based on your actual data"),
            ("Secure & Private", "Bank-level security with read-only access to your accounts")
        ]
        
        for (title, description) in benefits {
            let benefitView = BenefitItemView(title: title, description: description)
            benefitsStackView.addArrangedSubview(benefitView)
        }
        
        addSubview(titleLabel)
        addSubview(benefitsStackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            benefitsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            benefitsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            benefitsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            benefitsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
}

// MARK: - Benefit Item View

class BenefitItemView: UIView {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    init(title: String, description: String) {
        super.init(frame: .zero)
        setupView()
        configure(title: title, description: description)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
        iconImageView.tintColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        descriptionLabel.alpha = 0.7
        descriptionLabel.numberOfLines = 0
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(title: String, description: String) {
        titleLabel.text = title
        descriptionLabel.text = description
    }
}

// MARK: - Security Info View

class SecurityInfoView: UIView {
    
    private let titleLabel = UILabel()
    private let securityLabel = UILabel()
    private let securityIcon = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = UIColor(named: "SecondaryLime")?.withAlphaComponent(0.1) ?? UIColor.systemGreen.withAlphaComponent(0.1)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor(named: "SecondaryLime")?.withAlphaComponent(0.3) ?? UIColor.systemGreen.withAlphaComponent(0.3)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "🔒 Bank-Level Security"
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = UIColor(named: "SecondaryLime") ?? .systemGreen
        
        securityLabel.translatesAutoresizingMaskIntoConstraints = false
        securityLabel.text = "Your data is encrypted and secure. We use read-only access and never store your banking credentials."
        securityLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        securityLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        securityLabel.numberOfLines = 0
        
        addSubview(titleLabel)
        addSubview(securityLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            securityLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            securityLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            securityLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            securityLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
}

// MARK: - Supporting Types

struct PlaidLinkToken: Codable {
    let token: String
    let expiration: Date
}

struct PlaidLinkConfiguration {
    let token: String
    let onSuccess: (String, [String: Any]) -> Void
    let onExit: (Error?, [String: Any]) -> Void
}
