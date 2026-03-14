// POSViewModel.swift — Business logic for the main POS screen
import SwiftUI
import Combine

@MainActor
final class POSViewModel: ObservableObject {

    private let api = APIService.shared
    private let appState = AppState.shared

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

    // MARK: Payment
    @Published var showPaymentSheet = false
    @Published var isProcessingPayment = false
    @Published var lastCompletedOrder: Order?

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

    // MARK: Load Menu
    func loadMenu() async {
        isMenuLoading = true
        async let cats = api.fetchCategories()
        async let prods = api.fetchProducts(availableOnly: false)
        do {
            let (c, p) = try await (cats, prods)
            categories = c.sorted { $0.sortOrder < $1.sortOrder }
            products = p
            if selectedCategory == nil, let first = categories.first {
                selectedCategory = first
            }
        } catch {
            self.error = error.localizedDescription
        }
        isMenuLoading = false
    }

    func loadTables() async {
        do { tables = try await api.fetchTables() }
        catch { self.error = error.localizedDescription }
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

        let create = OrderCreate(
            orderType: orderType.rawValue,
            tableId: selectedTable?.id,
            items: orderItems,
            notes: orderNotes.isEmpty ? nil : orderNotes,
            customerName: customerName.isEmpty ? nil : customerName,
            customerPhone: customerPhone.isEmpty ? nil : customerPhone,
            localId: UUID().uuidString)

        do {
            let order = try await api.createOrder(create)
            return order
        } catch {
            self.error = error.localizedDescription
            appState.showError(error.localizedDescription)
            return nil
        }
    }

    // MARK: Pay Order
    func payOrder(order: Order, method: PaymentMethod, cashTendered: Double?) async -> Bool {
        isProcessingPayment = true
        do {
            let payment = OrderPayment(
                paymentMethod: method.rawValue,
                paymentReference: nil,
                cashTendered: cashTendered)
            let paid = try await api.payOrder(order.id, payment: payment)
            lastCompletedOrder = paid
            clearCart()
            appState.showSuccess("Payment successful! Order #\(paid.displayNumber ?? 0)")
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
