import UIKit

class ThemeService {
    static let shared = ThemeService()
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    private init() {}
    
    // MARK: - Theme Management
    
    var currentTheme: AppTheme {
        get {
            if let themeString = userDefaults.string(forKey: themeKey),
               let theme = AppTheme(rawValue: themeString) {
                return theme
            }
            return .system
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: themeKey)
            applyTheme(newValue)
        }
    }
    
    var isDarkMode: Bool {
        switch currentTheme {
        case .light:
            return false
        case .dark:
            return true
        case .system:
            return traitCollection.userInterfaceStyle == .dark
        }
    }
    
    func applyTheme(_ theme: AppTheme) {
        currentTheme = theme
        
        // Update UI appearance
        updateAppearance()
        
        // Notify observers
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
    }
    
    func updateAppearance() {
        let appearance = UINavigationBarAppearance()
        let tabBarAppearance = UITabBarAppearance()
        
        switch currentTheme {
        case .light:
            appearance.configureWithDefaultBackground()
            tabBarAppearance.configureWithDefaultBackground()
        case .dark:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
            
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemBackground
        case .system:
            appearance.configureWithDefaultBackground()
            tabBarAppearance.configureWithDefaultBackground()
        }
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    // MARK: - Color Management
    
    func color(for colorType: ColorType) -> UIColor {
        switch currentTheme {
        case .light:
            return colorType.lightColor
        case .dark:
            return colorType.darkColor
        case .system:
            return colorType.systemColor
        }
    }
    
    func dynamicColor(light: UIColor, dark: UIColor) -> UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            case .light, .unspecified:
                return light
            @unknown default:
                return light
            }
        }
    }
    
    // MARK: - Background Colors
    
    var backgroundColor: UIColor {
        return color(for: .background)
    }
    
    var secondaryBackgroundColor: UIColor {
        return color(for: .secondaryBackground)
    }
    
    var tertiaryBackgroundColor: UIColor {
        return color(for: .tertiaryBackground)
    }
    
    // MARK: - Text Colors
    
    var primaryTextColor: UIColor {
        return color(for: .primaryText)
    }
    
    var secondaryTextColor: UIColor {
        return color(for: .secondaryText)
    }
    
    var tertiaryTextColor: UIColor {
        return color(for: .tertiaryText)
    }
    
    // MARK: - Accent Colors
    
    var primaryAccentColor: UIColor {
        return color(for: .primaryAccent)
    }
    
    var secondaryAccentColor: UIColor {
        return color(for: .secondaryAccent)
    }
    
    var successColor: UIColor {
        return color(for: .success)
    }
    
    var warningColor: UIColor {
        return color(for: .warning)
    }
    
    var errorColor: UIColor {
        return color(for: .error)
    }
    
    // MARK: - Card Colors
    
    var cardBackgroundColor: UIColor {
        return color(for: .cardBackground)
    }
    
    var cardBorderColor: UIColor {
        return color(for: .cardBorder)
    }
    
    var cardShadowColor: UIColor {
        return color(for: .cardShadow)
    }
    
    // MARK: - Input Colors
    
    var inputBackgroundColor: UIColor {
        return color(for: .inputBackground)
    }
    
    var inputBorderColor: UIColor {
        return color(for: .inputBorder)
    }
    
    var inputTextColor: UIColor {
        return color(for: .inputText)
    }
    
    var inputPlaceholderColor: UIColor {
        return color(for: .inputPlaceholder)
    }
    
    // MARK: - Button Colors
    
    var buttonPrimaryBackgroundColor: UIColor {
        return color(for: .buttonPrimaryBackground)
    }
    
    var buttonPrimaryTextColor: UIColor {
        return color(for: .buttonPrimaryText)
    }
    
    var buttonSecondaryBackgroundColor: UIColor {
        return color(for: .buttonSecondaryBackground)
    }
    
    var buttonSecondaryTextColor: UIColor {
        return color(for: .buttonSecondaryText)
    }
    
    // MARK: - Chart Colors
    
    var chartLineColor: UIColor {
        return color(for: .chartLine)
    }
    
    var chartFillColor: UIColor {
        return color(for: .chartFill)
    }
    
    var chartGridColor: UIColor {
        return color(for: .chartGrid)
    }
    
    // MARK: - Status Colors
    
    var statusActiveColor: UIColor {
        return color(for: .statusActive)
    }
    
    var statusInactiveColor: UIColor {
        return color(for: .statusInactive)
    }
    
    var statusPendingColor: UIColor {
        return color(for: .statusPending)
    }
    
    // MARK: - Utility Methods
    
    func updateInterfaceStyle(_ style: UIUserInterfaceStyle) {
        if currentTheme == .system {
            updateAppearance()
            NotificationCenter.default.post(name: .themeDidChange, object: currentTheme)
        }
    }
    
    func getContrastingTextColor(for backgroundColor: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        
        return brightness > 0.5 ? UIColor.black : UIColor.white
    }
}

// MARK: - Supporting Types

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "gear"
        }
    }
}

enum ColorType {
    case background
    case secondaryBackground
    case tertiaryBackground
    case primaryText
    case secondaryText
    case tertiaryText
    case primaryAccent
    case secondaryAccent
    case success
    case warning
    case error
    case cardBackground
    case cardBorder
    case cardShadow
    case inputBackground
    case inputBorder
    case inputText
    case inputPlaceholder
    case buttonPrimaryBackground
    case buttonPrimaryText
    case buttonSecondaryBackground
    case buttonSecondaryText
    case chartLine
    case chartFill
    case chartGrid
    case statusActive
    case statusInactive
    case statusPending
    
