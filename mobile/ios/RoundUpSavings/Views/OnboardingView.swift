import UIKit

protocol OnboardingViewDelegate: AnyObject {
    func onboardingDidComplete()
    func onboardingDidSkip()
}

class OnboardingViewController: UIViewController {
    
    // MARK: - Properties
    
    weak var delegate: OnboardingViewDelegate?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Ascend",
            subtitle: "Your AI-powered debt management companion",
            description: "Eliminate debt 38% faster with intelligent optimization and personalized strategies.",
            imageName: "chart.line.uptrend.xyaxis",
            backgroundColor: UIColor(named: "PrimaryBlue") ?? .systemBlue
        ),
        OnboardingPage(
            title: "Smart Optimization",
            subtitle: "AI-powered payment strategies",
            description: "Our AI analyzes your debts and creates the most efficient payoff plan to save you money and time.",
            imageName: "brain.head.profile",
            backgroundColor: UIColor(named: "SecondaryLime") ?? .systemGreen
        ),
        OnboardingPage(
            title: "Track Progress",
            subtitle: "Visualize your journey",
            description: "See your debt-free journey with beautiful charts and celebrate every milestone along the way.",
            imageName: "chart.pie.fill",
            backgroundColor: UIColor(named: "AccentLavender") ?? .systemPurple
        ),
        OnboardingPage(
            title: "Community Support",
            subtitle: "You're not alone",
            description: "Join anonymous support groups and challenges to stay motivated and connected with others on the same journey.",
            imageName: "person.3.fill",
            backgroundColor: UIColor(named: "WarningOrange") ?? .systemOrange
        )
    ]
    
    private var currentPage = 0
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        
        // Page control
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.systemGray4
        pageControl.currentPageIndicatorTintColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        
        // Next button
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = UIFont(name: "Satoshi-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = UIColor(named: "PrimaryBlue") ?? .systemBlue
        nextButton.layer.cornerRadius = 12
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        
        // Skip button
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = UIFont(name: "Satoshi-Medium", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
        skipButton.setTitleColor(UIColor(named: "AccentLavender") ?? .darkGray, for: .normal)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        
        view.addSubview(scrollView)
        view.addSubview(pageControl)
        view.addSubview(nextButton)
        view.addSubview(skipButton)
        
        setupPages()
    }
    
    private func setupPages() {
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        var previousPage: UIView?
        
        for (index, pageData) in pages.enumerated() {
            let pageView = createPageView(with: pageData)
            pageView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(pageView)
            
            NSLayoutConstraint.activate([
                pageView.topAnchor.constraint(equalTo: contentView.topAnchor),
                pageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                pageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                pageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ])
            
            if let previous = previousPage {
                pageView.leadingAnchor.constraint(equalTo: previous.trailingAnchor).isActive = true
            } else {
                pageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            }
            
            if index == pages.count - 1 {
                pageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            }
            
            previousPage = pageView
        }
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
    private func createPageView(with pageData: OnboardingPage) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = pageData.backgroundColor
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: pageData.imageName)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = pageData.title
        titleLabel.font = UIFont(name: "Satoshi-Bold", size: 28) ?? UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = pageData.subtitle
        subtitleLabel.font = UIFont(name: "Satoshi-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .medium)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        let descriptionLabel = UILabel()
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = pageData.description
        descriptionLabel.font = UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(descriptionLabel)
        
        NSLayoutConstraint.activate([
            // Image view
            imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor, constant: 80),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            // Subtitle label
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            
            // Description label
            descriptionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40)
        ])
        
        return containerView
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),
            
            // Page control
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -30),
            
            // Next button
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func nextTapped() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            let offset = CGPoint(x: CGFloat(currentPage) * scrollView.frame.width, y: 0)
            scrollView.setContentOffset(offset, animated: true)
        } else {
            delegate?.onboardingDidComplete()
        }
    }
    
    @objc private func skipTapped() {
        delegate?.onboardingDidSkip()
    }
    
    @objc private func pageControlChanged() {
        currentPage = pageControl.currentPage
        let offset = CGPoint(x: CGFloat(currentPage) * scrollView.frame.width, y: 0)
        scrollView.setContentOffset(offset, animated: true)
    }
    
    private func updateUI() {
        pageControl.currentPage = currentPage
        
        if currentPage == pages.count - 1 {
            nextButton.setTitle("Get Started", for: .normal)
        } else {
            nextButton.setTitle("Next", for: .normal)
        }
    }
}

// MARK: - UIScrollViewDelegate

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / scrollView.frame.width))
        if page != currentPage {
            currentPage = page
            updateUI()
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let backgroundColor: UIColor
}
