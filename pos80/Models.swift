// Models.swift — All API data models for Ampos POS
import Foundation

// MARK: - Auth
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let userId: String
    let role: String
    let nameEn: String
    let nameAr: String
    let tenantId: String?
    let tenantSlug: String?
    let tenantName: String?
    let tenantNameAr: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case userId = "user_id"
        case role, nameEn = "name_en", nameAr = "name_ar"
        case tenantId = "tenant_id"
        case tenantSlug = "tenant_slug"
        case tenantName = "tenant_name"
        case tenantNameAr = "tenant_name_ar"
    }
}

struct ResolveTenantCodeRequest: Codable {
    let tenantCode: String

    enum CodingKeys: String, CodingKey {
        case tenantCode = "tenant_code"
    }
}

struct TenantCodeResponse: Codable, Equatable {
    let tenantSlug: String
    let tenantName: String
    let tenantNameAr: String

    enum CodingKeys: String, CodingKey {
        case tenantSlug = "tenant_slug"
        case tenantName = "tenant_name"
        case tenantNameAr = "tenant_name_ar"
    }
}

struct LoginPINRequest: Codable {
    let email: String
    let pin: String
}

struct POSUserPreview: Codable, Identifiable {
    let id: String
    let email: String
    let nameEn: String
    let nameAr: String
    let role: String
    let avatarURL: String?
    let branchId: String?

    enum CodingKeys: String, CodingKey {
        case id, email, role
        case nameEn = "name_en"
        case nameAr = "name_ar"
        case avatarURL = "avatar_url"
        case branchId = "branch_id"
    }

    var displayName: String {
        let primary = nameEn.trimmingCharacters(in: .whitespacesAndNewlines)
        return primary.isEmpty ? email : primary
    }

    var isManager: Bool {
        role == "manager" || role == "owner" || role == "super_admin"
    }
}

// MARK: - Category
struct ProductCategory: Codable, Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let descriptionAr: String?
    let descriptionEn: String?
    let imageUrl: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case nameAr = "name_ar", nameEn = "name_en"
        case descriptionAr = "description_ar", descriptionEn = "description_en"
        case imageUrl = "image_url"
        case sortOrder = "sort_order"
    }

    var resolvedImageURL: URL? {
        APIConfig.resolvedMediaURL(imageUrl)
    }
}

// MARK: - Products
struct Product: Codable, Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let descriptionAr: String?
    let descriptionEn: String?
    let price: Double
    let costPrice: Double?
    let sku: String?
    let barcode: String?
    let imageUrl: String?
    let categoryId: String
    let isTaxable: Bool
    let prepTimeMinutes: Int?
    let isAvailable: Bool?
    let modifiers: [ProductModifier]?

    enum CodingKeys: String, CodingKey {
        case id
        case nameAr = "name_ar", nameEn = "name_en"
        case descriptionAr = "description_ar", descriptionEn = "description_en"
        case price
        case costPrice = "cost_price"
        case sku, barcode
        case imageUrl = "image_url"
        case categoryId = "category_id"
        case isTaxable = "is_taxable"
        case prepTimeMinutes = "prep_time_minutes"
        case isAvailable = "is_available"
        case modifiers
    }

    var resolvedImageURL: URL? {
        APIConfig.resolvedMediaURL(imageUrl)
    }
}

struct ProductModifier: Codable, Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let isRequired: Bool
    let minSelections: Int
    let maxSelections: Int
    let options: [ModifierOption]

    enum CodingKeys: String, CodingKey {
        case id
        case nameAr = "name_ar", nameEn = "name_en"
        case isRequired = "is_required"
        case minSelections = "min_selections"
        case maxSelections = "max_selections"
        case options
    }
}

struct ModifierOption: Codable, Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let priceDelta: Double
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nameAr = "name_ar", nameEn = "name_en"
        case priceDelta = "price_delta"
        case isDefault = "is_default"
    }
}

