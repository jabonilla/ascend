import Foundation
import Network

class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkManager")
    private var isConnected = true
    private var pendingRequests: [PendingRequest] = []
    private let cache = NSCache<NSString, CachedResponse>()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConstants.Request.defaultTimeout
        config.timeoutIntervalForResource = APIConstants.Request.downloadTimeout
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "network_cache")
        
        self.session = URLSession(configuration: config)
        setupNetworkMonitoring()
        setupCache()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let wasConnected = self?.isConnected ?? true
            self?.isConnected = path.status == .satisfied
            
            if !wasConnected && self?.isConnected == true {
                self?.processPendingRequests()
            }
        }
        monitor.start(queue: queue)
    }
    
    private func setupCache() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Request Execution
    
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        parameters: [String: String]? = nil,
        cachePolicy: CachePolicy = .default,
        retryCount: Int = APIConstants.Request.maxRetries
    ) async throws -> T {
        
        // Check cache first
        if cachePolicy == .cacheFirst || cachePolicy == .cacheOnly {
            if let cached: T = getCachedResponse(for: endpoint) {
                return cached
            }
            
            if cachePolicy == .cacheOnly {
                throw NetworkError.noCachedData
            }
        }
        
        // Check network connectivity
        guard isConnected else {
            if cachePolicy == .networkOnly {
                throw NetworkError.noConnection
            }
            
            // Try to get cached data as fallback
            if let cached: T = getCachedResponse(for: endpoint) {
                return cached
            }
            
            // Queue request for later
            let pendingRequest = PendingRequest(
                endpoint: endpoint,
                method: method,
                body: body,
                parameters: parameters,
                cachePolicy: cachePolicy,
                retryCount: retryCount
            )
            pendingRequests.append(pendingRequest)
            throw NetworkError.noConnection
        }
        
        // Build request
        guard let url = APIConstants.buildURL(endpoint, parameters: parameters) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = APIConstants.getHeaders()
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        // Execute request with retry logic
        return try await executeRequest(request, cachePolicy: cachePolicy, retryCount: retryCount)
    }
    
    private func executeRequest<T: Codable>(
        _ request: URLRequest,
        cachePolicy: CachePolicy,
        retryCount: Int
    ) async throws -> T {
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try to decode as APIResponse first
                if let apiResponse = try? decoder.decode(APIResponse<T>.self, from: data) {
                    if apiResponse.success {
                        let result = apiResponse.data!
                        cacheResponse(result, for: request.url?.absoluteString ?? "", policy: cachePolicy)
                        return result
                    } else {
                        throw NetworkError.apiError(apiResponse.message ?? "Unknown API error")
                    }
                }
                
                // Try direct decoding
                let result = try decoder.decode(T.self, from: data)
                cacheResponse(result, for: request.url?.absoluteString ?? "", policy: cachePolicy)
                return result
                
            case 401:
                // Handle token refresh
                if await refreshToken() {
                    return try await executeRequest(request, cachePolicy: cachePolicy, retryCount: retryCount)
                }
                throw NetworkError.unauthorized
                
            case 403:
                throw NetworkError.forbidden
                
            case 404:
                throw NetworkError.notFound
                
            case 422:
                if let errorResponse = try? JSONDecoder().decode(APIResponse<Never>.self, from: data) {
                    throw NetworkError.validationError(errorResponse.errors ?? [])
                }
                throw NetworkError.validationError([])
                
            case 429:
                throw NetworkError.rateLimited
                
            case 500...599:
                if retryCount > 0 && APIConstants.shouldRetry(statusCode: httpResponse.statusCode) {
                    let delay = APIConstants.getRetryDelay(attempt: APIConstants.Request.maxRetries - retryCount + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await executeRequest(request, cachePolicy: cachePolicy, retryCount: retryCount - 1)
                }
                throw NetworkError.serverError
                
            default:
                throw NetworkError.unknownError
            }
            
        } catch {
            if retryCount > 0 && shouldRetry(error: error) {
                let delay = APIConstants.getRetryDelay(attempt: APIConstants.Request.maxRetries - retryCount + 1)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeRequest(request, cachePolicy: cachePolicy, retryCount: retryCount - 1)
            }
            throw error
        }
    }
    
    private func shouldRetry(error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.networkConnectionLost, .notConnectedToInternet, .timedOut, .cannotConnectToHost].contains(urlError.code)
        }
        return false
    }
    
    // MARK: - Token Refresh
    
    private func refreshToken() async -> Bool {
        guard let refreshToken = AuthenticationService.shared.getRefreshToken() else {
            return false
        }
        
        do {
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: APIResponse<AuthTokens> = try await request(
                endpoint: APIConstants.Endpoints.refresh,
                method: .POST,
                body: try request.toDictionary(),
                cachePolicy: .networkOnly
            )
            
            if response.success, let tokens = response.data {
                AuthenticationService.shared.updateTokens(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
                return true
            }
        } catch {
            // Token refresh failed, user needs to re-authenticate
            AuthenticationService.shared.logout()
        }
        
        return false
    }
    
    // MARK: - Caching
    
    private func cacheResponse<T>(_ response: T, for key: String, policy: CachePolicy) {
        guard policy != .networkOnly else { return }
        
        let cachedResponse = CachedResponse(
            data: response,
            timestamp: Date(),
            maxAge: policy.maxAge
        )
        
        cache.setObject(cachedResponse, forKey: key as NSString)
    }
    
    private func getCachedResponse<T>(for key: String) -> T? {
        guard let cachedResponse = cache.object(forKey: key as NSString) as? CachedResponse else {
            return nil
        }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cachedResponse.timestamp) > cachedResponse.maxAge {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        
        return cachedResponse.data as? T
    }
    
    // MARK: - Pending Requests
    
    private func processPendingRequests() {
        let requests = pendingRequests
        pendingRequests.removeAll()
        
        Task {
            for request in requests {
                do {
                    let _: Any = try await self.request(
                        endpoint: request.endpoint,
                        method: request.method,
                        body: request.body,
                        parameters: request.parameters,
                        cachePolicy: request.cachePolicy,
                        retryCount: request.retryCount
                    )
                } catch {
                    // Log error but don't retry again
                    print("Failed to process pending request: \(error)")
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    func clearCache() {
        cache.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    func isNetworkAvailable() -> Bool {
        return isConnected
    }
}

// MARK: - Supporting Types

enum CachePolicy {
    case networkOnly
    case cacheFirst
    case cacheOnly
    case default
    
    var maxAge: TimeInterval {
        switch self {
        case .networkOnly:
            return 0
        case .cacheFirst, .default:
            return APIConstants.Cache.maxAge
        case .cacheOnly:
            return APIConstants.Cache.maxAgeLong
        }
    }
}

struct CachedResponse {
    let data: Any
    let timestamp: Date
    let maxAge: TimeInterval
}

struct PendingRequest {
    let endpoint: String
    let method: HTTPMethod
    let body: [String: Any]?
    let parameters: [String: String]?
    let cachePolicy: CachePolicy
    let retryCount: Int
}

struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

enum NetworkError: Error, LocalizedError {
    case noConnection
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case validationError([APIError])
    case rateLimited
    case serverError
    case apiError(String)
    case noCachedData
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available. Please check your network settings."
        case .invalidURL:
            return "Invalid URL format."
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "You are not authorized to access this resource. Please log in again."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .validationError(let errors):
            let messages = errors.map { $0.message }.joined(separator: ", ")
            return "Validation error: \(messages)"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .serverError:
            return "Server error. Please try again later."
        case .apiError(let message):
            return message
        case .noCachedData:
            return "No cached data available."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        }
    }
}

// MARK: - Extensions

extension RefreshTokenRequest {
    func toDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}

extension NetworkManager {
    func upload<T: Codable>(
        endpoint: String,
        data: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        guard let url = APIConstants.buildURL(endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = APIConstants.getHeaders()
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await executeRequest(request, cachePolicy: .networkOnly, retryCount: APIConstants.Request.maxRetries)
    }
    
    func download(
        from url: URL,
        progress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}
