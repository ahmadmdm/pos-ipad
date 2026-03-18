// APIService.swift — Centralized network layer for Ampos POS API
import Foundation

// MARK: - Configuration
enum APIConfig {
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? "http://localhost:8000"
    }
    static var apiV1: String { "\(baseURL)/api/v1" }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE"
}

// MARK: - APIService
@MainActor
final class APIService {

    static let shared = APIService()
    private init() {}

    // MARK: Token Storage (Keychain — secure; tenantSlug is non-sensitive and stays in UserDefaults)
    private let tokenKey        = "pos_access_token"
    private let refreshTokenKey = "pos_refresh_token"
    private let tenantSlugKey   = "pos_tenant_slug"

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
    var isAuthenticated: Bool { accessToken != nil }

    // MARK: Generic request
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        formData: [String: String]? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: APIConfig.apiV1 + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.timeoutInterval = 30

        if requiresAuth, let token = accessToken {
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
        if http.statusCode == 401, let refresh = refreshToken {
            try await refreshAccessToken(refresh)
            return try await request(path: path, method: method, body: body,
                                     formData: formData, requiresAuth: requiresAuth)
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
    private func rawData(path: String, method: HTTPMethod, body: Encodable?) async throws -> Data {
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
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401, let refresh = refreshToken {
            try await refreshAccessToken(refresh)
            return try await rawData(path: path, method: method, body: body)
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
        guard let url = URL(string: APIConfig.apiV1 + "/auth/refresh") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RefreshReq(refresh_token: token))
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode(RefreshResp.self, from: data)
        accessToken = resp.access_token
        if let rt = resp.refresh_token { refreshToken = rt }
    }

    // MARK: Login
    func login(email: String, password: String) async throws -> TokenResponse {
        let form = ["username": email, "password": password, "grant_type": "password"]
        return try await request(path: "/auth/login", method: .post, formData: form, requiresAuth: false)
    }

    func loginWithPIN(email: String, pin: String) async throws -> TokenResponse {
        let body = LoginPINRequest(email: email, pin: pin)
        return try await request(path: "/auth/login-pin", method: .post, body: body, requiresAuth: false)
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

    func fetchOrders(status: String? = nil, page: Int = 1) async throws -> [Order] {
        var path = "/orders?page=\(page)&per_page=50"
        if let s = status { path += "&status=\(s)" }
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

    func getShiftSummary(_ shiftId: String) async throws -> Shift {
        return try await request(path: "/shifts/\(shiftId)/summary")
    }

    // MARK: Reports
    func fetchDashboard(range: String = "7d") async throws -> DashboardSummary {
        return try await request(path: "/reports/dashboard?range=\(range)")
    }

    // MARK: Settings
    func fetchSettings() async throws -> AppSettings {
        return try await request(path: "/settings")
    }

    func updateSettings(_ settings: AppSettings) async throws -> AppSettings {
        return try await request(path: "/settings", method: .put, body: settings)
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
}
