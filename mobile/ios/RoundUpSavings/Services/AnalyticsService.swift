import Foundation

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    func initialize() {
        // Initialize analytics providers
        setupMixpanel()
        setupSentry()
    }
    
    // MARK: - Event Tracking
    
    func trackEvent(_ event: AnalyticsEvent) {
        // Track with Mixpanel
        trackMixpanelEvent(event)
        
        // Track with custom analytics
        trackCustomEvent(event)
    }
    
    func trackScreenView(_ screenName: String) {
        let event = AnalyticsEvent.screenView(screenName: screenName)
        trackEvent(event)
    }
    
    func trackUserAction(_ action: String, properties: [String: Any] = [:]) {
        let event = AnalyticsEvent.userAction(action: action, properties: properties)
        trackEvent(event)
    }
    
    func trackError(_ error: Error, context: String) {
        let event = AnalyticsEvent.error(error: error, context: context)
        trackEvent(event)
    }
    
    // MARK: - User Properties
    
    func setUserProperty(_ key: String, value: Any) {
        // Set user property in Mixpanel
        setMixpanelUserProperty(key, value: value)
    }
    
    func identifyUser(_ userId: String, properties: [String: Any] = [:]) {
        // Identify user in Mixpanel
        identifyMixpanelUser(userId, properties: properties)
    }
    
    // MARK: - Conversion Tracking
    
    func trackConversion(_ conversion: ConversionEvent) {
        let event = AnalyticsEvent.conversion(conversion: conversion)
        trackEvent(event)
    }
    
    // MARK: - Private Methods
    
    private func setupMixpanel() {
        // Initialize Mixpanel with API key
        // Mixpanel.initialize(token: "YOUR_MIXPANEL_TOKEN")
    }
    
    private func setupSentry() {
        // Initialize Sentry for error tracking
        // SentrySDK.start { options in
        //     options.dsn = "YOUR_SENTRY_DSN"
        // }
    }
    
    private func trackMixpanelEvent(_ event: AnalyticsEvent) {
        // Track event with Mixpanel
        // Mixpanel.mainInstance().track(event.name, properties: event.properties)
    }
    
    private func trackCustomEvent(_ event: AnalyticsEvent) {
        // Send to custom analytics endpoint
        Task {
            await sendToAnalyticsServer(event)
        }
    }
    
    private func setMixpanelUserProperty(_ key: String, value: Any) {
        // Set user property in Mixpanel
        // Mixpanel.mainInstance().people.set(property: key, to: value)
    }
    
    private func identifyMixpanelUser(_ userId: String, properties: [String: Any]) {
        // Identify user in Mixpanel
        // Mixpanel.mainInstance().identify(distinctId: userId)
        // Mixpanel.mainInstance().people.set(properties: properties)
    }
    
    private func sendToAnalyticsServer(_ event: AnalyticsEvent) async {
        guard let url = URL(string: "\(APIConstants.baseURL)/analytics/events") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "event": event.name,
            "properties": event.properties,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Failed to send analytics event: \(error)")
        }
    }
}

// MARK: - Analytics Event Types

enum AnalyticsEvent {
    case screenView(screenName: String)
    case userAction(action: String, properties: [String: Any])
    case error(error: Error, context: String)
    case conversion(conversion: ConversionEvent)
    
    var name: String {
        switch self {
        case .screenView:
            return "Screen View"
        case .userAction(let action, _):
            return action
        case .error:
            return "Error"
        case .conversion(let conversion):
            return conversion.name
        }
    }
    
    var properties: [String: Any] {
        switch self {
        case .screenView(let screenName):
            return ["screen_name": screenName]
        case .userAction(_, let properties):
            return properties
        case .error(let error, let context):
            return [
                "error_message": error.localizedDescription,
                "context": context
            ]
        case .conversion(let conversion):
            return conversion.properties
        }
    }
}

enum ConversionEvent {
    case userRegistration
    case bankConnection
    case debtAdded
    case paymentScheduled
    case optimizationApplied
    case subscriptionUpgrade(tier: String)
    
    var name: String {
        switch self {
        case .userRegistration:
            return "User Registration"
        case .bankConnection:
            return "Bank Connection"
        case .debtAdded:
            return "Debt Added"
        case .paymentScheduled:
            return "Payment Scheduled"
        case .optimizationApplied:
            return "Optimization Applied"
        case .subscriptionUpgrade:
            return "Subscription Upgrade"
        }
    }
    
    var properties: [String: Any] {
        switch self {
        case .userRegistration:
            return [:]
        case .bankConnection:
            return [:]
        case .debtAdded:
            return [:]
        case .paymentScheduled:
            return [:]
        case .optimizationApplied:
            return [:]
        case .subscriptionUpgrade(let tier):
            return ["subscription_tier": tier]
        }
    }
}
