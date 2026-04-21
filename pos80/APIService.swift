// APIService.swift — Centralized network layer for Ampos POS API
import Foundation

// MARK: - Configuration
enum APIConfig {
    static let baseURLKey = "api_base_url"
    static let defaultBaseURL = "https://ampos-api.clo0.net"
    private static let legacyLocalhostBaseURL = "http://localhost:8000"

    static func normalizedBaseURL(_ urlString: String?) -> String? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static var baseURL: String {
        guard let stored = normalizedBaseURL(UserDefaults.standard.string(forKey: baseURLKey)) else {
            return defaultBaseURL
        }
        return stored == legacyLocalhostBaseURL ? defaultBaseURL : stored
    }

    static var apiV1: String { "\(baseURL)/api/v1" }
    static var publicBaseURL: String { baseURL }

    static func persistBaseURL(_ urlString: String) {
        let normalized = normalizedBaseURL(urlString) ?? defaultBaseURL
        UserDefaults.standard.set(normalized, forKey: baseURLKey)
    }

    static func migrateStoredBaseURLIfNeeded() {
        guard let stored = UserDefaults.standard.string(forKey: baseURLKey) else { return }
        guard let normalized = normalizedBaseURL(stored) else {
            UserDefaults.standard.removeObject(forKey: baseURLKey)
            return
        }
        if normalized == legacyLocalhostBaseURL {
            UserDefaults.standard.set(defaultBaseURL, forKey: baseURLKey)
            return
        }
        if normalized != stored {
            UserDefaults.standard.set(normalized, forKey: baseURLKey)
        }
    }