// MARK: - Cart
struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    var quantity: Int
    var notes: String?
    var selectedModifiers: [SelectedModifier]

    var unitPrice: Double {
        product.price + selectedModifiers.reduce(0) { $0 + $1.priceDelta }
    }
    var lineTotal: Double { unitPrice * Double(quantity) }

    var modifierSummary: String {
        selectedModifiers.map { $0.nameAr.isEmpty ? $0.nameEn : "\($0.nameAr) (\($0.nameEn))" }.joined(separator: ", ")
    }
}

struct SelectedModifier: Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let priceDelta: Double
}

// MARK: - Orders
enum OrderType: String, Codable, CaseIterable {
    case dineIn = "dine_in"
    case takeaway
    case delivery
    case qrSelfService = "qr_self_service"

    var displayName: String {
        switch self {
        case .dineIn: return "Dine In"
        case .takeaway: return "Takeaway"
        case .delivery: return "Delivery"
        case .qrSelfService: return "QR Self-Service"
        }
    }
    var icon: String {
        switch self {
        case .dineIn: return "fork.knife"
        case .takeaway: return "bag"
        case .delivery: return "bicycle"
        case .qrSelfService: return "qrcode"
        }
    }
}

enum OrderStatus: String, Codable {
    case draft, received, preparing, ready, served, paid, cancelled, void

    var displayName: String { rawValue.capitalized }
    var color: String {
        switch self {
        case .draft: return "94A3B8"
        case .received: return "38BDF8"
        case .preparing: return "FBBF24"
        case .ready: return "10D9A0"
        case .served: return "818CF8"
        case .paid: return "10D9A0"
        case .cancelled, .void: return "F87171"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable {
    case cash, card, apple_pay, mada, credit, split

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .apple_pay: return "Apple Pay"
        case .mada: return "Mada"
        case .credit: return "Credit"
        case .split: return "Split"
        }
    }
    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .apple_pay: return "apple.logo"
        case .mada: return "creditcard.fill"
        case .credit: return "creditcard.and.123"
        case .split: return "arrow.branch"
        }
    }
}

struct OrderCreate: Codable {
    let orderType: String
    let tableId: String?
    let items: [OrderItemIn]
    let notes: String?
    let customerName: String?
    let customerPhone: String?
    let localId: String?
    let couponCode: String?

    enum CodingKeys: String, CodingKey {
        case orderType = "order_type"
        case tableId = "table_id"
        case items, notes
        case customerName = "customer_name"
        case customerPhone = "customer_phone"
        case localId = "local_id"
        case couponCode = "coupon_code"
    }
}

struct OrderItemIn: Codable {
    let productId: String
    let quantity: Int
    let unitPrice: Double
    let notes: String?
    let modifiers: [OrderItemModifierIn]

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case quantity
        case unitPrice = "unit_price"
        case notes, modifiers
    }
}

struct OrderItemModifierIn: Codable {
    let modifierOptionId: String
    let optionNameAr: String
    let optionNameEn: String
    let priceDelta: Double

    enum CodingKeys: String, CodingKey {
        case modifierOptionId = "modifier_option_id"
        case optionNameAr = "option_name_ar"
        case optionNameEn = "option_name_en"
        case priceDelta = "price_delta"
    }
}

struct OrderPayment: Codable {
    let paymentMethod: String
    let paymentReference: String?
    let cashTendered: Double?

    enum CodingKeys: String, CodingKey {
        case paymentMethod = "payment_method"
        case paymentReference = "payment_reference"
        case cashTendered = "cash_tendered"
    }
}

struct DiscountRequest: Codable {
    let discountAmount: Double
    let reason: String?
    enum CodingKeys: String, CodingKey {
        case discountAmount = "discount_amount"
        case reason
    }
}

struct CouponValidateRequest: Codable {
    let code: String
    let orderSubtotal: Double

    enum CodingKeys: String, CodingKey {
        case code
        case orderSubtotal = "order_subtotal"
    }
}

struct CouponValidationResult: Codable {
    let valid: Bool
    let couponId: String?
    let code: String?
    let discountAmount: Double
    let message: String

    enum CodingKeys: String, CodingKey {
        case valid, code, message
        case couponId = "coupon_id"
        case discountAmount = "discount_amount"
    }
}

