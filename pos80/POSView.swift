// POSView.swift — Main cashier screen: product grid + cart
import SwiftUI

private enum DiscountApprovalAction {
    case apply(Double)
    case remove
}

struct POSView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState
    private let l10n = L10n.shared
    @State private var showOrderTypeSheet = false
    @State private var showTablePicker = false
    @State private var showDiscountSheet = false
    @State private var discountInput = ""
    @State private var noteInput = ""
    @State private var showNoteSheet = false
    @State private var showHeldOrders = false
    @State private var showManagerApproval = false
    @State private var pendingDiscountAction: DiscountApprovalAction?
    @Namespace private var animation

    private var showPaymentSheetBinding: Binding<Bool> {
        Binding(get: { vm.showPaymentSheet }, set: { vm.showPaymentSheet = $0 })
    }

    private var showBarcodeScannerBinding: Binding<Bool> {
        Binding(get: { vm.showBarcodeScanner }, set: { vm.showBarcodeScanner = $0 })
    }

    private var showModifierSheetBinding: Binding<Bool> {
        Binding(get: { vm.showModifierSheet }, set: { vm.showModifierSheet = $0 })
    }

    private var searchTextBinding: Binding<String> {
        Binding(get: { vm.searchText }, set: { vm.searchText = $0 })
    }

    private var orderNotesBinding: Binding<String> {
        Binding(get: { vm.orderNotes }, set: { vm.orderNotes = $0 })
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Products
            productPanel
                .frame(maxWidth: .infinity)

            // Right: Cart
            CartView(
                showPayment: { vm.showPaymentSheet = true },
                showOrderType: { showOrderTypeSheet = true },
                showTablePicker: { showTablePicker = true },
                showDiscount: { showDiscountSheet = true },
                showNote: { showNoteSheet = true }
            )
            .environmentObject(vm)
            .frame(width: 360)
            .background(AppTheme.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(AppTheme.border).frame(width: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.bg)
        .sheet(isPresented: showPaymentSheetBinding) {
            PaymentView()
            .environmentObject(vm)
            .environmentObject(appState)
        }
        .sheet(isPresented: $showOrderTypeSheet) { orderTypeSheet }
        .sheet(isPresented: $showTablePicker) { tablePicker }
        .sheet(isPresented: $showDiscountSheet) { discountSheet }
        .sheet(isPresented: $showNoteSheet) { noteSheet }
        .sheet(isPresented: $showHeldOrders) { heldOrdersSheet }
        .sheet(isPresented: $showManagerApproval) {
            if let pendingDiscountAction {
                ManagerApprovalSheet(
                    actionTitle: approvalTitle(for: pendingDiscountAction),
                    message: l10n.managerApprovalRequired
                ) { _ in
                    performDiscountAction(pendingDiscountAction)
                }
            }
        }
        .sheet(isPresented: showBarcodeScannerBinding) {
            BarcodeScannerSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: showModifierSheetBinding) {
            if let product = vm.modifierProduct {
                ModifierSelectionView(product: product) { modifiers in
                    vm.addToCart(product: product, modifiers: modifiers)
                    vm.showModifierSheet = false
                    vm.modifierProduct = nil
                }
            }
        }
        .alert(l10n.error, isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button(l10n.ok, role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
        }
        // iPad Menu Bar commands
        .onReceive(NotificationCenter.default.publisher(for: .amposMenuNewOrder)) { _ in
            vm.clearCart()
            appState.selectedTab = .pos
        }
        .onReceive(NotificationCenter.default.publisher(for: .amposMenuClearCart)) { _ in
            vm.clearCart()
        }
        .onReceive(NotificationCenter.default.publisher(for: .amposMenuPrintReceipt)) { _ in
            guard vm.lastCompletedOrder != nil else { return }
            vm.showPaymentSheet = true
        }
    }

    // MARK: - Product Panel
    private var productPanel: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
            // Category tabs
            categoryTabs
            // Product grid
            if vm.isMenuLoading {
                loadingGrid
            } else if vm.filteredProducts.isEmpty {
                emptyProducts
            } else {
                productsGrid
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Service Desk")
                        .font(AppTheme.title2(28))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(AppTheme.caption(12))
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        Task { await vm.loadHeldOrders() }
                        showHeldOrders = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(vm.heldOrders.isEmpty ? AppTheme.textSecondary : AppTheme.warning)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.card)
                                .cornerRadius(AppTheme.r12)
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                    .strokeBorder(AppTheme.border, lineWidth: 1))
                            if !vm.heldOrders.isEmpty {
                                Text("\(vm.heldOrders.count)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.warning)
                                    .cornerRadius(8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }

                    Button {
                        vm.showBarcodeScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.card)
                            .cornerRadius(AppTheme.r12)
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                .strokeBorder(AppTheme.border, lineWidth: 1))
                    }
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.textMuted)
                        .font(.system(size: 15, weight: .medium))
                    TextField(l10n.searchProducts, text: searchTextBinding)
                        .font(AppTheme.body())
                        .foregroundColor(AppTheme.textPrimary)
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textMuted)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                    .strokeBorder(AppTheme.border, lineWidth: 1))
            }

            HStack(spacing: 8) {
                PillBadge(text: vm.orderType.displayName, color: AppTheme.accent)
                if let table = vm.selectedTable {
                    PillBadge(text: "#\(table.number)", color: AppTheme.info)
                }
                if !vm.heldOrders.isEmpty {
                    PillBadge(text: "\(vm.heldOrders.count) held", color: AppTheme.warning)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [AppTheme.surface, AppTheme.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - Category Tabs
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All tab
                CategoryTab(
                    label: l10n.allCategories,
                    icon: "square.grid.2x2.fill",
                    isSelected: vm.selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        vm.selectedCategory = nil
                    }
                }

                ForEach(vm.categories) { cat in
                    CategoryTab(
                        label: cat.nameAr.isEmpty ? cat.nameEn : cat.nameAr,
                        icon: nil,
                        isSelected: vm.selectedCategory?.id == cat.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.selectedCategory = cat
                        }
                    }
                }
            }
            .padding(8)
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.r16)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(AppTheme.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - Products Grid
    private var productsGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 12)],
                spacing: 12
            ) {
                ForEach(vm.filteredProducts) { product in
                    ProductCard(product: product) {
                        handleProductTap(product)
                    }
                    .compatDraggable(product.id)
                    .contextMenu {
                        Button {
                            handleProductTap(product)
                        } label: {
                            Label("Add to Cart", systemImage: "cart.badge.plus")
                        }
                        Button {
                            UIPasteboard.general.string = product.price.sarFormatted
                        } label: {
                            Label("Copy Price", systemImage: "doc.on.doc")
                        }
                        if !(product.modifiers?.isEmpty ?? true) {
                            Button {
                                vm.modifierProduct = product
                                vm.showModifierSheet = true
                            } label: {
                                Label("Customize", systemImage: "slider.horizontal.3")
                            }
                        }
                        if appState.currentUser?.isManager ?? false {
                            Button {
                                Task { await vm.toggleAvailability(for: product) }
                            } label: {
                                Label(product.isAvailable ?? true ? l10n.markUnavailable : l10n.markAvailable,
                                      systemImage: product.isAvailable ?? true ? "eye.slash.fill" : "eye.fill")
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func handleProductTap(_ product: Product) {
        if product.isAvailable == false {
            appState.showError(l10n.productUnavailable)
            return
        }
        if vm.productNeedsModifiers(product) {
            vm.modifierProduct = product
            vm.showModifierSheet = true
        } else {
            vm.addToCart(product: product)
        }
    }

    // MARK: - Loading grid
    private var loadingGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 12)], spacing: 12) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppTheme.r16)
                        .fill(AppTheme.card)
                        .frame(height: 160)
                        .shimmer()
                }
            }
            .padding(20)
        }
    }

    private var emptyProducts: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: vm.searchText.isEmpty ? "tray.fill" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)
            Text(vm.searchText.isEmpty ? l10n.noProductsAvailable : l10n.noResults(vm.searchText))
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Order Type Sheet
    private var orderTypeSheet: some View {
        SheetContainer(title: l10n.orderType) {
            VStack(spacing: 12) {
                ForEach(OrderType.allCases, id: \.self) { type in
                    Button {
                        vm.orderType = type
                        showOrderTypeSheet = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(vm.orderType == type ? .white : AppTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(vm.orderType == type ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                                .cornerRadius(12)

                            Text(type.displayName)
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textPrimary)

                            Spacer()

                            if vm.orderType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppTheme.success)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(16)
                        .background(vm.orderType == type ? AppTheme.accent.opacity(0.1) : AppTheme.card)
                        .cornerRadius(AppTheme.r12)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                            .strokeBorder(vm.orderType == type ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1))
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Table Picker Sheet
    private var tablePicker: some View {
        SheetContainer(title: l10n.selectTable) {
            if vm.tables.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "table.furniture.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text(l10n.noTablesConfigured)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                    // None option
                    Button {
                        vm.selectedTable = nil
                        showTablePicker = false
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 24))
                                .foregroundColor(vm.selectedTable == nil ? .white : AppTheme.textSecondary)
                            Text(l10n.none)
                                .font(AppTheme.headline(14))
                                .foregroundColor(vm.selectedTable == nil ? .white : AppTheme.textSecondary)
                        }
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .background(vm.selectedTable == nil ? AppTheme.accent : AppTheme.card)
                        .cornerRadius(AppTheme.r12)
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                            .strokeBorder(AppTheme.border, lineWidth: 1))
                    }

                    ForEach(vm.tables) { table in
                        Button {
                            vm.selectedTable = table
                            showTablePicker = false
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(table.isOccupied ? AppTheme.danger.opacity(0.15) :
                                              vm.selectedTable?.id == table.id ? AppTheme.accent : AppTheme.card)
                                        .frame(width: 40, height: 40)
                                    Text(table.number)
                                        .font(AppTheme.headline())
                                        .foregroundColor(table.isOccupied ? AppTheme.danger :
                                                         vm.selectedTable?.id == table.id ? .white : AppTheme.textPrimary)
                                }
                                if let section = table.section {
                                    Text(section)
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .frame(height: 80)
                            .frame(maxWidth: .infinity)
                            .background(vm.selectedTable?.id == table.id ? AppTheme.accent.opacity(0.1) : AppTheme.card)
                            .cornerRadius(AppTheme.r12)
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                .strokeBorder(vm.selectedTable?.id == table.id ? AppTheme.accent.opacity(0.5) : AppTheme.border, lineWidth: 1))
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Discount Sheet
    private var discountSheet: some View {
        SheetContainer(title: l10n.applyDiscount) {
            VStack(spacing: 20) {
                Text("\(l10n.cartSubtotalPrefix) \(vm.cartSubtotal.sarFormatted)")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(icon: "tag.fill", placeholder: l10n.discountAmountSAR, text: $discountInput, keyboardType: .decimalPad)

                Button {
                    guard let amount = Double(discountInput) else { return }
                    requestDiscountApproval(.apply(amount))
                } label: {
                    Text(l10n.applyDiscount)
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                .disabled(discountInput.isEmpty)

                if vm.discountAmount > 0 {
                    Button {
                        requestDiscountApproval(.remove)
                    } label: {
                        Text(l10n.removeDiscount)
                    }
                    .buttonStyle(DangerButtonStyle())
                }
            }
            .padding(24)
        }
    }

    private func requestDiscountApproval(_ action: DiscountApprovalAction) {
        if appState.currentUser?.isManager ?? false {
            performDiscountAction(action)
            return
        }
        pendingDiscountAction = action
        showManagerApproval = true
    }

    private func performDiscountAction(_ action: DiscountApprovalAction) {
        switch action {
        case .apply(let amount):
            vm.applyDiscount(amount)
            discountInput = ""
        case .remove:
            vm.discountAmount = 0
        }
        pendingDiscountAction = nil
        showDiscountSheet = false
    }

    private func approvalTitle(for action: DiscountApprovalAction) -> String {
        switch action {
        case .apply:
            return l10n.applyDiscountApproval
        case .remove:
            return l10n.removeDiscountApproval
        }
    }

    // MARK: - Note Sheet
    private var noteSheet: some View {
        return SheetContainer(title: l10n.orderNotes) {
            VStack(spacing: 16) {
                TextEditor(text: orderNotesBinding)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .compatHiddenScrollContentBackground()
                    .background(AppTheme.card)
                    .frame(height: 120)
                    .cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                        .strokeBorder(AppTheme.border, lineWidth: 1))

                Button {
                    showNoteSheet = false
                } label: {
                    Text(l10n.saveNotes)
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            }
            .padding(24)
        }
    }

    // MARK: - Held Orders Sheet
    private var heldOrdersSheet: some View {
        SheetContainer(title: l10n.heldOrders) {
            if vm.heldOrders.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.textMuted)
                    Text(l10n.noHeldOrders)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                    Text(l10n.holdSubtitle)
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.heldOrders) { order in
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.warning)
                                        Text("Order #\(order.displayNumber ?? 0)")
                                            .font(AppTheme.headline(14))
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    if let name = order.customerName {
                                        Text(name)
                                            .font(AppTheme.caption(12))
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                    Text(l10n.itemsCount(order.items?.count ?? 0))
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(AppTheme.textMuted)
                                }

                                Spacer()

                                Text(order.totalSafe.sarFormatted)
                                    .font(AppTheme.mono(14))
                                    .foregroundColor(AppTheme.textPrimary)

                                Button {
                                    Task {
                                        await vm.loadHeldOrderIntoCart(order)
                                        showHeldOrders = false
                                    }
                                } label: {
                                    Text(l10n.loadToCart)
                                        .font(AppTheme.caption(12))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.accent)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(14)
                            .background(AppTheme.card)
                            .cornerRadius(AppTheme.r12)
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                .strokeBorder(AppTheme.border, lineWidth: 1))
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let onTap: () -> Void
    @State private var isPressed = false

    private var isAvailable: Bool { product.isAvailable ?? true }

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPressed = false }
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image / Color block
                ZStack(alignment: .topTrailing) {
                    if let url = product.resolvedImageURL {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            productPlaceholder
                        }
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(AppTheme.r12)
                    } else {
                        productPlaceholder
                            .frame(height: 100)
                            .cornerRadius(AppTheme.r12)
                    }

                    // Tax badge
                    if product.isTaxable {
                        Text("VAT")
                            .font(AppTheme.caption(9))
                            .foregroundColor(AppTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.warning.opacity(0.15))
                            .cornerRadius(6)
                            .padding(6)
                    }

                    if !isAvailable {
                        Text("86")
                            .font(AppTheme.caption(10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.danger)
                            .cornerRadius(6)
                            .padding(.top, 34)
                            .padding(.trailing, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.nameAr)
                        .font(AppTheme.headline(14))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(product.nameEn)
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    HStack {
                        Text(product.price.sarFormatted)
                            .font(AppTheme.mono(14))
                            .foregroundColor(isAvailable ? AppTheme.accent : AppTheme.textMuted)
                        Spacer()
                        if !(product.modifiers?.isEmpty ?? true) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
            }
            .background(AppTheme.card)
            .opacity(isAvailable ? 1 : 0.65)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var productPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.accent.opacity(0.2), AppTheme.card],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "photo.fill")
                .font(.system(size: 24))
                .foregroundColor(AppTheme.textMuted.opacity(0.5))
        }
    }
}