    static func isLoopbackURL(_ urlString: String) -> Bool {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    static var shouldWarnAboutLoopbackBaseURL: Bool {
#if targetEnvironment(simulator)
        false
#else
        isLoopbackURL(baseURL)
#endif
    }

    static func shouldWarnAboutLoopback(_ urlString: String) -> Bool {
#if targetEnvironment(simulator)
        false
#else
        isLoopbackURL(urlString)
#endif
    }

    static func resolvedMediaURLString(_ rawURL: String?) -> String? {
        guard let rawURL else { return nil }
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let parsed = URL(string: trimmed) else {
            if trimmed.hasPrefix("/") {
                return publicBaseURL + trimmed
            }
            return publicBaseURL + "/" + trimmed
        }

        if parsed.scheme == nil || parsed.host == nil {
            let path = trimmed.hasPrefix("/") ? trimmed : "/" + trimmed
            return publicBaseURL + path
        }

        let shouldRebaseHost = ["backend_superadmin", "ampos_backend_superadmin"].contains(parsed.host?.lowercased() ?? "")
            || isLoopbackURL(trimmed)

        guard shouldRebaseHost,
              let base = URL(string: publicBaseURL),
              var components = URLComponents(url: parsed, resolvingAgainstBaseURL: false) else {
            return trimmed
        }

        components.scheme = base.scheme
        components.host = base.host
        components.port = base.port
        return components.url?.absoluteString ?? trimmed
    }

    static func resolvedMediaURL(_ rawURL: String?) -> URL? {
        guard let absolute = resolvedMediaURLString(rawURL) else { return nil }
        return URL(string: absolute)
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

// MARK: - APIService
@MainActor
final class APIService {

    /// Posted on the main queue when the refresh token is rejected, indicating the session has fully expired.
    static let sessionExpiredNotification = Notification.Name("APIServiceSessionExpired")

    static let shared = APIService()
    private init() {}

    private func validateRuntimeBaseURL() throws {
#if targetEnvironment(simulator)
        return
#else
        guard !APIConfig.shouldWarnAboutLoopbackBaseURL else {
            throw NSError(
                domain: "APIConfig",
                code: URLError.cannotConnectToHost.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: "Backend is set to localhost. On a physical iPad, localhost points to the iPad itself. Update the server address to your Mac or server LAN IP, for example http://192.168.1.100:8000."
                ]
            )
        }
#endif
    }

    // MARK: Token Storage (Keychain — secure; tenantSlug is non-sensitive and stays in UserDefaults)
    private let tokenKey        = "pos_access_token"
    private let refreshTokenKey = "pos_refresh_token"
    private let tenantSlugKey   = "pos_tenant_slug"
    private let tenantCodeKey   = "pos_tenant_code"
    private let tenantNameKey   = "pos_tenant_name"
    private let tenantNameArKey = "pos_tenant_name_ar"

    var accessToken: String? {
        get { KeychainHelper.load(forKey: tokenKey) }
        set {
            if let v = newValue { KeychainHelper.save(v, forKey: tokenKey) }
            else { KeychainHelper.delete(forKey: tokenKey) }
        }
    }
    var refreshToken: String? {
        get { KeychainHelper.load(forKey: refreshTokenKey) }
        set {
            if let v = newValue { KeychainHelper.save(v, forKey: refreshTokenKey) }
            else { KeychainHelper.delete(forKey: refreshTokenKey) }
        }
    }
    var tenantSlug: String? {
        get { UserDefaults.standard.string(forKey: tenantSlugKey) }
        set { UserDefaults.standard.set(newValue, forKey: tenantSlugKey) }
    }
    var tenantCode: String? {
        get { UserDefaults.standard.string(forKey: tenantCodeKey) }
        set { UserDefaults.standard.set(newValue, forKey: tenantCodeKey) }
    }
    var tenantName: String? {
        get { UserDefaults.standard.string(forKey: tenantNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: tenantNameKey) }
    }
    var tenantNameAr: String? {
        get { UserDefaults.standard.string(forKey: tenantNameArKey) }
        set { UserDefaults.standard.set(newValue, forKey: tenantNameArKey) }
    }
    var resolvedTenant: TenantCodeResponse? {
        guard let tenantSlug,
              let tenantName,
              let tenantNameAr else { return nil }
        return TenantCodeResponse(tenantSlug: tenantSlug, tenantName: tenantName, tenantNameAr: tenantNameAr)
    }
    var isAuthenticated: Bool { accessToken != nil }

    func cacheResolvedTenant(_ resolvedTenant: TenantCodeResponse, tenantCode: String) {
        self.tenantCode = tenantCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        tenantSlug = resolvedTenant.tenantSlug
        tenantName = resolvedTenant.tenantName
        tenantNameAr = resolvedTenant.tenantNameAr
    }

    func cacheAuthenticatedTenant(from token: TokenResponse) {
        if let slug = token.tenantSlug, !slug.isEmpty {
            tenantSlug = slug
        }
        if let tenantName = token.tenantName, !tenantName.isEmpty {
            self.tenantName = tenantName
        }
        if let tenantNameAr = token.tenantNameAr, !tenantNameAr.isEmpty {
            self.tenantNameAr = tenantNameAr
        }
    }

    // MARK: Generic request
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        formData: [String: String]? = nil,
        requiresAuth: Bool = true,
        accessTokenOverride: String? = nil
    ) async throws -> T {
        try validateRuntimeBaseURL()
        guard let url = URL(string: APIConfig.apiV1 + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30

        if requiresAuth, let token = accessTokenOverride ?? accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let slug = tenantSlug {
            req.setValue(slug, forHTTPHeaderField: "X-Tenant-Slug")
        }

        if let form = formData {
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = form.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                              .joined(separator: "&")
                              .data(using: .utf8)
        } else if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // Auto-refresh on 401
        if http.statusCode == 401, accessTokenOverride == nil, let refresh = refreshToken {
            try await refreshAccessToken(refresh)
            return try await request(path: path, method: method, body: body,
                                     formData: formData, requiresAuth: requiresAuth,
                                     accessTokenOverride: accessTokenOverride)
        }

        guard (200..<300).contains(http.statusCode) else {
            let apiErr = try? JSONDecoder().decode(APIError.self, from: data)
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr?.detail ?? "Server error \(http.statusCode)"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: Void request (204/200 with no body)
    func requestVoid(
        path: String,
        method: HTTPMethod = .post,
        body: Encodable? = nil
    ) async throws {
        try validateRuntimeBaseURL()
        guard let url = URL(string: APIConfig.apiV1 + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let slug = tenantSlug {
            req.setValue(slug, forHTTPHeaderField: "X-Tenant-Slug")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: Raw data helper (returns raw Data, auth-aware)
    private func rawData(path: String, method: HTTPMethod, body: Encodable?, accessTokenOverride: String? = nil) async throws -> Data {
        try validateRuntimeBaseURL()
        guard let url = URL(string: APIConfig.apiV1 + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        if let token = accessTokenOverride ?? accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let slug = tenantSlug {
            req.setValue(slug, forHTTPHeaderField: "X-Tenant-Slug")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401, accessTokenOverride == nil, let refresh = refreshToken {
            try await refreshAccessToken(refresh)
            return try await rawData(path: path, method: method, body: body, accessTokenOverride: accessTokenOverride)
        }
        guard (200..<300).contains(http.statusCode) else {
            let apiErr = try? JSONDecoder().decode(APIError.self, from: data)
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: apiErr?.detail ?? "Server error \(http.statusCode)"])
        }
        return data
    }

    // MARK: Raw Any request (for endpoints returning unknown shape)
    func requestAny(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil
    ) async throws -> Any {
        try validateRuntimeBaseURL()
        guard let url = URL(string: APIConfig.apiV1 + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let slug = tenantSlug {
            req.setValue(slug, forHTTPHeaderField: "X-Tenant-Slug")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: Token refresh
    private func refreshAccessToken(_ token: String) async throws {
        struct RefreshReq: Codable { let refresh_token: String }
        struct RefreshResp: Codable {
            let access_token: String
            let refresh_token: String?
        }
        try validateRuntimeBaseURL()
        guard let url = URL(string: APIConfig.apiV1 + "/auth/refresh") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RefreshReq(refresh_token: token))
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            // Refresh token is invalid or expired — notify observers so AppState can force logout
            NotificationCenter.default.post(name: APIService.sessionExpiredNotification, object: nil)
            throw NSError(domain: "API", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."])
        }
        let resp = try JSONDecoder().decode(RefreshResp.self, from: data)
        accessToken = resp.access_token
        if let rt = resp.refresh_token { refreshToken = rt }
    }

    // MARK: Login
    func login(email: String, password: String) async throws -> TokenResponse {
        let form = ["username": email, "password": password, "grant_type": "password"]
        return try await request(path: "/auth/login", method: .post, formData: form, requiresAuth: false)
    }

    func resolveTenantCode(_ tenantCode: String) async throws -> TenantCodeResponse {
        let normalizedCode = tenantCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let body = ResolveTenantCodeRequest(tenantCode: normalizedCode)
        let resolved: TenantCodeResponse = try await request(path: "/auth/resolve-tenant-code", method: .post, body: body, requiresAuth: false)
        cacheResolvedTenant(resolved, tenantCode: normalizedCode)
        return resolved
    }

    func loginWithPIN(email: String, pin: String) async throws -> TokenResponse {
        let body = LoginPINRequest(email: email, pin: pin)
        return try await request(path: "/auth/login-pin", method: .post, body: body, requiresAuth: false)
    }

    func fetchPOSUsers() async throws -> [POSUserPreview] {
        return try await request(path: "/auth/pos-users", requiresAuth: false)
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: Menu
    func fetchCategories() async throws -> [ProductCategory] {
        return try await request(path: "/menu/categories")
    }

    func fetchProducts(categoryId: String? = nil, availableOnly: Bool = false) async throws -> [Product] {
        var path = "/menu/products?available_only=\(availableOnly)"
        if let cid = categoryId { path += "&category_id=\(cid)" }
        return try await request(path: path)
    }

    func fetchProductByBarcode(_ barcode: String) async throws -> Product {
        return try await request(path: "/menu/products/barcode/\(barcode)")
    }

    // MARK: Orders
    func createOrder(_ order: OrderCreate) async throws -> Order {
        let data = try await rawData(path: "/orders", method: .post, body: order)
        return try decodeOrder(from: data)
    }

    func fetchOrders(status: String? = nil, page: Int = 1, orderTypes: [String] = [], date: String? = nil, limit: Int? = nil) async throws -> [Order] {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(limit ?? 50))
        ]
        if let s = status {
            queryItems.append(URLQueryItem(name: "status", value: s))
        }
        if let date, !date.isEmpty {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        for type in orderTypes where !type.isEmpty {
            queryItems.append(URLQueryItem(name: "order_type[]", value: type))
        }
        var comps = URLComponents()
        comps.path = "/orders"
        comps.queryItems = queryItems
        let path = comps.string ?? "/orders?page=\(page)&per_page=\(limit ?? 50)"
        let data = try await rawData(path: path, method: .get, body: nil)
        let decoder = JSONDecoder()
        if let arr = try? decoder.decode([Order].self, from: data) { return arr }
        struct Paginated: Decodable { let items: [Order]? }
        if let p = try? decoder.decode(Paginated.self, from: data) { return p.items ?? [] }
        if let str = String(data: data, encoding: .utf8) { print("[Orders] decode failed: \(str.prefix(300))") }
        return []
    }

    func getOrder(_ id: String) async throws -> Order {
        let data = try await rawData(path: "/orders/\(id)", method: .get, body: nil)
        return try decodeOrder(from: data)
    }

    func payOrder(_ id: String, payment: OrderPayment) async throws -> Order {
        let data = try await rawData(path: "/orders/\(id)/pay", method: .post, body: payment)
        return try decodeOrder(from: data)
    }

    func holdOrder(_ id: String) async throws -> Order {
        let data = try await rawData(path: "/orders/\(id)/hold", method: .post, body: nil)
        return try decodeOrder(from: data)
    }

    func unholdOrder(_ id: String) async throws -> Order {
        let data = try await rawData(path: "/orders/\(id)/unhold", method: .post, body: nil)
        return try decodeOrder(from: data)
    }

    func applyDiscount(_ id: String, amount: Double, reason: String?) async throws -> Order {
        let body = DiscountRequest(discountAmount: amount, reason: reason)
        let data = try await rawData(path: "/orders/\(id)/discount", method: .patch, body: body)
        return try decodeOrder(from: data)
    }

    func fetchCustomerInsights(limit: Int = 20) async throws -> [CustomerInsight] {
        let data = try await rawData(path: "/orders/customers/insights?limit=\(limit)", method: .get, body: nil)
        return try decodeFlexibleArray(CustomerInsight.self, from: data, rootKeys: ["items", "customers", "results", "data"])
    }

    func validateCoupon(code: String, orderSubtotal: Double) async throws -> CouponValidationResult {
        let body = CouponValidateRequest(code: code, orderSubtotal: orderSubtotal)
        return try await request(path: "/coupons/validate", method: .post, body: body)
    }

    func lookupLoyaltyCustomer(phone: String) async throws -> LoyaltyCustomer {
        let encodedPhone = phone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? phone
        let data = try await rawData(path: "/loyalty/customers/lookup?phone=\(encodedPhone)", method: .get, body: nil)
        return try decodeFlexible(LoyaltyCustomer.self, from: data, rootKeys: ["customer", "item", "data"])
    }

    func voidOrderItem(orderId: String, itemId: String) async throws -> Order {
        let data = try await rawData(path: "/orders/\(orderId)/items/\(itemId)", method: .delete, body: nil)
        return try decodeOrder(from: data)
    }

    // Helper: decode Order supporting direct, wrapped {"order":...}, or {"data":...}
    private func decodeOrder(from data: Data) throws -> Order {
        let decoder = JSONDecoder()
        if let order = try? decoder.decode(Order.self, from: data) { return order }
        struct Wrapped: Decodable { let order: Order?; let data: Order? }
        if let w = try? decoder.decode(Wrapped.self, from: data), let o = w.order ?? w.data { return o }
        if let str = String(data: data, encoding: .utf8) { print("[Order] decode failed: \(str.prefix(400))") }
        throw NSError(domain: "Order", code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Could not parse order response from server."])
    }

    // MARK: Tables
    func fetchTables() async throws -> [RestaurantTable] {
        return try await request(path: "/tables")
    }

    // MARK: Shifts
    func getCurrentShift() async throws -> Shift? {
        let data = try await rawData(path: "/shifts/current", method: .get, body: nil)
        guard !data.isEmpty else { return nil }

        // Helper: only accept shifts with an "open" status
        func isOpen(_ s: Shift) -> Bool {
            let st = s.status?.lowercased() ?? ""
            return st == "open" || st == "active"
        }

        // 1) Try wrapped: {"shift": {...}} or {"shift": null}
        struct Wrapped: Decodable {
            let shift: Shift?
            let data: Shift?
        }
        if let w = try? JSONDecoder().decode(Wrapped.self, from: data) {
            if let s = w.shift ?? w.data, isOpen(s) { return s }
            return nil  // shift was null or closed
        }

        // 2) Try direct decode (status must be open)
        if let shift = try? JSONDecoder().decode(Shift.self, from: data), isOpen(shift) {
            return shift
        }

        // 3) Try array — take first open shift
        if let arr = try? JSONDecoder().decode([Shift].self, from: data) {
            return arr.first(where: { isOpen($0) })
        }

        // Log raw response for diagnosis
        if let str = String(data: data, encoding: .utf8) {
            print("[Shift] getCurrentShift decode failed. Raw: \(str.prefix(500))")
        }
        return nil
    }

    func openShift(openingCash: Double) async throws -> Shift {
        let body = OpenShiftRequest(openingCash: openingCash)
        do {
            let data = try await rawData(path: "/shifts/open", method: .post, body: body)
            // Backend returns {"id": "...", "opening_cash": ..., "status": "open", ...}
            if let shift = try? JSONDecoder().decode(Shift.self, from: data),
               shift.status?.lowercased() == "open" {
                return shift
            }
        } catch let err as NSError {
            let code = err.code
            let msg = err.localizedDescription.lowercased()
            guard msg.contains("already") || code == 400 || code == 409 || code == 422 else {
                throw err
            }
            print("[Shift] already open on server — fetching current")
        }
        // Fallback: fetch authoritative shift state
        if let shift = try await getCurrentShift() { return shift }
        try await Task.sleep(nanoseconds: 600_000_000)
        guard let shift = try await getCurrentShift() else {
            throw NSError(domain: "Shift", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Could not load shift after opening. Please refresh."])
        }
        return shift
    }

    func closeShift(shiftId: String, closingCash: Double, notes: String?) async throws -> Shift {
        let body = CloseShiftRequest(closingCash: closingCash, notes: notes)
        let data = try await rawData(path: "/shifts/\(shiftId)/close", method: .post, body: body)
        if let shift = try? JSONDecoder().decode(Shift.self, from: data) { return shift }
        // Fallback: fetch summary
        return try await request(path: "/shifts/\(shiftId)/summary")
    }

    func addCashDrop(shiftId: String, amount: Double, notes: String?, isBlind: Bool = true) async throws {
        let body = CashDropRequest(amount: amount, notes: notes, isBlind: isBlind)
        try await requestVoid(path: "/shifts/\(shiftId)/cash-drop", method: .post, body: body)
    }

    func getShiftSummary(_ shiftId: String) async throws -> ShiftSummary {
        return try await request(path: "/shifts/\(shiftId)/summary")
    }

    func getShiftHistory(page: Int = 1, perPage: Int = 20) async throws -> [Shift] {
        let data = try await rawData(path: "/shifts/history?page=\(page)&per_page=\(perPage)", method: .get, body: nil)
        // Try array first (backend may return flat list)
        if let arr = try? JSONDecoder().decode([Shift].self, from: data) {
            return arr
        }
        // Try wrapped: {"items": [...]} or {"data": [...]}
        struct Wrapped: Decodable { let items: [Shift]?; let data: [Shift]? }
        if let w = try? JSONDecoder().decode(Wrapped.self, from: data) {
            return w.items ?? w.data ?? []
        }
        return []
    }

    // MARK: Reports
    func fetchDashboard(range: String = "7d", authToken: String? = nil) async throws -> DashboardSummary {
        return try await request(path: "/reports/dashboard?range=\(range)", accessTokenOverride: authToken)
    }

    func fetchPaymentsSummary(range: String = "7d", authToken: String? = nil) async throws -> [PaymentSummaryRow] {
        return try await request(path: "/reports/payments-summary?\(dateRangeQuery(range: range))", accessTokenOverride: authToken)
    }

    func fetchZATCAReport(range: String = "7d", authToken: String? = nil) async throws -> ZATCAReport {
        return try await request(path: "/reports/zatca?\(dateRangeQuery(range: range))", accessTokenOverride: authToken)
    }

    func fetchTopProducts(limit: Int = 10, range: String = "7d", authToken: String? = nil) async throws -> [TopProduct] {
        return try await request(path: "/reports/top-products?limit=\(limit)&range=\(range)", accessTokenOverride: authToken)
    }

    // MARK: Settings
    func fetchSettings() async throws -> AppSettings {
        return try await request(path: "/settings")
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        try await requestVoid(path: "/settings", method: .put, body: settings)
        return try await fetchSettings()
    }

    func fetchBroadcasts() async throws -> BroadcastsResponse {
        return try await request(path: "/settings/broadcasts")
    }

    func dismissBroadcast(_ broadcastId: String) async throws {
        try await requestVoid(path: "/settings/broadcasts/\(broadcastId)/dismiss", method: .post)
    }

    // MARK: Staff
    func fetchStaff() async throws -> [Staff] {
        return try await request(path: "/staff")
    }

    // MARK: Split Payment
    func splitPayOrder(_ id: String, splits: [SplitEntry]) async throws -> [String: Any] {
        let body = SplitPaymentRequest(splits: splits)
        return try await requestAny(path: "/orders/\(id)/split-payment", method: .post, body: body) as? [String: Any] ?? [:]
    }

    // MARK: Invoice PDF
    func downloadInvoicePDF(_ orderId: String) async throws -> Data {
        return try await rawData(path: "/orders/\(orderId)/invoice.pdf", method: .get, body: nil)
    }

    // MARK: Fetch Held Orders
    func fetchHeldOrders() async throws -> [Order] {
        return try await request(path: "/orders?status=held")
    }

    // MARK: Batch Sync (Offline Orders)
    func syncOfflineBatch(_ orders: [OrderCreate]) async throws -> [[String: Any]] {
        let result = try await requestAny(path: "/orders/sync-batch", method: .post, body: orders)
        return result as? [[String: Any]] ?? []
    }

    private func dateRangeQuery(range: String) -> String {
        let now = Date()
        let start = reportStartDate(for: range, now: now)
        let formatter = ISO8601DateFormatter()
        let from = formatter.string(from: start).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let to = formatter.string(from: now).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "date_from=\(from)&date_to=\(to)"
    }

    private func reportStartDate(for range: String, now: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        switch range {
        case "1d":
            return calendar.startOfDay(for: now)
        case "30d":
            return calendar.date(byAdding: .day, value: -30, to: now) ?? now
        case "90d":
            return calendar.date(byAdding: .day, value: -90, to: now) ?? now
        default:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        }
    }

    private func decodeFlexible<T: Decodable>(_ type: T.Type, from data: Data, rootKeys: [String]) throws -> T {
        let decoder = JSONDecoder()
        if let value = try? decoder.decode(T.self, from: data) {
            return value
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        if let dictionary = rawObject as? [String: Any] {
            for key in rootKeys {
                guard let nested = dictionary[key], JSONSerialization.isValidJSONObject(nested) else { continue }
                let nestedData = try JSONSerialization.data(withJSONObject: nested)
                if let value = try? decoder.decode(T.self, from: nestedData) {
                    return value
                }
            }
        }

        throw NSError(domain: "API", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse API response."])
    }

    private func decodeFlexibleArray<T: Decodable>(_ type: T.Type, from data: Data, rootKeys: [String]) throws -> [T] {
        let decoder = JSONDecoder()
        if let value = try? decoder.decode([T].self, from: data) {
            return value
        }

        let rawObject = try JSONSerialization.jsonObject(with: data)
        if let dictionary = rawObject as? [String: Any] {
            for key in rootKeys {
                guard let nested = dictionary[key], JSONSerialization.isValidJSONObject(nested) else { continue }
                let nestedData = try JSONSerialization.data(withJSONObject: nested)
                if let value = try? decoder.decode([T].self, from: nestedData) {
                    return value
                }
            }
        }

        return []
    }

    // ╔══════════════════════════════════════════════════════════════════╗
    // ║  NEW API v2.2 ENDPOINTS                                         ║
    // ╚══════════════════════════════════════════════════════════════════╝

    // MARK: - Auth Enhancements
    func logoutServer() async throws {
        try await requestVoid(path: "/auth/logout", method: .post)
    }

    func verify2FA(_ body: Verify2FARequest, pendingToken: String) async throws -> TokenResponse {
        return try await request(path: "/auth/2fa/verify", method: .post, body: body, accessTokenOverride: pendingToken)
    }

    func validate2FA(_ body: Verify2FARequest, pendingToken: String) async throws -> TokenResponse {
        return try await request(path: "/auth/2fa/validate", method: .post, body: body, accessTokenOverride: pendingToken)
    }

    func setup2FA() async throws -> TwoFASetupResponse {
        return try await request(path: "/auth/2fa/setup", method: .post)
    }

    func disable2FA() async throws {
        try await requestVoid(path: "/auth/2fa/disable", method: .post)
    }

    func changePassword(_ body: ChangePasswordRequest) async throws {
        try await requestVoid(path: "/auth/change-password", method: .post, body: body)
    }

    func getMe() async throws -> [String: Any] {
        return try await requestAny(path: "/auth/me", method: .get, body: nil) as? [String: Any] ?? [:]
    }

    // MARK: - Staff CRUD
    func createStaff(_ body: StaffCreate) async throws -> Staff {
        return try await request(path: "/staff", method: .post, body: body)
    }

    func getStaffById(_ id: String) async throws -> Staff {
        return try await request(path: "/staff/\(id)")
    }

    func updateStaff(_ id: String, body: StaffUpdate) async throws -> Staff {
        return try await request(path: "/staff/\(id)", method: .put, body: body)
    }

    func deleteStaff(_ id: String) async throws {
        try await requestVoid(path: "/staff/\(id)", method: .delete)
    }

    func updateStaffPin(_ id: String, body: PinUpdate) async throws {
        try await requestVoid(path: "/staff/\(id)/pin", method: .put, body: body)
    }

    func fetchStaffShiftHistory(_ id: String) async throws -> [Shift] {
        return try await request(path: "/staff/\(id)/shift-history")
    }

    // MARK: - Order Status Update
    func updateOrderStatus(_ orderId: String, body: StatusUpdate) async throws -> Order {
        let data = try await rawData(path: "/orders/\(orderId)/status", method: .put, body: body)
        return try decodeOrder(from: data)
    }

    // MARK: - Menu CRUD
    func createCategory(_ body: CategoryCreate) async throws -> ProductCategory {
        return try await request(path: "/menu/categories", method: .post, body: body)
    }

    func updateCategory(_ id: String, body: CategoryCreate) async throws -> ProductCategory {
        return try await request(path: "/menu/categories/\(id)", method: .put, body: body)
    }

    func deleteCategory(_ id: String) async throws {
        try await requestVoid(path: "/menu/categories/\(id)", method: .delete)
    }

    func createProduct(_ body: ProductCreate) async throws -> Product {
        return try await request(path: "/menu/products", method: .post, body: body)
    }

    func updateProduct(_ id: String, body: ProductCreate) async throws -> Product {
        return try await request(path: "/menu/products/\(id)", method: .put, body: body)
    }

    func deleteProduct(_ id: String) async throws {
        try await requestVoid(path: "/menu/products/\(id)", method: .delete)
    }

    func toggleProductAvailability(_ id: String) async throws -> Product {
        return try await request(path: "/menu/products/\(id)/toggle-availability", method: .post)
    }

    func createModifier(productId: String, body: ModifierCreateFull) async throws -> ProductModifier {
        return try await request(path: "/menu/products/\(productId)/modifiers", method: .post, body: body)
    }

    func updateModifier(productId: String, modifierId: String, body: ModifierCreateFull) async throws -> ProductModifier {
        return try await request(path: "/menu/products/\(productId)/modifiers/\(modifierId)", method: .put, body: body)
    }

    func deleteModifier(productId: String, modifierId: String) async throws {
        try await requestVoid(path: "/menu/products/\(productId)/modifiers/\(modifierId)", method: .delete)
    }

    func uploadMenuImage(imageData: Data, filename: String) async throws -> String {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let url = URL(string: APIConfig.apiV1 + "/menu/upload-image")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError(detail: "Image upload failed")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let urlStr = json["url"] as? String {
            return urlStr
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func downloadMenuImportTemplate() async throws -> Data {
        return try await rawData(path: "/menu/import/template", method: .get, body: nil)
    }

    func importMenuExcel(fileData: Data, filename: String) async throws -> MenuImportResult {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let url = URL(string: APIConfig.apiV1 + "/menu/import")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError(detail: "Menu import failed")
        }
        return try JSONDecoder().decode(MenuImportResult.self, from: data)
    }

    // MARK: - Tables CRUD
    func createTable(_ body: TableCreate) async throws -> RestaurantTable {
        return try await request(path: "/tables", method: .post, body: body)
    }

    func updateTable(_ id: String, body: TableUpdate) async throws -> RestaurantTable {
        return try await request(path: "/tables/\(id)", method: .put, body: body)
    }

    func deleteTable(_ id: String) async throws {
        try await requestVoid(path: "/tables/\(id)", method: .delete)
    }

    func updateTablePosition(_ id: String, body: TablePositionUpdate) async throws {
        try await requestVoid(path: "/tables/\(id)/position", method: .put, body: body)
    }

    func ringTableBell(_ id: String) async throws {
        try await requestVoid(path: "/tables/\(id)/bell", method: .post)
    }

    func generateTableQR(_ id: String) async throws -> Data {
        return try await rawData(path: "/tables/\(id)/qr", method: .get, body: nil)
    }

    // MARK: - Coupons CRUD
    func fetchCoupons(skip: Int = 0, limit: Int = 50) async throws -> [Coupon] {
        return try await request(path: "/coupons?skip=\(skip)&limit=\(limit)")
    }

    func getCoupon(_ id: String) async throws -> Coupon {
        return try await request(path: "/coupons/\(id)")
    }

    func createCoupon(_ body: CouponCreate) async throws -> Coupon {
        return try await request(path: "/coupons", method: .post, body: body)
    }

    func updateCoupon(_ id: String, body: CouponUpdate) async throws -> Coupon {
        return try await request(path: "/coupons/\(id)", method: .put, body: body)
    }

    func deleteCoupon(_ id: String) async throws {
        try await requestVoid(path: "/coupons/\(id)", method: .delete)
    }

    // MARK: - Loyalty Full
    func fetchLoyaltySettings() async throws -> LoyaltySettings {
        return try await request(path: "/loyalty/settings")
    }

    func updateLoyaltySettings(_ body: LoyaltySettingsUpdate) async throws -> LoyaltySettings {
        return try await request(path: "/loyalty/settings", method: .put, body: body)
    }

    func fetchLoyaltyCustomers(skip: Int = 0, limit: Int = 50) async throws -> [LoyaltyCustomer] {
        return try await request(path: "/loyalty/customers?skip=\(skip)&limit=\(limit)")
    }

    func createLoyaltyCustomer(_ body: CustomerCreate) async throws -> LoyaltyCustomer {
        return try await request(path: "/loyalty/customers", method: .post, body: body)
    }

    func getLoyaltyCustomer(_ id: String) async throws -> LoyaltyCustomer {
        return try await request(path: "/loyalty/customers/\(id)")
    }

    func adjustLoyaltyPoints(_ customerId: String, body: PointsAdjust) async throws {
        try await requestVoid(path: "/loyalty/customers/\(customerId)/adjust", method: .post, body: body)
    }

    func earnLoyaltyPoints(_ body: EarnRequest) async throws {
        try await requestVoid(path: "/loyalty/earn", method: .post, body: body)
    }

    func validateLoyaltyRedemption(_ body: RedeemRequest) async throws -> RedemptionValidation {
        return try await request(path: "/loyalty/validate-redemption", method: .post, body: body)
    }

    func redeemLoyaltyPoints(_ body: RedeemRequest) async throws -> RedemptionValidation {
        return try await request(path: "/loyalty/redeem", method: .post, body: body)
    }

    func fetchLoyaltyTransactions(customerId: String? = nil, skip: Int = 0, limit: Int = 50) async throws -> [LoyaltyTransaction] {
        var path = "/loyalty/transactions?skip=\(skip)&limit=\(limit)"
        if let cid = customerId { path += "&customer_id=\(cid)" }
        return try await request(path: path)
    }

    // MARK: - Inventory
    func fetchRawMaterials(skip: Int = 0, limit: Int = 50) async throws -> [RawMaterial] {
        return try await request(path: "/inventory/raw-materials?skip=\(skip)&limit=\(limit)")
    }

    func createRawMaterial(_ body: RawMaterialCreate) async throws -> RawMaterial {
        return try await request(path: "/inventory/raw-materials", method: .post, body: body)
    }

    func getRawMaterial(_ id: String) async throws -> RawMaterial {
        return try await request(path: "/inventory/raw-materials/\(id)")
    }

    func updateRawMaterial(_ id: String, body: RawMaterialCreate) async throws -> RawMaterial {
        return try await request(path: "/inventory/raw-materials/\(id)", method: .put, body: body)
    }

    func deleteRawMaterial(_ id: String) async throws {
        try await requestVoid(path: "/inventory/raw-materials/\(id)", method: .delete)
    }

    func adjustStock(_ materialId: String, body: StockAdjustment) async throws {
        try await requestVoid(path: "/inventory/raw-materials/\(materialId)/adjust", method: .post, body: body)
    }

    func fetchStockMovements(_ materialId: String) async throws -> [StockMovement] {
        return try await request(path: "/inventory/raw-materials/\(materialId)/movements")
    }

    func fetchRecipe(productId: String) async throws -> Recipe {
        return try await request(path: "/inventory/recipes/\(productId)")
    }

    func upsertRecipe(productId: String, body: RecipeUpsert) async throws -> Recipe {
        return try await request(path: "/inventory/recipes/\(productId)", method: .put, body: body)
    }

    func deleteRecipe(productId: String) async throws {
        try await requestVoid(path: "/inventory/recipes/\(productId)", method: .delete)
    }

    func fetchBatches(skip: Int = 0, limit: Int = 50) async throws -> [InventoryBatch] {
        return try await request(path: "/inventory/batches?skip=\(skip)&limit=\(limit)")
    }

    func createBatch(_ body: BatchCreate) async throws -> InventoryBatch {
        return try await request(path: "/inventory/batches", method: .post, body: body)
    }

    // MARK: - KDS
    func fetchKDSOrders(stationId: String? = nil) async throws -> [Order] {
        var path = "/kds/orders"
        if let sid = stationId { path += "?station_id=\(sid)" }
        let data = try await rawData(path: path, method: .get, body: nil)
        return try decodeFlexibleArray(Order.self, from: data, rootKeys: ["orders", "items", "data"])
    }

    func bumpKDSOrder(_ orderId: String, body: BumpOrder) async throws {
        try await requestVoid(path: "/kds/orders/\(orderId)/bump", method: .post, body: body)
    }

    // MARK: - Kitchen Stations
    func fetchKitchenStations() async throws -> [KitchenStation] {
        return try await request(path: "/kitchen-stations")
    }

    func createKitchenStation(_ body: StationCreate) async throws -> KitchenStation {
        return try await request(path: "/kitchen-stations", method: .post, body: body)
    }

    func updateKitchenStation(_ id: String, body: StationUpdate) async throws -> KitchenStation {
        return try await request(path: "/kitchen-stations/\(id)", method: .put, body: body)
    }

    func deleteKitchenStation(_ id: String) async throws {
        try await requestVoid(path: "/kitchen-stations/\(id)", method: .delete)
    }

    // MARK: - Reservations
    func fetchReservations(date: String? = nil, status: String? = nil, skip: Int = 0, limit: Int = 50) async throws -> [Reservation] {
        var path = "/reservations?skip=\(skip)&limit=\(limit)"
        if let d = date { path += "&date=\(d)" }
        if let s = status { path += "&status=\(s)" }
        return try await request(path: path)
    }

    func createReservation(_ body: ReservationCreate) async throws -> Reservation {
        return try await request(path: "/reservations", method: .post, body: body)
    }

    func getReservation(_ id: String) async throws -> Reservation {
        return try await request(path: "/reservations/\(id)")
    }

    func updateReservation(_ id: String, body: ReservationUpdate) async throws -> Reservation {
        return try await request(path: "/reservations/\(id)", method: .put, body: body)
    }

    func deleteReservation(_ id: String) async throws {
        try await requestVoid(path: "/reservations/\(id)", method: .delete)
    }

    // MARK: - Delivery
    func fetchDeliveryPartners() async throws -> [DeliveryPartner] {
        return try await request(path: "/delivery/partners")
    }

    func createDeliveryPartner(_ body: DeliveryPartnerCreate) async throws -> DeliveryPartner {
        return try await request(path: "/delivery/partners", method: .post, body: body)
    }

    func updateDeliveryPartner(_ id: String, body: DeliveryPartnerUpdate) async throws -> DeliveryPartner {
        return try await request(path: "/delivery/partners/\(id)", method: .put, body: body)
    }

    func deleteDeliveryPartner(_ id: String) async throws {
        try await requestVoid(path: "/delivery/partners/\(id)", method: .delete)
    }

    func fetchDeliveryOrders(status: String? = nil) async throws -> [DeliveryOrder] {
        var path = "/delivery/orders"
        if let s = status { path += "?status=\(s)" }
        return try await request(path: path)
    }

    func updateDeliveryOrder(_ id: String, body: DeliveryOrderUpdate) async throws -> DeliveryOrder {
        return try await request(path: "/delivery/orders/\(id)", method: .put, body: body)
    }

    // MARK: - Staff Schedules
    func fetchSchedules(branchId: String? = nil, dateFrom: String? = nil, dateTo: String? = nil) async throws -> [StaffSchedule] {
        var params: [String] = []
        if let b = branchId { params.append("branch_id=\(b)") }
        if let f = dateFrom { params.append("date_from=\(f)") }
        if let t = dateTo { params.append("date_to=\(t)") }
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request(path: "/schedules\(query)")
    }

    func createSchedule(_ body: ScheduleCreate) async throws -> StaffSchedule {
        return try await request(path: "/schedules", method: .post, body: body)
    }

    func updateSchedule(_ id: String, body: ScheduleUpdate) async throws -> StaffSchedule {
        return try await request(path: "/schedules/\(id)", method: .put, body: body)
    }

    func deleteSchedule(_ id: String) async throws {
        try await requestVoid(path: "/schedules/\(id)", method: .delete)
    }

    // MARK: - Reports (new)
    func fetchDailyReport(date: String? = nil) async throws -> DailyReport {
        var path = "/reports/daily"
        if let d = date { path += "?date=\(d)" }
        return try await request(path: path)
    }

    func fetchMonthlyReport(year: Int? = nil, month: Int? = nil) async throws -> MonthlyReport {
        var params: [String] = []
        if let y = year { params.append("year=\(y)") }
        if let m = month { params.append("month=\(m)") }
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        return try await request(path: "/reports/monthly\(query)")
    }

    func fetchProfitabilityReport(range: String = "30d") async throws -> [ProfitabilityRow] {
        return try await request(path: "/reports/profitability?range=\(range)")
    }

    func fetchOrdersReport(range: String = "7d", skip: Int = 0, limit: Int = 50) async throws -> [Order] {
        let q = dateRangeQuery(range: range)
        let data = try await rawData(path: "/reports/orders?\(q)&skip=\(skip)&limit=\(limit)", method: .get, body: nil)
        return try decodeFlexibleArray(Order.self, from: data, rootKeys: ["orders", "items", "data"])
    }

    // MARK: - Subscription
    func fetchSubscriptionInfo() async throws -> SubscriptionInfo {
        return try await request(path: "/subscription")
    }

    // MARK: - ZATCA Server
    func zatcaOnboard() async throws -> [String: Any] {
        return try await requestAny(path: "/zatca/onboard", method: .post, body: nil) as? [String: Any] ?? [:]
    }

    func fetchZATCAInvoices(skip: Int = 0, limit: Int = 50) async throws -> [[String: Any]] {
        let result = try await requestAny(path: "/zatca/invoices?skip=\(skip)&limit=\(limit)", method: .get, body: nil)
        return result as? [[String: Any]] ?? []
    }
}