struct LoyaltyCustomer: Decodable, Identifiable {
    let id: String
    let name: String
    let phone: String
    let email: String?
    let pointsBalance: Int
    let totalOrders: Int?
    let totalSpent: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, phone, email
        case nameAr = "name_ar"
        case nameEn = "name_en"
        case pointsBalance = "points_balance"
        case availablePoints = "available_points"
        case totalPoints = "total_points"
        case points
        case totalOrders = "total_orders"
        case ordersCount = "orders_count"
        case totalSpent = "total_spent"
        case spent = "spent"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        if let stringId = try? c.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }

        let localizedName = (try? c.decode(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameEn = (try? c.decode(String.self, forKey: .nameEn))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameAr = (try? c.decode(String.self, forKey: .nameAr))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateNames: [String?] = [localizedName, nameEn, nameAr]
        var resolvedName = "Customer"
        for candidate in candidateNames {
            guard let candidate, !candidate.isEmpty else { continue }
            resolvedName = candidate
            break
        }
        name = resolvedName

        phone = (try? c.decode(String.self, forKey: .phone)) ?? ""
        email = try? c.decode(String.self, forKey: .email)
        pointsBalance = (try? c.decode(Int.self, forKey: .pointsBalance))
            ?? (try? c.decode(Int.self, forKey: .availablePoints))
            ?? (try? c.decode(Int.self, forKey: .totalPoints))
            ?? (try? c.decode(Int.self, forKey: .points))
            ?? 0
        totalOrders = (try? c.decode(Int.self, forKey: .totalOrders))
            ?? (try? c.decode(Int.self, forKey: .ordersCount))
        totalSpent = (try? c.decode(Double.self, forKey: .totalSpent))
            ?? (try? c.decode(Double.self, forKey: .spent))
    }
}

struct CustomerInsight: Decodable, Identifiable {
    let id: String
    let name: String
    let phone: String?
    let pointsBalance: Int
    let totalOrders: Int?
    let totalSpent: Double?
    let lastOrderAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, phone
        case nameAr = "name_ar"
        case nameEn = "name_en"
        case pointsBalance = "points_balance"
        case availablePoints = "available_points"
        case points
        case totalOrders = "total_orders"
        case ordersCount = "orders_count"
        case totalSpent = "total_spent"
        case spent = "spent"
        case lastOrderAt = "last_order_at"
        case latestOrderAt = "latest_order_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let phoneValue = try? c.decode(String.self, forKey: .phone)
        let primaryName = (try? c.decode(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameEn = (try? c.decode(String.self, forKey: .nameEn))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameAr = (try? c.decode(String.self, forKey: .nameAr))?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateNames: [String?] = [primaryName, nameEn, nameAr]
        var resolvedName = "Customer"
        for candidate in candidateNames {
            guard let candidate, !candidate.isEmpty else { continue }
            resolvedName = candidate
            break
        }
        name = resolvedName

        if let stringId = try? c.decode(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = phoneValue ?? name
        }

        phone = phoneValue
        pointsBalance = (try? c.decode(Int.self, forKey: .pointsBalance))
            ?? (try? c.decode(Int.self, forKey: .availablePoints))
            ?? (try? c.decode(Int.self, forKey: .points))
            ?? 0
        totalOrders = (try? c.decode(Int.self, forKey: .totalOrders))
            ?? (try? c.decode(Int.self, forKey: .ordersCount))
        totalSpent = (try? c.decode(Double.self, forKey: .totalSpent))
            ?? (try? c.decode(Double.self, forKey: .spent))
        lastOrderAt = (try? c.decode(String.self, forKey: .lastOrderAt))
            ?? (try? c.decode(String.self, forKey: .latestOrderAt))
    }
}

// MARK: - Order Response
struct Order: Identifiable {
    let id: String
    let orderNumber: String?
    let displayNumber: Int?
    let orderType: String
    let status: String
    let tableId: String?
    let tableNumber: String?
    let customerName: String?
    let items: [OrderItem]?
    let subtotal: Double?
    let vatAmount: Double?
    let discountAmount: Double?
    let total: Double?
    let paymentMethod: String?
    let notes: String?
    let createdAt: String?
    let paidAt: String?