// MARK: - Category Tab
struct CategoryTab: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(label).font(AppTheme.headline(13))
            }
            .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.accent : AppTheme.card)
            .cornerRadius(AppTheme.r8)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r8)
                .strokeBorder(isSelected ? .clear : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet Container
struct SheetContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) var dismiss

    var body: some View {
        CompatNavigationContainer {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                ScrollView { content() }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .compatSheetNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(AppTheme.headline())
                }
            }
        }
    }
}

// MARK: - Modifier Selection View
struct ModifierSelectionView: View {
    let product: Product
    var initialModifiers: [SelectedModifier] = []
    let onConfirm: ([SelectedModifier]) -> Void
    @State private var selections: [String: Set<String>] = [:]
    @Environment(\.dismiss) var dismiss

    private var selectedModifiers: [SelectedModifier] {
        guard let mods = product.modifiers else { return [] }
        return mods.flatMap { group in
            group.options.filter { opt in
                selections[group.id]?.contains(opt.id) ?? false
            }.map { opt in
                SelectedModifier(id: opt.id, nameAr: opt.nameAr, nameEn: opt.nameEn, priceDelta: opt.priceDelta)
            }
        }
    }

    var body: some View {
        SheetContainer(title: product.nameAr.isEmpty ? product.nameEn : product.nameAr) {
            VStack(alignment: .leading, spacing: 20) {
                // Price header
                HStack {
                    Spacer()
                    Text("Base: \(product.price.sarFormatted)")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }

                // Modifier groups
                ForEach(product.modifiers ?? []) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(group.nameAr.isEmpty ? group.nameEn : group.nameAr)
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            if group.isRequired {
                                PillBadge(text: "Required", color: AppTheme.danger)
                            }
                        }

                        ForEach(group.options) { option in
                            let isSelected = selections[group.id]?.contains(option.id) ?? false
                            Button {
                                toggleOption(groupId: group.id, optionId: option.id,
                                             max: group.maxSelections)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: group.maxSelections > 1 ? 6 : 100)
                                            .strokeBorder(isSelected ? AppTheme.accent : AppTheme.border, lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: group.maxSelections > 1 ? 4 : 100)
                                                .fill(AppTheme.accent)
                                                .frame(width: 14, height: 14)
                                        }
                                    }
                                    Text(option.nameAr.isEmpty ? option.nameEn : option.nameAr)
                                        .font(AppTheme.body())
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    if option.priceDelta != 0 {
                                        Text("+\(option.priceDelta.sarFormatted)")
                                            .font(AppTheme.mono(13))
                                            .foregroundColor(AppTheme.textSecondary)
                                    }
                                }
                                .padding(14)
                                .background(isSelected ? AppTheme.accent.opacity(0.1) : AppTheme.card)
                                .cornerRadius(AppTheme.r12)
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                    .strokeBorder(isSelected ? AppTheme.accent.opacity(0.4) : AppTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Total extra
                let extra = selectedModifiers.reduce(0) { $0 + $1.priceDelta }
                HStack {
                    Text("Total")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Text((product.price + extra).sarFormatted)
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.accent)
                }
                .padding(16)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)

                Button {
                    onConfirm(selectedModifiers)
                } label: {
                    Text(initialModifiers.isEmpty ? "Add to Cart" : "Save Changes")
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            }
            .padding(20)
        }
        .onAppear {
            // Pre-populate from initial modifiers (editing existing cart item)
            if !initialModifiers.isEmpty {
                guard let mods = product.modifiers else { return }
                for group in mods {
                    let preSelected = group.options
                        .filter { opt in initialModifiers.contains(where: { $0.id == opt.id }) }
                        .map { $0.id }
                    if !preSelected.isEmpty { selections[group.id] = Set(preSelected) }
                }
            } else {
                // Pre-select defaults for new item
                for group in product.modifiers ?? [] {
                    let defaults = group.options.filter { $0.isDefault }.map { $0.id }
                    if !defaults.isEmpty { selections[group.id] = Set(defaults) }
                }
            }
        }
    }

    private func toggleOption(groupId: String, optionId: String, max: Int) {
        var current = selections[groupId] ?? []
        if current.contains(optionId) {
            current.remove(optionId)
        } else {
            if max == 1 { current = [optionId] }
            else if current.count < max { current.insert(optionId) }
        }
        selections[groupId] = current
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