    var lightColor: UIColor {
        switch self {
        case .background: return UIColor.systemBackground
        case .secondaryBackground: return UIColor.systemGray6
        case .tertiaryBackground: return UIColor.systemGray5
        case .primaryText: return UIColor.label
        case .secondaryText: return UIColor.secondaryLabel
        case .tertiaryText: return UIColor.tertiaryLabel
        case .primaryAccent: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .secondaryAccent: return UIColor(named: "SecondaryLime") ?? UIColor.systemGreen
        case .success: return UIColor.systemGreen
        case .warning: return UIColor.systemOrange
        case .error: return UIColor.systemRed
        case .cardBackground: return UIColor.systemBackground
        case .cardBorder: return UIColor.systemGray4
        case .cardShadow: return UIColor.black.withAlphaComponent(0.1)
        case .inputBackground: return UIColor.systemBackground
        case .inputBorder: return UIColor.systemGray4
        case .inputText: return UIColor.label
        case .inputPlaceholder: return UIColor.placeholderText
        case .buttonPrimaryBackground: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .buttonPrimaryText: return UIColor.white
        case .buttonSecondaryBackground: return UIColor.systemGray5
        case .buttonSecondaryText: return UIColor.label
        case .chartLine: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .chartFill: return UIColor(named: "PrimaryBlue")?.withAlphaComponent(0.1) ?? UIColor.systemBlue.withAlphaComponent(0.1)
        case .chartGrid: return UIColor.systemGray4
        case .statusActive: return UIColor.systemGreen
        case .statusInactive: return UIColor.systemGray
        case .statusPending: return UIColor.systemOrange
        }
    }
    
    var darkColor: UIColor {
        switch self {
        case .background: return UIColor.systemBackground
        case .secondaryBackground: return UIColor.systemGray6
        case .tertiaryBackground: return UIColor.systemGray5
        case .primaryText: return UIColor.label
        case .secondaryText: return UIColor.secondaryLabel
        case .tertiaryText: return UIColor.tertiaryLabel
        case .primaryAccent: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .secondaryAccent: return UIColor(named: "SecondaryLime") ?? UIColor.systemGreen
        case .success: return UIColor.systemGreen
        case .warning: return UIColor.systemOrange
        case .error: return UIColor.systemRed
        case .cardBackground: return UIColor.secondarySystemBackground
        case .cardBorder: return UIColor.systemGray4
        case .cardShadow: return UIColor.black.withAlphaComponent(0.3)
        case .inputBackground: return UIColor.secondarySystemBackground
        case .inputBorder: return UIColor.systemGray4
        case .inputText: return UIColor.label
        case .inputPlaceholder: return UIColor.placeholderText
        case .buttonPrimaryBackground: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .buttonPrimaryText: return UIColor.white
        case .buttonSecondaryBackground: return UIColor.systemGray5
        case .buttonSecondaryText: return UIColor.label
        case .chartLine: return UIColor(named: "PrimaryBlue") ?? UIColor.systemBlue
        case .chartFill: return UIColor(named: "PrimaryBlue")?.withAlphaComponent(0.2) ?? UIColor.systemBlue.withAlphaComponent(0.2)
        case .chartGrid: return UIColor.systemGray4
        case .statusActive: return UIColor.systemGreen
        case .statusInactive: return UIColor.systemGray
        case .statusPending: return UIColor.systemOrange
        }
    }
    
    var systemColor: UIColor {
        return UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return self.darkColor
            case .light, .unspecified:
                return self.lightColor
            @unknown default:
                return self.lightColor
            }
        }
    }
}

// MARK: - UIView Extensions

extension UIView {
    func applyTheme() {
        backgroundColor = ThemeService.shared.backgroundColor
        layer.borderColor = ThemeService.shared.cardBorderColor.cgColor
        layer.shadowColor = ThemeService.shared.cardShadowColor.cgColor
    }
    
    func applyCardTheme() {
        backgroundColor = ThemeService.shared.cardBackgroundColor
        layer.borderColor = ThemeService.shared.cardBorderColor.cgColor
        layer.shadowColor = ThemeService.shared.cardShadowColor.cgColor
        layer.cornerRadius = 12
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }
}

extension UILabel {
    func applyTheme() {
        textColor = ThemeService.shared.primaryTextColor
    }
    
    func applySecondaryTheme() {
        textColor = ThemeService.shared.secondaryTextColor
    }
}

extension UITextField {
    func applyTheme() {
        backgroundColor = ThemeService.shared.inputBackgroundColor
        textColor = ThemeService.shared.inputTextColor
        layer.borderColor = ThemeService.shared.inputBorderColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 8
    }
}

extension UIButton {
    func applyPrimaryTheme() {
        backgroundColor = ThemeService.shared.buttonPrimaryBackgroundColor
        setTitleColor(ThemeService.shared.buttonPrimaryTextColor, for: .normal)
        layer.cornerRadius = 8
    }
    
    func applySecondaryTheme() {
        backgroundColor = ThemeService.shared.buttonSecondaryBackgroundColor
        setTitleColor(ThemeService.shared.buttonSecondaryTextColor, for: .normal)
        layer.cornerRadius = 8
    }
}

extension UITableView {
    func applyTheme() {
        backgroundColor = ThemeService.shared.backgroundColor
        separatorColor = ThemeService.shared.cardBorderColor
    }
}

extension UICollectionView {
    func applyTheme() {
        backgroundColor = ThemeService.shared.backgroundColor
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