    var orderStatus: OrderStatus { OrderStatus(rawValue: status) ?? .draft }
    var totalSafe: Double { total ?? 0 }
    var displayTableNumber: String? {
        guard let tableNumber, !tableNumber.isEmpty else { return nil }
        let trimmed = tableNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.uppercased().hasPrefix("T") ? trimmed : "T\(trimmed)"
    }
}

extension Order: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case orderId       = "order_id"   // API alternate key
        case orderNumber   = "order_number"
        case displayNumber = "display_number"
        case orderType     = "order_type"
        case status
        case tableId       = "table_id"
        case tableNumber   = "table_number"
        case customerName  = "customer_name"
        case items, subtotal
        case totalAmount   = "total_amount"  // API alternate key
        case vatAmount     = "vat_amount"
        case discountAmount = "discount_amount"
        case total
        case paymentMethod = "payment_method"
        case notes
        case createdAt = "created_at"
        case paidAt    = "paid_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id: try "id" first, then "order_id" (actual API key)
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else if let n = try? c.decode(Int.self, forKey: .id) { id = "\(n)" }
        else if let s = try? c.decode(String.self, forKey: .orderId) { id = s }
        else if let n = try? c.decode(Int.self, forKey: .orderId) { id = "\(n)" }
        else { throw DecodingError.keyNotFound(CodingKeys.id,
               .init(codingPath: c.codingPath, debugDescription: "Missing order id/order_id")) }

        orderNumber   = try? c.decode(String.self, forKey: .orderNumber)
        displayNumber = try? c.decode(Int.self,    forKey: .displayNumber)
        orderType     = ((try? c.decode(String.self, forKey: .orderType)) ?? "dine_in").lowercased()
        status        = ((try? c.decode(String.self, forKey: .status)) ?? "draft").lowercased()
        tableId       = try? c.decode(String.self, forKey: .tableId)
        tableNumber   = try? c.decode(String.self, forKey: .tableNumber)
        customerName  = try? c.decode(String.self, forKey: .customerName)
        items         = try? c.decode([OrderItem].self, forKey: .items)
        subtotal      = try? c.decode(Double.self, forKey: .subtotal)
        vatAmount     = try? c.decode(Double.self, forKey: .vatAmount)
        discountAmount = try? c.decode(Double.self, forKey: .discountAmount)
        total         = (try? c.decode(Double.self, forKey: .total))
                     ?? (try? c.decode(Double.self, forKey: .totalAmount))
        paymentMethod = try? c.decode(String.self, forKey: .paymentMethod)
        notes         = try? c.decode(String.self, forKey: .notes)
        createdAt     = try? c.decode(String.self, forKey: .createdAt)
        paidAt        = try? c.decode(String.self, forKey: .paidAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,         forKey: .id)
        try? c.encode(orderNumber,   forKey: .orderNumber)
        try? c.encode(displayNumber, forKey: .displayNumber)
        try c.encode(orderType,      forKey: .orderType)
        try c.encode(status,         forKey: .status)
        try? c.encode(tableId,       forKey: .tableId)
        try? c.encode(tableNumber,   forKey: .tableNumber)
        try? c.encode(customerName,  forKey: .customerName)
        try? c.encode(items,         forKey: .items)
        try? c.encode(subtotal,      forKey: .subtotal)
        try? c.encode(vatAmount,     forKey: .vatAmount)
        try? c.encode(discountAmount,forKey: .discountAmount)
        try? c.encode(total,         forKey: .total)
        try? c.encode(paymentMethod, forKey: .paymentMethod)
        try? c.encode(notes,         forKey: .notes)
        try? c.encode(createdAt,     forKey: .createdAt)
        try? c.encode(paidAt,        forKey: .paidAt)
    }
}

struct OrderItem: Identifiable {
    let id: String
    let productId: String?
    let productNameEn: String?
    let productNameAr: String?
    let quantity: Int
    let unitPrice: Double
    let lineTotal: Double?
    let notes: String?
}

