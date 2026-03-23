// POSViewModel.swift — Business logic for the main POS screen
import SwiftUI

@Observable
@MainActor
final class POSViewModel {

    private let api = APIService.shared
    private let appState = AppState.shared
    private let l10n = L10n.shared
    var offlineManager: OfflineManager { OfflineManager.shared }
    private var invoiceStore: LocalInvoiceStore { LocalInvoiceStore.shared }

    // MARK: Menu Data
    var categories: [ProductCategory] = []
    var products: [Product] = []
    var selectedCategory: ProductCategory?
    var isMenuLoading = false

    // MARK: Cart
    var cartItems: [CartItem] = []
    var orderType: OrderType = .dineIn
    var selectedTable: RestaurantTable?
    var customerName: String = ""
    var customerPhone: String = ""
    var orderNotes: String = ""
    var discountAmount: Double = 0

    // MARK: Payment
    var showPaymentSheet = false
    var isProcessingPayment = false
    var lastCompletedOrder: Order?
    var lastCompletedOrderQR: String?

    // MARK: Search & Barcode
    var searchText = ""
    var showBarcodeScanner = false

    // MARK: Modifier selection
    var showModifierSheet = false
    var modifierProduct: Product?

    // MARK: Completed Orders (held)
    var heldOrders: [Order] = []

    // MARK: Tables
    var tables: [RestaurantTable] = []

    // MARK: Errors
    var error: String?

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
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    func incrementItem(_ item: CartItem) {
        guard let idx = cartItems.firstIndex(where: { $0.id == item.id }) else { return }
        cartItems[idx].quantity += 1
    }

    func decrementItem(_ item: CartItem) {
        guard let idx = cartItems.firstIndex(where: { $0.id == item.id }) else { return }
        if cartItems[idx].quantity > 1 { cartItems[idx].quantity -= 1 }
        else { cartItems.remove(at: idx) }
    }

    func removeItem(_ item: CartItem) {
        cartItems.removeAll { $0.id == item.id }
    }

    func clearCart() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            cartItems.removeAll()
            orderType = .dineIn
            discountAmount = 0
            customerName = ""
            customerPhone = ""
            orderNotes = ""
            selectedTable = nil
        }
    }

    func applyDiscount(_ amount: Double) {
        discountAmount = min(amount, cartSubtotal)
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
            localId: localId)

        do {
            let order = try await api.createOrder(create)
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
            localId: localId)

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
            clearCart()
            appState.showSuccess("Payment successful! Order #\(paid.displayNumber ?? 0)")
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
            let detailedOrder = try await api.getOrder(order.id)
            let sourceItems = detailedOrder.items ?? order.items ?? []

            guard !sourceItems.isEmpty else {
                appState.showError(l10n.heldOrderNotRestorable)
                return
            }

            var restoredItems: [CartItem] = []
            var missingItems = 0

            for item in sourceItems {
                guard let productId = item.productId,
                      let product = products.first(where: { $0.id == productId }) else {
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
}
