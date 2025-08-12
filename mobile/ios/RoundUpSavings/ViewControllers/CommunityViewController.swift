import UIKit

class CommunityViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let headerView = UIView()
    private let welcomeLabel = UILabel()
    private let statsView = CommunityStatsView()
    
    private let challengesSection = ChallengesSection()
    private let supportGroupsSection = SupportGroupsSection()
    private let leaderboardSection = LeaderboardSection()
    private let achievementsSection = AchievementsSection()
    
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Data
    
    private var challenges: [CommunityChallenge] = []
    private var supportGroups: [SupportGroup] = []
    private var leaderboardEntries: [LeaderboardEntry] = []
    private var achievements: [Achievement] = []
    
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
        AnalyticsService.shared.trackScreenView("Community")
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
        
        // Header
        setupHeaderView()
        
        // Sections
        setupSections()
        
        // Add subviews
        contentView.addSubview(headerView)
        contentView.addSubview(challengesSection)
        contentView.addSubview(supportGroupsSection)
        contentView.addSubview(leaderboardSection)
        contentView.addSubview(achievementsSection)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor(named: "PrimaryBlue")
        headerView.layer.cornerRadius = 20
        
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        welcomeLabel.text = "Welcome to the Community!"
        welcomeLabel.font = UIFont(name: "Satoshi-Bold", size: 24) ?? UIFont.boldSystemFont(ofSize: 24)
        welcomeLabel.textColor = .white
        welcomeLabel.textAlignment = .center
        
        statsView.translatesAutoresizingMaskIntoConstraints = false
        statsView.delegate = self
        
        headerView.addSubview(welcomeLabel)
        headerView.addSubview(statsView)
    }
    
    private func setupSections() {
        challengesSection.translatesAutoresizingMaskIntoConstraints = false
        challengesSection.delegate = self
        
        supportGroupsSection.translatesAutoresizingMaskIntoConstraints = false
        supportGroupsSection.delegate = self
        
        leaderboardSection.translatesAutoresizingMaskIntoConstraints = false
        leaderboardSection.delegate = self
        
        achievementsSection.translatesAutoresizingMaskIntoConstraints = false
        achievementsSection.delegate = self
    }
    
    private func setupNavigationBar() {
        title = "Community"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.circle"),
            style: .plain,
            target: self,
            action: #selector(profileTapped)
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
            headerView.heightAnchor.constraint(equalToConstant: 160),
            
            welcomeLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            welcomeLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            statsView.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 16),
            statsView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            statsView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            statsView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // Challenges section
            challengesSection.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            challengesSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            challengesSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Support groups section
            supportGroupsSection.topAnchor.constraint(equalTo: challengesSection.bottomAnchor, constant: 16),
            supportGroupsSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            supportGroupsSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Leaderboard section
            leaderboardSection.topAnchor.constraint(equalTo: supportGroupsSection.bottomAnchor, constant: 16),
            leaderboardSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            leaderboardSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Achievements section
            achievementsSection.topAnchor.constraint(equalTo: leaderboardSection.bottomAnchor, constant: 16),
            achievementsSection.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            achievementsSection.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            achievementsSection.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        Task {
            await loadChallenges()
            await loadSupportGroups()
            await loadLeaderboard()
            await loadAchievements()
            await loadCommunityStats()
        }
    }
    
    private func loadChallenges() async {
        do {
            challenges = try await CommunityService.shared.fetchChallenges()
            DispatchQueue.main.async {
                self.challengesSection.configure(with: self.challenges)
            }
        } catch {
            showError(error)
        }
    }
    
    private func loadSupportGroups() async {
        do {
            supportGroups = try await CommunityService.shared.fetchSupportGroups()
            DispatchQueue.main.async {
                self.supportGroupsSection.configure(with: self.supportGroups)
            }
        } catch {
            showError(error)
        }
    }
    
    private func loadLeaderboard() async {
        do {
            leaderboardEntries = try await CommunityService.shared.fetchLeaderboard()
            DispatchQueue.main.async {
                self.leaderboardSection.configure(with: self.leaderboardEntries)
            }
        } catch {
            showError(error)
        }
    }
    
    private func loadAchievements() async {
        do {
            achievements = try await CommunityService.shared.fetchAchievements()
            DispatchQueue.main.async {
                self.achievementsSection.configure(with: self.achievements)
            }
        } catch {
            showError(error)
        }
    }
    
    private func loadCommunityStats() async {
        do {
            let stats = try await CommunityService.shared.fetchCommunityStats()
            DispatchQueue.main.async {
                self.statsView.configure(with: stats)
            }
        } catch {
            showError(error)
        }
    }
    
    // MARK: - Actions
    
    @objc private func refreshData() {
        loadData()
        refreshControl.endRefreshing()
    }
    
    @objc private func profileTapped() {
        let profileVC = ProfileViewController()
        navigationController?.pushViewController(profileVC, animated: true)
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

// MARK: - Section Delegates

extension CommunityViewController: ChallengesSectionDelegate {
    func challengesSectionDidTapChallenge(_ challenge: CommunityChallenge) {
        let challengeDetailVC = ChallengeDetailViewController(challenge: challenge)
        navigationController?.pushViewController(challengeDetailVC, animated: true)
    }
    
    func challengesSectionDidJoinChallenge(_ challenge: CommunityChallenge) {
        Task {
            do {
                try await CommunityService.shared.joinChallenge(challenge.id)
                loadChallenges()
                showSuccessMessage("Successfully joined challenge!")
            } catch {
                showError(error)
            }
        }
    }
}

extension CommunityViewController: SupportGroupsSectionDelegate {
    func supportGroupsSectionDidTapGroup(_ group: SupportGroup) {
        let groupDetailVC = SupportGroupDetailViewController(group: group)
        navigationController?.pushViewController(groupDetailVC, animated: true)
    }
    
    func supportGroupsSectionDidJoinGroup(_ group: SupportGroup) {
        Task {
            do {
                try await CommunityService.shared.joinSupportGroup(group.id)
                loadSupportGroups()
                showSuccessMessage("Successfully joined support group!")
            } catch {
                showError(error)
            }
        }
    }
}

extension CommunityViewController: LeaderboardSectionDelegate {
    func leaderboardSectionDidTapEntry(_ entry: LeaderboardEntry) {
        // Show user profile or details
        AnalyticsService.shared.trackUserAction("leaderboard_entry_tapped", properties: ["rank": entry.rank])
    }
}

extension CommunityViewController: AchievementsSectionDelegate {
    func achievementsSectionDidTapAchievement(_ achievement: Achievement) {
        let achievementDetailVC = AchievementDetailViewController(achievement: achievement)
        navigationController?.pushViewController(achievementDetailVC, animated: true)
    }
}

extension CommunityViewController: CommunityStatsViewDelegate {
    func communityStatsViewDidTapStat(_ stat: CommunityStat) {
        // Handle stat tap
        AnalyticsService.shared.trackUserAction("community_stat_tapped", properties: ["stat_type": stat.type])
    }
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Great!", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Community Stats View

protocol CommunityStatsViewDelegate: AnyObject {
    func communityStatsViewDidTapStat(_ stat: CommunityStat)
}

class CommunityStatsView: UIView {
    
    weak var delegate: CommunityStatsViewDelegate?
    
    private let stackView = UIStackView()
    private var stats: [CommunityStat] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with stats: [CommunityStat]) {
        self.stats = stats
        
        // Clear existing stat views
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add new stat views
        for stat in stats {
            let statView = StatView(stat: stat)
            statView.delegate = self
            stackView.addArrangedSubview(statView)
        }
    }
}

extension CommunityStatsView: StatViewDelegate {
    func statViewDidTap(_ stat: CommunityStat) {
        delegate?.communityStatsViewDidTapStat(stat)
    }
}

// MARK: - Stat View

protocol StatViewDelegate: AnyObject {
    func statViewDidTap(_ stat: CommunityStat)
}

class StatView: UIView {
    
    weak var delegate: StatViewDelegate?
    private let stat: CommunityStat
    
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()
    
    init(stat: CommunityStat) {
        self.stat = stat
        super.init(frame: .zero)
        setupView()
        configure(with: stat)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor.white.withAlphaComponent(0.2)
        layer.cornerRadius = 12
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont(name: "Satoshi-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .center
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont(name: "Inter-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        addSubview(valueLabel)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }
    
    private func configure(with stat: CommunityStat) {
        valueLabel.text = stat.value
        titleLabel.text = stat.title
    }
    
    @objc private func tapped() {
        delegate?.statViewDidTap(stat)
    }
}

// MARK: - Supporting Types

struct CommunityStat {
    let type: String
    let value: String
    let title: String
}

struct CommunityChallenge: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let goal: String
    let participants: Int
    let endDate: Date
    let isJoined: Bool
    let progress: Double
}

struct SupportGroup: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let memberCount: Int
    let isPrivate: Bool
    let isJoined: Bool
    let category: String
}

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let rank: Int
    let username: String
    let debtPaid: Double
    let avatar: String?
}

struct Achievement: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let unlockedDate: Date?
    let progress: Double
}

