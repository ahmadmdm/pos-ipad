// POSViewModel.swift — Business logic for the main POS screen
import SwiftUI
import Combine

@MainActor
final class POSViewModel: ObservableObject {

    enum DiscountOrigin {
        case none
        case manual
        case coupon
        case loyalty
    }

    private let api = APIService.shared
    private let appState = AppState.shared
    private let l10n = L10n.shared
    var offlineManager: OfflineManager { OfflineManager.shared }
    private var invoiceStore: LocalInvoiceStore { LocalInvoiceStore.shared }

    // MARK: Menu Data
    @Published var categories: [ProductCategory] = []
    @Published var products: [Product] = []
    @Published var selectedCategory: ProductCategory?
    @Published var isMenuLoading = false

    // MARK: Cart
    @Published var cartItems: [CartItem] = []
    @Published var orderType: OrderType = .dineIn
    @Published var selectedTable: RestaurantTable?
    @Published var customerName: String = ""
    @Published var customerPhone: String = ""
    @Published var orderNotes: String = ""
    @Published var discountAmount: Double = 0
    @Published var discountPercent: Double = 0
    @Published var discountIsPercent: Bool = false
    @Published var discountOrigin: DiscountOrigin = .none
    @Published var couponCode: String = ""
    @Published var appliedCoupon: CouponValidationResult?
    @Published var loyaltyCustomer: LoyaltyCustomer?
    @Published var loyaltyRedemption: RedemptionValidation?
    @Published var loyaltyPointsToRedeem = ""
    @Published var customerInsights: [CustomerInsight] = []
    @Published var isApplyingCoupon = false
    @Published var isApplyingLoyaltyRedemption = false
    @Published var isLookingUpLoyaltyCustomer = false
    @Published var isLoadingCustomerInsights = false

    // MARK: Payment
    @Published var showPaymentSheet = false
    @Published var isProcessingPayment = false
    @Published var lastCompletedOrder: Order?
    @Published var lastCompletedOrderQR: String?

    // MARK: Search & Barcode
    @Published var searchText = ""
    @Published var showBarcodeScanner = false

    // MARK: Modifier selection
    @Published var showModifierSheet = false
    @Published var modifierProduct: Product?

    // MARK: Completed Orders (held)
    @Published var heldOrders: [Order] = []

    // MARK: Tables
    @Published var tables: [RestaurantTable] = []

    // MARK: Errors
    @Published var error: String?

    // MARK: Computed Values
    var filteredProducts: [Product] {
        let base = selectedCategory == nil
            ? products
            : products.filter { $0.categoryId == selectedCategory?.id }
        if searchText.isEmpty { return base }
        return base.filter {
            $0.nameEn.localizedCaseInsensitiveContains(searchText) ||
            $0.nameAr.contains(searchText) ||
            ($0.barcode?.contains(searchText) ?? false)
        }
    }

    var cartSubtotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    var cartVAT: Double { (cartSubtotal - discountAmount) * 0.15 }
    var cartTotal: Double { cartSubtotal - discountAmount + cartVAT }
    var cartCount: Int { cartItems.reduce(0) { $0 + $1.quantity } }
    var isEmpty: Bool { cartItems.isEmpty }
    var discountSummaryLabel: String {
        if let coupon = appliedCoupon, let code = coupon.code ?? nonEmptyTrimmed(couponCode) {
            return "\(l10n.discount) (\(code))"
        }
        if discountOrigin == .loyalty {
            return l10n.loyaltyDiscount
        }
        if discountIsPercent && discountPercent > 0 {
            let pct = discountPercent.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", discountPercent)
                : String(format: "%.1f", discountPercent)
            return "\(l10n.discount) (\(pct)%)"
        }
        return l10n.discount
    }

    // MARK: Menu Cache Keys
    private let cachedCategoriesKey = "cached_menu_categories"
    private let cachedProductsKey   = "cached_menu_products"