extension OrderItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case productId      = "product_id"
        case productNameEn  = "product_name_en"
        case productNameAr  = "product_name_ar"
        case quantity
        case unitPrice      = "unit_price"
        case lineTotal      = "line_total"
        case notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? c.decode(String.self, forKey: .id) { id = s }
        else if let n = try? c.decode(Int.self, forKey: .id) { id = "\(n)" }
        else { id = UUID().uuidString }

        productId     = try? c.decode(String.self, forKey: .productId)
        productNameEn = try? c.decode(String.self, forKey: .productNameEn)
        productNameAr = try? c.decode(String.self, forKey: .productNameAr)
        quantity      = (try? c.decode(Int.self,    forKey: .quantity)) ?? 1
        unitPrice     = (try? c.decode(Double.self, forKey: .unitPrice)) ?? 0
        lineTotal     = try? c.decode(Double.self, forKey: .lineTotal)
        notes         = try? c.decode(String.self, forKey: .notes)
    }
}

// MARK: - Tables
struct RestaurantTable: Codable, Identifiable {
    let id: String
    let number: String
    let nameAr: String?
    let nameEn: String?
    let capacity: Int
    let section: String?
    let posX: Double?
    let posY: Double?
    let status: String?
    let currentOrderId: String?

    enum CodingKeys: String, CodingKey {
        case id, number
        case nameAr = "name_ar", nameEn = "name_en"
        case capacity, section
        case posX = "pos_x", posY = "pos_y"
        case status
        case currentOrderId = "current_order_id"
    }

    var isOccupied: Bool { status == "occupied" }
    var displayLabel: String {
        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.uppercased().hasPrefix("T") ? trimmed : "T\(trimmed)"
    }
}

// MARK: - Shifts
struct Shift: Identifiable {
    let id: String
    let openingCash: Double
    let closingCash: Double?
    let notes: String?
    let status: String?
    let openedAt: String?
    let closedAt: String?
    let totalSales: Double?
    let totalOrders: Int?
    let cashSales: Double?
    let cardSales: Double?
}

extension Shift: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case shiftId   = "shift_id"
        case openingCash  = "opening_cash"
        case closingCash  = "closing_cash"
        case notes, status
        case openedAt  = "opened_at"
        case closedAt  = "closed_at"
        case totalSales   = "total_sales"
        case totalOrders  = "total_orders"
        case cashSales    = "cash_sales"
        case cardSales    = "card_sales"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id may be String, Int, or under key "shift_id"
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let n = try? c.decode(Int.self, forKey: .id) {
            id = "\(n)"
        } else if let s = try? c.decode(String.self, forKey: .shiftId) {
            id = s
        } else if let n = try? c.decode(Int.self, forKey: .shiftId) {
            id = "\(n)"
        } else {
            id = UUID().uuidString
        }
        openingCash  = (try? c.decode(Double.self, forKey: .openingCash))  ?? 0
        closingCash  = try? c.decode(Double.self, forKey: .closingCash)
        notes        = try? c.decode(String.self, forKey: .notes)
        status       = try? c.decode(String.self, forKey: .status)
        openedAt     = try? c.decode(String.self, forKey: .openedAt)
        closedAt     = try? c.decode(String.self, forKey: .closedAt)
        totalSales   = try? c.decode(Double.self, forKey: .totalSales)
        totalOrders  = try? c.decode(Int.self,    forKey: .totalOrders)
        cashSales    = try? c.decode(Double.self, forKey: .cashSales)
        cardSales    = try? c.decode(Double.self, forKey: .cardSales)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(openingCash,  forKey: .openingCash)
        try? c.encode(closingCash, forKey: .closingCash)
        try? c.encode(notes,       forKey: .notes)
        try? c.encode(status,      forKey: .status)
        try? c.encode(openedAt,    forKey: .openedAt)
        try? c.encode(closedAt,    forKey: .closedAt)
        try? c.encode(totalSales,  forKey: .totalSales)
        try? c.encode(totalOrders, forKey: .totalOrders)
        try? c.encode(cashSales,   forKey: .cashSales)
        try? c.encode(cardSales,   forKey: .cardSales)
    }
}