// MARK: - Community Service

class CommunityService {
    static let shared = CommunityService()
    
    private init() {}
    
    func fetchChallenges() async throws -> [CommunityChallenge] {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return [
            CommunityChallenge(
                id: "1",
                title: "30-Day Debt Free Challenge",
                description: "Pay off at least $500 in debt this month",
                goal: "$500",
                participants: 1247,
                endDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
                isJoined: false,
                progress: 0.0
            ),
            CommunityChallenge(
                id: "2",
                title: "High APR Elimination",
                description: "Focus on paying off your highest APR debt",
                goal: "Eliminate 1 high APR debt",
                participants: 892,
                endDate: Date().addingTimeInterval(60 * 24 * 60 * 60),
                isJoined: true,
                progress: 0.6
            )
        ]
    }
    
    func fetchSupportGroups() async throws -> [SupportGroup] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return [
            SupportGroup(
                id: "1",
                name: "Student Loan Warriors",
                description: "Support group for those tackling student loan debt",
                memberCount: 3421,
                isPrivate: false,
                isJoined: true,
                category: "Student Loans"
            ),
            SupportGroup(
                id: "2",
                name: "Credit Card Freedom",
                description: "Anonymous group for credit card debt support",
                memberCount: 2156,
                isPrivate: true,
                isJoined: false,
                category: "Credit Cards"
            )
        ]
    }
    
    func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return [
            LeaderboardEntry(id: "1", rank: 1, username: "DebtSlayer", debtPaid: 25000, avatar: nil),
            LeaderboardEntry(id: "2", rank: 2, username: "FreedomSeeker", debtPaid: 22000, avatar: nil),
            LeaderboardEntry(id: "3", rank: 3, username: "MoneyMaster", debtPaid: 19500, avatar: nil)
        ]
    }
    
    func fetchAchievements() async throws -> [Achievement] {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        return [
            Achievement(
                id: "1",
                title: "First Payment",
                description: "Make your first debt payment",
                icon: "checkmark.circle.fill",
                isUnlocked: true,
                unlockedDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
                progress: 1.0
            ),
            Achievement(
                id: "2",
                title: "Debt Destroyer",
                description: "Pay off $10,000 in debt",
                icon: "trophy.fill",
                isUnlocked: false,
                unlockedDate: nil,
                progress: 0.7
            )
        ]
    }
    
    func fetchCommunityStats() async throws -> [CommunityStat] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        return [
            CommunityStat(type: "members", value: "12.5K", title: "Members"),
            CommunityStat(type: "debt_paid", value: "$2.1M", title: "Debt Paid"),
            CommunityStat(type: "challenges", value: "47", title: "Active Challenges")
        ]
    }
    
    func joinChallenge(_ challengeId: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        // Simulate API call
    }
    
    func joinSupportGroup(_ groupId: String) async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        // Simulate API call
    }
}