    // MARK: Load Menu (with offline fallback to local cache)
    func loadMenu() async {
        isMenuLoading = true
        loadMenuFromCache()
        if selectedCategory == nil, let first = categories.first {
            selectedCategory = first
        }
        do {
            async let cats  = api.fetchCategories()
            async let prods = api.fetchProducts(availableOnly: false)
            let (c, p) = try await (cats, prods)
            categories = c.sorted { $0.sortOrder < $1.sortOrder }
            products   = p
            // Persist to cache for offline use
            if let catData  = try? JSONEncoder().encode(c) { UserDefaults.standard.set(catData,  forKey: cachedCategoriesKey) }
            if let prodData = try? JSONEncoder().encode(p) { UserDefaults.standard.set(prodData, forKey: cachedProductsKey) }
        } catch {
            if !categories.isEmpty {
                // Cache was found, no need to show error
            } else {
                self.error = "No internet connection and no cached menu available."
            }
        }
        if selectedCategory == nil, let first = categories.first {
            selectedCategory = first
        }
        isMenuLoading = false
    }

    private func loadMenuFromCache() {
        if let data = UserDefaults.standard.data(forKey: cachedCategoriesKey),
           let cached = try? JSONDecoder().decode([ProductCategory].self, from: data) {
            categories = cached.sorted { $0.sortOrder < $1.sortOrder }
        }
        if let data = UserDefaults.standard.data(forKey: cachedProductsKey),
           let cached = try? JSONDecoder().decode([Product].self, from: data) {
            products = cached
        }
    }

    func loadTables() async {
        do { tables = try await api.fetchTables() }
        catch { /* Silently fail offline; tables are supplementary */ }
    }