struct OpenShiftRequest: Codable {
    let openingCash: Double
    enum CodingKeys: String, CodingKey { case openingCash = "opening_cash" }
}

struct CloseShiftRequest: Codable {
    let closingCash: Double
    let notes: String?
    enum CodingKeys: String, CodingKey {
        case closingCash = "closing_cash"
        case notes
    }
}

struct CashDropRequest: Codable {
    let amount: Double
    let notes: String?
    let isBlind: Bool

    enum CodingKeys: String, CodingKey {
        case amount, notes
        case isBlind = "is_blind"
    }
}

struct ShiftCashDrop: Codable, Identifiable {
    var id: String { "\(createdAt ?? UUID().uuidString)-\(amount)" }
    let amount: Double
    let notes: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case amount, notes
        case createdAt = "created_at"
    }
}

struct ShiftSummaryOrder: Codable, Identifiable {
    let id: String
    let orderNumber: String?
    let total: Double
    let paymentMethod: String?

    enum CodingKeys: String, CodingKey {
        case id, total
        case orderNumber = "order_number"
        case paymentMethod = "payment_method"
    }
}

struct ShiftSummary: Codable, Identifiable {
    let id: String
    let status: String?
    let openingCash: Double
    let closingCash: Double?
    let expectedCash: Double?
    let cashDifference: Double?
    let totalSales: Double?
    let totalOrders: Int?
    let totalCashSales: Double?
    let totalCardSales: Double?
    let totalVat: Double?
    let openedAt: String?
    let closedAt: String?
    let notes: String?
    let cashDrops: [ShiftCashDrop]
    let orders: [ShiftSummaryOrder]

    enum CodingKeys: String, CodingKey {
        case id, status, notes, orders
        case openingCash = "opening_cash"
        case closingCash = "closing_cash"
        case expectedCash = "expected_cash"
        case cashDifference = "cash_difference"
        case totalSales = "total_sales"
        case totalOrders = "total_orders"
        case totalCashSales = "total_cash_sales"
        case totalCardSales = "total_card_sales"
        case totalVat = "total_vat"
        case openedAt = "opened_at"
        case closedAt = "closed_at"
        case cashDrops = "cash_drops"
    }
}

// MARK: - Reports / Dashboard
struct DashboardSummary: Codable {
    let totalRevenue: Double
    let totalOrders: Int
    let avgOrderValue: Double
    let totalVat: Double
    let totalDiscounts: Double
    let ordersToday: Int
    let revenueToday: Double
    let activeStaff: Int
    let avgOrderTimeMin: Double
    let hourlyTrend: [HourlyTrend]
    let topProducts: [DashboardTopProduct]
    let revenueByOrderType: [String: Double]
    let revenueByPaymentMethod: [String: Double]

    enum CodingKeys: String, CodingKey {
        case totalRevenue = "total_revenue"
        case totalOrders = "total_orders"
        case avgOrderValue = "avg_order_value"
        case totalVat = "total_vat"
        case totalDiscounts = "total_discounts"
        case ordersToday = "orders_today"
        case revenueToday = "revenue_today"
        case activeStaff = "active_staff"
        case avgOrderTimeMin = "avg_order_time_min"
        case hourlyTrend = "hourly_trend"
        case topProducts = "top_products"
        case revenueByOrderType = "revenue_by_order_type"
        case revenueByPaymentMethod = "revenue_by_payment_method"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalRevenue = (try? c.decode(Double.self, forKey: .totalRevenue)) ?? 0
        totalOrders = (try? c.decode(Int.self, forKey: .totalOrders)) ?? 0
        avgOrderValue = (try? c.decode(Double.self, forKey: .avgOrderValue)) ?? 0
        totalVat = (try? c.decode(Double.self, forKey: .totalVat)) ?? 0
        totalDiscounts = (try? c.decode(Double.self, forKey: .totalDiscounts)) ?? 0
        ordersToday = (try? c.decode(Int.self, forKey: .ordersToday)) ?? 0
        revenueToday = (try? c.decode(Double.self, forKey: .revenueToday)) ?? 0
        activeStaff = (try? c.decode(Int.self, forKey: .activeStaff)) ?? 0
        avgOrderTimeMin = (try? c.decode(Double.self, forKey: .avgOrderTimeMin)) ?? 0
        hourlyTrend = (try? c.decode([HourlyTrend].self, forKey: .hourlyTrend)) ?? []
        topProducts = (try? c.decode([DashboardTopProduct].self, forKey: .topProducts)) ?? []
        revenueByOrderType = (try? c.decode([String: Double].self, forKey: .revenueByOrderType)) ?? [:]
        revenueByPaymentMethod = (try? c.decode([String: Double].self, forKey: .revenueByPaymentMethod)) ?? [:]
    }
}

