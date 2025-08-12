import UIKit
import LocalAuthentication

class ProfileViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let profileHeaderView = ProfileHeaderView()
    private let subscriptionCard = SubscriptionCard()
    private let settingsTableView = UITableView()
    
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Data
    
    private var user: User?
    private var settingsSections: [SettingsSection] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupConstraints()
        setupSettingsData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserData()
        AnalyticsService.shared.trackScreenView("Profile")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor(named: "MistBackground")
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Refresh control
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        
        // Profile header
        profileHeaderView.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.delegate = self
        
        // Subscription card
        subscriptionCard.translatesAutoresizingMaskIntoConstraints = false
        subscriptionCard.delegate = self
        
        // Settings table
        settingsTableView.translatesAutoresizingMaskIntoConstraints = false
        settingsTableView.backgroundColor = .clear
        settingsTableView.separatorStyle = .none
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.register(SettingsCell.self, forCellReuseIdentifier: "SettingsCell")
        settingsTableView.register(SettingsHeaderView.self, forHeaderFooterViewReuseIdentifier: "SettingsHeaderView")
        settingsTableView.isScrollEnabled = false
        
        // Add subviews
        contentView.addSubview(profileHeaderView)
        contentView.addSubview(subscriptionCard)
        contentView.addSubview(settingsTableView)
    }
    
    private func setupNavigationBar() {
        title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
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
            
            // Profile header
            profileHeaderView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            profileHeaderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            profileHeaderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Subscription card
            subscriptionCard.topAnchor.constraint(equalTo: profileHeaderView.bottomAnchor, constant: 16),
            subscriptionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subscriptionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Settings table
            settingsTableView.topAnchor.constraint(equalTo: subscriptionCard.bottomAnchor, constant: 16),
            settingsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            settingsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            settingsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupSettingsData() {
        settingsSections = [
            SettingsSection(
                title: "Account",
                items: [
                    SettingsItem(title: "Personal Information", icon: "person.circle", type: .navigation),
                    SettingsItem(title: "Security & Privacy", icon: "lock.shield", type: .navigation),
                    SettingsItem(title: "Notification Preferences", icon: "bell", type: .navigation),
                    SettingsItem(title: "Connected Accounts", icon: "link", type: .navigation)
                ]
            ),
            SettingsSection(
                title: "App",
                items: [
                    SettingsItem(title: "Data & Storage", icon: "externaldrive", type: .navigation),
                    SettingsItem(title: "Help & Support", icon: "questionmark.circle", type: .navigation),
                    SettingsItem(title: "About Ascend", icon: "info.circle", type: .navigation),
                    SettingsItem(title: "Rate App", icon: "star", type: .action)
                ]
            ),
            SettingsSection(
                title: "Legal",
                items: [
                    SettingsItem(title: "Privacy Policy", icon: "hand.raised", type: .navigation),
                    SettingsItem(title: "Terms of Service", icon: "doc.text", type: .navigation),
                    SettingsItem(title: "Data Usage", icon: "chart.bar", type: .navigation)
                ]
            )
        ]
    }
    
    // MARK: - Data Loading
    
    private func loadUserData() {
        Task {
            do {
                user = try await AuthenticationService.shared.getCurrentUser()
                DispatchQueue.main.async {
                    self.updateUI()
                }
            } catch {
                showError(error)
            }
        }
    }
    
    private func updateUI() {
        profileHeaderView.configure(with: user)
        subscriptionCard.configure(with: user)
        settingsTableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func refreshData() {
        loadUserData()
        refreshControl.endRefreshing()
    }
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
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

// MARK: - Profile Header Delegate

extension ProfileViewController: ProfileHeaderViewDelegate {
    func profileHeaderViewDidTapEdit() {
        let editProfileVC = EditProfileViewController()
        editProfileVC.delegate = self
        let navController = UINavigationController(rootViewController: editProfileVC)
        present(navController, animated: true)
    }
    
    func profileHeaderViewDidTapAvatar() {
        let alert = UIAlertController(title: "Profile Photo", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
            self.takePhoto()
        })
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in
            self.choosePhoto()
        })
        
        if user?.avatar != nil {
            alert.addAction(UIAlertAction(title: "Remove Photo", style: .destructive) { _ in
                self.removePhoto()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func takePhoto() {
        // Implement camera functionality
        AnalyticsService.shared.trackUserAction("profile_photo_take")
    }
    
    private func choosePhoto() {
        // Implement photo library functionality
        AnalyticsService.shared.trackUserAction("profile_photo_choose")
    }
    
    private func removePhoto() {
        Task {
            do {
                try await AuthenticationService.shared.updateProfile(avatar: nil)
                loadUserData()
            } catch {
                showError(error)
            }
        }
    }
}

// MARK: - Subscription Card Delegate

extension ProfileViewController: SubscriptionCardDelegate {
    func subscriptionCardDidTapUpgrade() {
        let subscriptionVC = SubscriptionViewController()
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
    }
    
    func subscriptionCardDidTapManage() {
        let subscriptionVC = SubscriptionViewController()
        let navController = UINavigationController(rootViewController: subscriptionVC)
        present(navController, animated: true)
    }
}

// MARK: - Edit Profile Delegate

extension ProfileViewController: EditProfileViewControllerDelegate {
    func editProfileViewControllerDidUpdateProfile() {
        loadUserData()
    }
}

// MARK: - UITableViewDataSource

extension ProfileViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return settingsSections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsSections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! SettingsCell
        let item = settingsSections[indexPath.section].items[indexPath.row]
        cell.configure(with: item)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "SettingsHeaderView") as! SettingsHeaderView
        headerView.configure(with: settingsSections[section].title)
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = settingsSections[indexPath.section].items[indexPath.row]
        
        switch item.type {
        case .navigation:
            handleNavigationItem(item)
        case .action:
            handleActionItem(item)
        case .toggle:
            // Handle toggle
            break
        }
    }
    
    private func handleNavigationItem(_ item: SettingsItem) {
        switch item.title {
        case "Personal Information":
            let personalInfoVC = PersonalInformationViewController()
            navigationController?.pushViewController(personalInfoVC, animated: true)
        case "Security & Privacy":
            let securityVC = SecurityPrivacyViewController()
            navigationController?.pushViewController(securityVC, animated: true)
        case "Notification Preferences":
            let notificationsVC = NotificationPreferencesViewController()
            navigationController?.pushViewController(notificationsVC, animated: true)
        case "Connected Accounts":
            let connectedAccountsVC = ConnectedAccountsViewController()
            navigationController?.pushViewController(connectedAccountsVC, animated: true)
        case "Data & Storage":
            let dataStorageVC = DataStorageViewController()
            navigationController?.pushViewController(dataStorageVC, animated: true)
        case "Help & Support":
            let helpSupportVC = HelpSupportViewController()
            navigationController?.pushViewController(helpSupportVC, animated: true)
        case "About Ascend":
            let aboutVC = AboutViewController()
            navigationController?.pushViewController(aboutVC, animated: true)
        case "Privacy Policy":
            let privacyVC = PrivacyPolicyViewController()
            navigationController?.pushViewController(privacyVC, animated: true)
        case "Terms of Service":
            let termsVC = TermsOfServiceViewController()
            navigationController?.pushViewController(termsVC, animated: true)
        case "Data Usage":
            let dataUsageVC = DataUsageViewController()
            navigationController?.pushViewController(dataUsageVC, animated: true)
        default:
            break
        }
    }
    
    private func handleActionItem(_ item: SettingsItem) {
        switch item.title {
        case "Rate App":
            rateApp()
        case "Logout":
            logout()
        default:
            break
        }
    }
    
    private func rateApp() {
        // Open App Store rating
        if let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") {
            UIApplication.shared.open(url)
        }
        AnalyticsService.shared.trackUserAction("rate_app_tapped")
    }
    
    private func logout() {
        let alert = UIAlertController(
            title: "Logout",
            message: "Are you sure you want to logout?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Logout", style: .destructive) { _ in
            Task {
                do {
                    try await AuthenticationService.shared.logout()
                    DispatchQueue.main.async {
                        // Return to authentication screen
                        let authVC = AuthenticationViewController()
                        authVC.delegate = self
                        self.view.window?.rootViewController = authVC
                    }
                } catch {
                    self.showError(error)
                }
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Authentication Delegate

extension ProfileViewController: AuthenticationViewControllerDelegate {
    func authenticationDidComplete() {
        // User logged back in
        loadUserData()
    }
    
    func authenticationDidFail(_ error: Error) {
        showError(error)
    }
}

// MARK: - Profile Header View

protocol ProfileHeaderViewDelegate: AnyObject {
    func profileHeaderViewDidTapEdit()
    func profileHeaderViewDidTapAvatar()
}

class ProfileHeaderView: UIView {
    
    weak var delegate: ProfileHeaderViewDelegate?
    
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editButton = UIButton(type: .system)
    
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
        
        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.backgroundColor = UIColor(named: "MistBackground") ?? .systemGray6
        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(avatarTap)
        avatarImageView.isUserInteractionEnabled = true
        
        // Name label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont(name: "Satoshi-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        nameLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        // Email label
        emailLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        emailLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        emailLabel.alpha = 0.7
        
        // Edit button
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.setTitle("Edit Profile", for: .normal)
        editButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        editButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(emailLabel)
        addSubview(editButton)
        
        NSLayoutConstraint.activate([
            avatarImageView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            avatarImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            avatarImageView.widthAnchor.constraint(equalToConstant: 80),
            avatarImageView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -16),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            
            editButton.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            editButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with user: User?) {
        nameLabel.text = user?.fullName ?? "User"
        emailLabel.text = user?.email ?? ""
        
        if let avatar = user?.avatar {
            // Load avatar image
            avatarImageView.image = UIImage(named: avatar)
        } else {
            avatarImageView.image = UIImage(systemName: "person.circle.fill")
        }
    }
    
    @objc private func editTapped() {
        delegate?.profileHeaderViewDidTapEdit()
    }
    
    @objc private func avatarTapped() {
        delegate?.profileHeaderViewDidTapAvatar()
    }
}

// MARK: - Subscription Card

protocol SubscriptionCardDelegate: AnyObject {
    func subscriptionCardDidTapUpgrade()
    func subscriptionCardDidTapManage()
}

class SubscriptionCard: UIView {
    
    weak var delegate: SubscriptionCardDelegate?
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
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
        backgroundColor = UIColor(named: "PrimaryBlue")
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .white
        titleLabel.text = "Free Plan"
        
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .white
        descriptionLabel.alpha = 0.9
        descriptionLabel.text = "Upgrade to Premium for advanced features"
        descriptionLabel.numberOfLines = 0
        
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.setTitle("Upgrade", for: .normal)
        actionButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        actionButton.setTitleColor(UIColor(named: "PrimaryBlue") ?? .systemBlue, for: .normal)
        actionButton.backgroundColor = .white
        actionButton.layer.cornerRadius = 8
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        
        addSubview(titleLabel)
        addSubview(descriptionLabel)
        addSubview(actionButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -16),
            
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            actionButton.widthAnchor.constraint(equalToConstant: 80),
            actionButton.heightAnchor.constraint(equalToConstant: 36),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }
    
    func configure(with user: User?) {
        if let subscription = user?.subscriptionTier {
            switch subscription {
            case .free:
                titleLabel.text = "Free Plan"
                descriptionLabel.text = "Upgrade to Premium for advanced features"
                actionButton.setTitle("Upgrade", for: .normal)
            case .premium:
                titleLabel.text = "Premium Plan"
                descriptionLabel.text = "You have access to all premium features"
                actionButton.setTitle("Manage", for: .normal)
            }
        }
    }
    
    @objc private func actionTapped() {
        if actionButton.title(for: .normal) == "Upgrade" {
            delegate?.subscriptionCardDidTapUpgrade()
        } else {
            delegate?.subscriptionCardDidTapManage()
        }
    }
}

// MARK: - Supporting Types

struct SettingsSection {
    let title: String
    let items: [SettingsItem]
}

struct SettingsItem {
    let title: String
    let icon: String
    let type: SettingsItemType
}

enum SettingsItemType {
    case navigation
    case action
    case toggle
}

// MARK: - Settings Cell

class SettingsCell: UITableViewCell {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let accessoryImageView = UIImageView()
    
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
        selectionStyle = .none
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = UIColor(named: "AccentLavender") ?? .darkGray
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        accessoryImageView.translatesAutoresizingMaskIntoConstraints = false
        accessoryImageView.image = UIImage(systemName: "chevron.right")
        accessoryImageView.tintColor = UIColor.systemGray3
        accessoryImageView.contentMode = .scaleAspectFit
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(accessoryImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor, constant: -16),
            
            accessoryImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            accessoryImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            accessoryImageView.widthAnchor.constraint(equalToConstant: 16),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with item: SettingsItem) {
        iconImageView.image = UIImage(systemName: item.icon)
        titleLabel.text = item.title
    }
}

// MARK: - Settings Header View

class SettingsHeaderView: UITableViewHeaderFooterView {
    
    private let titleLabel = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        contentView.backgroundColor = .clear
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = UIColor(named: "AccentLavender") ?? .darkGray
        
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(with title: String) {
        titleLabel.text = title.uppercased()
    }
}