    // MARK: Cart Operations
    func addToCart(product: Product, modifiers: [SelectedModifier] = [], notes: String? = nil) {
        // If same product + same modifiers, increment quantity
        if let idx = cartItems.firstIndex(where: {
            $0.product.id == product.id &&
            $0.selectedModifiers.map(\.id) == modifiers.map(\.id)
        }) {
            cartItems[idx].quantity += 1
        } else {
            cartItems.append(CartItem(product: product, quantity: 1, notes: notes, selectedModifiers: modifiers))
        }
        recomputePercentDiscountIfNeeded()
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    func incrementItem(_ item: CartItem) {
        guard let idx = cartItems.firstIndex(where: { $0.id == item.id }) else { return }
        cartItems[idx].quantity += 1
        recomputePercentDiscountIfNeeded()
    }

    func decrementItem(_ item: CartItem) {
        guard let idx = cartItems.firstIndex(where: { $0.id == item.id }) else { return }
        if cartItems[idx].quantity > 1 { cartItems[idx].quantity -= 1 }
        else { cartItems.remove(at: idx) }
        recomputePercentDiscountIfNeeded()
    }

    func removeItem(_ item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
        recomputePercentDiscountIfNeeded()
    }

    func replaceModifiers(for item: CartItem, with newModifiers: [SelectedModifier]) {
        guard let idx = cartItems.firstIndex(where: { $0.id == item.id }) else { return }
        cartItems[idx].selectedModifiers = newModifiers
        recomputePercentDiscountIfNeeded()
    }

    func clearCart() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            cartItems.removeAll()
            orderType = .dineIn
            clearDiscountState()
            customerName = ""
            customerPhone = ""
            loyaltyCustomer = nil
            orderNotes = ""
            selectedTable = nil
        }
    }

    func applyDiscount(_ amount: Double) {
        appliedCoupon = nil
        couponCode = ""
        loyaltyRedemption = nil
        loyaltyPointsToRedeem = ""
        discountOrigin = .manual
        discountIsPercent = false
        discountPercent = 0
        discountAmount = min(max(amount, 0), cartSubtotal)
    }

    func applyPercentDiscount(_ percent: Double) {
        appliedCoupon = nil
        couponCode = ""
        loyaltyRedemption = nil
        loyaltyPointsToRedeem = ""
        discountOrigin = .manual
        let clamped = min(max(percent, 0), 100)
        discountIsPercent = true
        discountPercent = clamped
        discountAmount = min(cartSubtotal * clamped / 100.0, cartSubtotal)
    }

    private func recomputePercentDiscountIfNeeded() {
        guard discountIsPercent, discountOrigin == .manual else { return }
        discountAmount = min(cartSubtotal * discountPercent / 100.0, cartSubtotal)
    }

    func clearDiscountState() {
        discountAmount = 0
        discountPercent = 0
        discountIsPercent = false
        discountOrigin = .none
        appliedCoupon = nil
        couponCode = ""
        loyaltyRedemption = nil
        loyaltyPointsToRedeem = ""
    }

    func applyCoupon() async -> Bool {
        let trimmedCode = nonEmptyTrimmed(couponCode)?.uppercased() ?? ""
        guard !trimmedCode.isEmpty else {
            appState.showError(l10n.enterCouponCode)
            return false
        }
        guard cartSubtotal > 0 else {
            appState.showError(l10n.addItemsBeforeCoupon)
            return false
        }

        isApplyingCoupon = true
        defer { isApplyingCoupon = false }

        do {
            let result = try await api.validateCoupon(code: trimmedCode, orderSubtotal: cartSubtotal)
            guard result.valid else {
                clearDiscountState()
                let message = result.message.isEmpty ? l10n.couponInvalid : result.message
                error = message
                appState.showError(message)
                return false
            }

            appliedCoupon = result
            couponCode = (result.code ?? trimmedCode).uppercased()
            loyaltyRedemption = nil
            loyaltyPointsToRedeem = ""
            discountOrigin = .coupon
            discountAmount = min(result.discountAmount, cartSubtotal)
            appState.showSuccess(result.message.isEmpty ? l10n.couponApplied(couponCode) : result.message)
            return true
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
            return false
        }
    }

    func removeCoupon() {
        guard discountOrigin == .coupon || appliedCoupon != nil else { return }
        clearDiscountState()
    }

    func loadCustomerInsights(limit: Int = 12) async {
        guard !isLoadingCustomerInsights else { return }
        isLoadingCustomerInsights = true
        defer { isLoadingCustomerInsights = false }

        do {
            customerInsights = try await api.fetchCustomerInsights(limit: limit)
        } catch {
            customerInsights = []
        }
    }

    func lookupLoyaltyCustomer() async {
        let trimmedPhone = nonEmptyTrimmed(customerPhone) ?? ""
        guard !trimmedPhone.isEmpty else {
            loyaltyCustomer = nil
            appState.showError(l10n.enterCustomerPhone)
            return
        }

        isLookingUpLoyaltyCustomer = true
        defer { isLookingUpLoyaltyCustomer = false }

        do {
            let customer = try await api.lookupLoyaltyCustomer(phone: trimmedPhone)
            loyaltyCustomer = customer
            customerPhone = customer.phone.isEmpty ? trimmedPhone : customer.phone
            if customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                customerName = customer.name
            }
            appState.showSuccess(l10n.loyaltyCustomerLoaded)
        } catch {
            loyaltyCustomer = nil
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
        }
    }

    func selectCustomerInsight(_ insight: CustomerInsight) {
        customerName = insight.name
        customerPhone = insight.phone ?? ""
        guard let matchingPhone = insight.phone, !matchingPhone.isEmpty else { return }
        Task { await lookupLoyaltyCustomer() }
    }

    func applyLoyaltyRedemption() async -> Bool {
        guard let loyaltyCustomer else {
            appState.showError(l10n.lookupLoyalty)
            return false
        }
        guard let points = Int(loyaltyPointsToRedeem), points > 0 else {
            appState.showError(l10n.pointsToRedeem)
            return false
        }
        guard cartSubtotal > 0 else {
            appState.showError(l10n.addItemsBeforeCoupon)
            return false
        }

        isApplyingLoyaltyRedemption = true
        defer { isApplyingLoyaltyRedemption = false }

        do {
            let validation = try await api.validateLoyaltyRedemption(
                RedeemRequest(customerId: loyaltyCustomer.id, orderId: nil, points: points)
            )
            guard validation.valid else {
                loyaltyRedemption = nil
                discountOrigin = .none
                discountAmount = 0
                appState.showError(validation.message ?? l10n.insufficientPoints)
                return false
            }
            loyaltyRedemption = validation
            appliedCoupon = nil
            couponCode = ""
            discountOrigin = .loyalty
            discountAmount = min(validation.discountAmount ?? 0, cartSubtotal)
            appState.showSuccess(validation.message ?? l10n.pointsRedeemed)
            return true
        } catch {
            appState.showError(error.localizedDescription)
            return false
        }
    }

    func clearLoyaltyRedemption() {
        guard discountOrigin == .loyalty || loyaltyRedemption != nil else { return }
        discountAmount = 0
        discountOrigin = .none
        loyaltyRedemption = nil
        loyaltyPointsToRedeem = ""
    }

    func commitLoyaltyRedemption(orderId: String) async -> Bool {
        guard let loyaltyCustomer,
              let points = Int(loyaltyPointsToRedeem),
              points > 0,
              discountOrigin == .loyalty else { return true }
        do {
            let result = try await api.redeemLoyaltyPoints(
                RedeemRequest(customerId: loyaltyCustomer.id, orderId: orderId, points: points)
            )
            if result.valid == false {
                appState.showError(result.message ?? l10n.insufficientPoints)
                return false
            }
            return true
        } catch {
            appState.showError(error.localizedDescription)
            return false
        }
    }

    func earnLoyaltyPointsIfNeeded(order: Order, totalAmount: Double) async {
        guard let loyaltyCustomer else { return }
        do {
            try await api.earnLoyaltyPoints(EarnRequest(customerId: loyaltyCustomer.id, orderId: order.id, totalAmount: totalAmount))
        } catch {
            // Non-blocking. Payment already succeeded.
        }
    }

    func toggleAvailability(for product: Product) async {
        do {
            let updated = try await api.toggleProductAvailability(product.id)
            if let idx = products.firstIndex(where: { $0.id == updated.id }) {
                products[idx] = updated
            }
            appState.showSuccess((updated.isAvailable ?? true) ? l10n.productAvailable : l10n.productUnavailable)
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    // MARK: Place Order
    func placeOrder() async -> Order? {
        guard !cartItems.isEmpty else { return nil }
        guard appState.currentShift != nil else {
            error = "Please open a shift before placing orders."
            return nil
        }

        let orderItems: [OrderItemIn] = cartItems.map { item in
            let mods = item.selectedModifiers.map { mod in
                OrderItemModifierIn(
                    modifierOptionId: mod.id,
                    optionNameAr: mod.nameAr,
                    optionNameEn: mod.nameEn,
                    priceDelta: mod.priceDelta)
            }
            return OrderItemIn(
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                notes: item.notes,
                modifiers: mods)
        }

        let localId = UUID().uuidString
        let create = OrderCreate(
            orderType: orderType.rawValue,
            tableId: selectedTable?.id,
            items: orderItems,
            notes: orderNotes.isEmpty ? nil : orderNotes,
            customerName: customerName.isEmpty ? nil : customerName,
            customerPhone: customerPhone.isEmpty ? nil : customerPhone,
            localId: localId,
            couponCode: discountOrigin == .coupon ? nonEmptyTrimmed(couponCode) : nil)

        do {
            let order = try await api.createOrder(create)
            // Dispatch dine-in orders to KDS immediately so kitchen can start cooking.
            // Takeaway/delivery orders are dispatched after payment in payOrder().
            if orderType == .dineIn {
                await dispatchToKitchen(orderId: order.id)
            }
            return order
        } catch {
            // If offline, queue for later
            if !offlineManager.isOnline {
                return nil // Caller should use placeOrderOffline instead
            }
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
            return nil
        }
    }

    /// The backend auto-routes newly created orders (status = "received") to the
    /// KDS queue. We only need to nudge the local KDS view to refresh.
    func dispatchToKitchen(orderId: String) async {
        NotificationCenter.default.post(name: Notification.Name("kdsOrdersDidChange"), object: nil)
    }

    /// Cashier action: place the current cart as a kitchen order WITHOUT taking
    /// payment. The order stays in "received" status so it shows up on the KDS
    /// queue immediately. Cashier collects payment later from the Orders screen.
    func sendOrderToKitchenOnly() async {
        guard !cartItems.isEmpty else { return }
        guard let order = await placeOrder() else { return }
        await dispatchToKitchen(orderId: order.id)
        clearCart()
        appState.showSuccess("\(l10n.paymentSuccessfulOrder) #\(order.displayNumber ?? 0) — \(l10n.sentToKitchen)")
        await appState.refreshManagerSnapshot()
    }

    // MARK: Place Order Offline
    func placeOrderOffline(paymentMethod: PaymentMethod, cashTendered: Double?) {
        guard !cartItems.isEmpty else { return }

        let orderItems: [OrderItemIn] = cartItems.map { item in
            let mods = item.selectedModifiers.map { mod in
                OrderItemModifierIn(
                    modifierOptionId: mod.id,
                    optionNameAr: mod.nameAr,
                    optionNameEn: mod.nameEn,
                    priceDelta: mod.priceDelta)
            }
            return OrderItemIn(
                productId: item.product.id,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                notes: item.notes,
                modifiers: mods)
        }

        let localId = UUID().uuidString
        let create = OrderCreate(
            orderType: orderType.rawValue,
            tableId: selectedTable?.id,
            items: orderItems,
            notes: orderNotes.isEmpty ? nil : orderNotes,
            customerName: customerName.isEmpty ? nil : customerName,
            customerPhone: customerPhone.isEmpty ? nil : customerPhone,
            localId: localId,
            couponCode: discountOrigin == .coupon ? nonEmptyTrimmed(couponCode) : nil)

        offlineManager.queueOrder(create, paymentMethod: paymentMethod.rawValue, cashTendered: cashTendered)

        // Create local ZATCA invoice
        _ = invoiceStore.createInvoice(
            orderLocalId: localId,
            orderNumber: nil,
            sellerNameAr: "AMPOS",
            vatNumber: "300000000000003",
            subtotal: cartSubtotal,
            discountAmount: discountAmount)

        clearCart()
        appState.showSuccess("Order saved offline. Will sync when online.")
        appState.syncManagerSnapshotWithLocalState()
    }

    // MARK: Pay Order
    func payOrder(order: Order, method: PaymentMethod, cashTendered: Double?) async -> Bool {
        isProcessingPayment = true
        // Capture cart values before clearCart() wipes them
        let capturedSubtotal = cartSubtotal
        let capturedDiscount = discountAmount
        do {
            let payment = OrderPayment(
                paymentMethod: method.rawValue,
                paymentReference: nil,
                cashTendered: cashTendered)
            let paid = try await api.payOrder(order.id, payment: payment)
            lastCompletedOrder = paid
            // Create local ZATCA invoice so receipt can include the QR barcode
            let vatNumber = UserDefaults.standard.string(forKey: "vat_number") ?? ""
            let sellerAr = UserDefaults.standard.string(forKey: "seller_name_ar") ?? "AMPOS"
            let localInv = invoiceStore.createInvoice(
                orderLocalId: order.id,
                orderNumber: paid.orderNumber,
                sellerNameAr: sellerAr,
                vatNumber: vatNumber,
                subtotal: capturedSubtotal,
                discountAmount: capturedDiscount
            )
            lastCompletedOrderQR = localInv.qrCodeBase64
            await earnLoyaltyPointsIfNeeded(order: paid, totalAmount: capturedSubtotal - capturedDiscount)
            // The order was already auto-routed to the KDS at creation time
            // (status = "received"). Paid orders no longer appear on the KDS
            // backend filter, so just refresh the local view.
            await dispatchToKitchen(orderId: paid.id)
            clearCart()
            appState.showSuccess("\(l10n.paymentSuccessfulOrder) #\(paid.displayNumber ?? 0) — \(l10n.sentToKitchen)")
            await appState.refreshManagerSnapshot()
            isProcessingPayment = false
            return true
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
            isProcessingPayment = false
            return false
        }
    }

    // MARK: Hold Order
    func holdCurrentOrder() async {
        guard let order = await placeOrder() else { return }
        do {
            let held = try await api.holdOrder(order.id)
            heldOrders.append(held)
            clearCart()
            appState.showSuccess("Order held successfully")
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
        }
    }

    // MARK: Load Held Orders
    func loadHeldOrders() async {
        do {
            heldOrders = try await api.fetchHeldOrders()
        } catch {
            // Silently fail — held orders are supplementary
        }
    }

    // MARK: Load Held Order Into Cart
    func loadHeldOrderIntoCart(_ order: Order) async {
        do {
            if products.isEmpty {
                await loadMenu()
            }
            let detailedOrder = try await api.getOrder(order.id)
            let sourceItems = detailedOrder.items ?? order.items ?? []

            guard !sourceItems.isEmpty else {
                appState.showError(l10n.heldOrderNotRestorable)
                return
            }

            var restoredItems: [CartItem] = []
            var missingItems = 0

            for item in sourceItems {
                let product = products.first { product in
                    if let productId = item.productId, product.id == productId {
                        return true
                    }
                    if let productNameEn = item.productNameEn,
                       !productNameEn.isEmpty,
                       product.nameEn.caseInsensitiveCompare(productNameEn) == .orderedSame {
                        return true
                    }
                    if let productNameAr = item.productNameAr,
                       !productNameAr.isEmpty,
                       product.nameAr == productNameAr {
                        return true
                    }
                    return false
                }

                guard let product else {
                    missingItems += 1
                    continue
                }

                restoredItems.append(
                    CartItem(
                        product: product,
                        quantity: max(item.quantity, 1),
                        notes: item.notes,
                        selectedModifiers: []
                    )
                )
            }

            guard !restoredItems.isEmpty else {
                appState.showError(l10n.heldOrderNotRestorable)
                return
            }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cartItems = restoredItems
                orderType = OrderType(rawValue: detailedOrder.orderType) ?? .dineIn
                selectedTable = tables.first(where: { $0.id == detailedOrder.tableId })
                customerName = detailedOrder.customerName ?? ""
                customerPhone = ""
                orderNotes = detailedOrder.notes ?? ""
                discountAmount = detailedOrder.discountAmount ?? 0
                discountOrigin = discountAmount > 0 ? .manual : .none
                appliedCoupon = nil
                couponCode = ""
                loyaltyCustomer = nil
            }

            _ = try await api.unholdOrder(order.id)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                heldOrders.removeAll { $0.id == order.id }
            }

            appState.selectedTab = .pos
            if missingItems > 0 {
                appState.showError(l10n.heldOrderLoadedPartial)
            } else {
                appState.showSuccess(l10n.heldOrderLoaded)
            }
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
        }
    }

    // MARK: Split Payment
    func splitPayOrder(order: Order, splits: [SplitEntry]) async -> Bool {
        isProcessingPayment = true
        do {
            _ = try await api.splitPayOrder(order.id, splits: splits)
            lastCompletedOrder = order
            await earnLoyaltyPointsIfNeeded(order: order, totalAmount: cartSubtotal - discountAmount)
            clearCart()
            appState.showSuccess("Split payment successful! Order #\(order.displayNumber ?? 0)")
            await appState.refreshManagerSnapshot()
            isProcessingPayment = false
            return true
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
            isProcessingPayment = false
            return false
        }
    }

    // MARK: Download Invoice PDF
    func downloadInvoicePDF(orderId: String) async -> Data? {
        do {
            return try await api.downloadInvoicePDF(orderId)
        } catch {
            self.error = "Failed to download invoice"
            return nil
        }
    }

    // MARK: Barcode Lookup
    func lookupBarcode(_ barcode: String) async {
        do {
            let product = try await api.fetchProductByBarcode(barcode)
            addToCart(product: product)
        } catch {
            self.error = "Product not found for barcode: \(barcode)"
        }
    }

    // MARK: Check if product has modifiers
    func productNeedsModifiers(_ product: Product) -> Bool {
        guard let mods = product.modifiers else { return false }
        return !mods.isEmpty
    }

    private func nonEmptyTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