struct HourlyTrend: Codable, Identifiable {
    var id: String { hour }
    let hour: String
    let orders: Int
    let revenue: Double
}

/// Lightweight top-product from the dashboard endpoint ({name, count})
struct DashboardTopProduct: Codable, Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

/// Full top-product from /reports/top-products endpoint
struct TopProduct: Codable, Identifiable {
    var id: String { nameEn }
    let nameEn: String
    let nameAr: String
    let totalQty: Int
    let totalRevenue: Double

    enum CodingKeys: String, CodingKey {
        case nameEn = "name_en"
        case nameAr = "name_ar"
        case totalQty = "total_qty"
        case totalRevenue = "total_revenue"
    }
}

struct PaymentSummaryRow: Codable, Identifiable {
    var id: String { method }
    let method: String
    let count: Int
    let total: Double
    let vat: Double
}

struct ZATCAReport: Codable {
    let totalInvoices: Int
    let totalVatCollected: Double
    let byStatus: [String: Int]

    enum CodingKeys: String, CodingKey {
        case totalInvoices = "total_invoices"
        case totalVatCollected = "total_vat_collected"
        case byStatus = "by_status"
    }
}

// MARK: - Settings
struct AppSettings: Codable {
    var receiptPrinterIp: String?
    var receiptPrinterPort: Int?
    var kitchenPrinterIp: String?
    var kitchenPrinterPort: Int?
    var timezone: String?
    var currency: String?
    var vatNumber: String?
    var receiptFooter: String?
    var paperSize: String?
    var receiptFontSize: String?
    var printMode: String?

    enum CodingKeys: String, CodingKey {
        case receiptPrinterIp = "receipt_printer_ip"
        case receiptPrinterPort = "receipt_printer_port"
        case kitchenPrinterIp = "kitchen_printer_ip"
        case kitchenPrinterPort = "kitchen_printer_port"
        case timezone, currency
        case vatNumber = "vat_number"
        case receiptFooter = "receipt_footer"
        case paperSize = "paper_size"
        case receiptFontSize = "receipt_font_size"
        case printMode = "print_mode"
    }
}

struct BroadcastsResponse: Codable {
    let items: [BroadcastItem]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case items
        case unreadCount = "unread_count"
    }
}

struct BroadcastItem: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let audiencePlan: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case audiencePlan = "audience_plan"
        case createdAt = "created_at"
    }
}

// MARK: - Pagination Wrapper (generic)
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]?
    let total: Int?
    let page: Int?
    let perPage: Int?
    let pages: Int?

    enum CodingKeys: String, CodingKey {
        case items, total, page
        case perPage = "per_page"
        case pages
    }
}

// MARK: - API Error
struct APIError: Codable, Error {
    let detail: String?
}

// MARK: - Staff
struct Staff: Codable, Identifiable {
    let id: String
    let nameAr: String
    let nameEn: String
    let email: String
    let role: String
    let isActive: Bool?
    let branchId: String?
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nameAr = "name_ar", nameEn = "name_en"
        case email, role
        case isActive = "is_active"
        case branchId = "branch_id"
        case phone
    }
}

// MARK: - Split Payment
struct SplitEntry: Codable {
    let method: String
    let amount: Double
}

struct SplitPaymentRequest: Codable {
    let splits: [SplitEntry]
}