// MARK: - Section Views (Placeholder implementations)

protocol ChallengesSectionDelegate: AnyObject {
    func challengesSectionDidTapChallenge(_ challenge: CommunityChallenge)
    func challengesSectionDidJoinChallenge(_ challenge: CommunityChallenge)
}

class ChallengesSection: UIView {
    weak var delegate: ChallengesSectionDelegate?
    
    func configure(with challenges: [CommunityChallenge]) {
        // Implementation would go here
    }
}

protocol SupportGroupsSectionDelegate: AnyObject {
    func supportGroupsSectionDidTapGroup(_ group: SupportGroup)
    func supportGroupsSectionDidJoinGroup(_ group: SupportGroup)
}

class SupportGroupsSection: UIView {
    weak var delegate: SupportGroupsSectionDelegate?
    
    func configure(with groups: [SupportGroup]) {
        // Implementation would go here
    }
}

protocol LeaderboardSectionDelegate: AnyObject {
    func leaderboardSectionDidTapEntry(_ entry: LeaderboardEntry)
}

class LeaderboardSection: UIView {
    weak var delegate: LeaderboardSectionDelegate?
    
    func configure(with entries: [LeaderboardEntry]) {
        // Implementation would go here
    }
}

protocol AchievementsSectionDelegate: AnyObject {
    func achievementsSectionDidTapAchievement(_ achievement: Achievement)
}

class AchievementsSection: UIView {
    weak var delegate: AchievementsSectionDelegate?
    
    func configure(with achievements: [Achievement]) {
        // Implementation would go here
    }
}
