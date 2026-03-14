// POSView.swift — Main cashier screen: product grid + cart
import SwiftUI

struct POSView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState
    @State private var showOrderTypeSheet = false
    @State private var showTablePicker = false
    @State private var showDiscountSheet = false
    @State private var discountInput = ""
    @State private var noteInput = ""
    @State private var showNoteSheet = false
    @Namespace private var animation

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
        .background(AppTheme.bg)
        .sheet(isPresented: $vm.showPaymentSheet) {
            PaymentView()
                .environmentObject(vm)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showOrderTypeSheet) { orderTypeSheet }
        .sheet(isPresented: $showTablePicker) { tablePicker }
        .sheet(isPresented: $showDiscountSheet) { discountSheet }
        .sheet(isPresented: $showNoteSheet) { noteSheet }
        .sheet(isPresented: $vm.showModifierSheet) {
            if let product = vm.modifierProduct {
                ModifierSelectionView(product: product) { modifiers in
                    vm.addToCart(product: product, modifiers: modifiers)
                    vm.showModifierSheet = false
                    vm.modifierProduct = nil
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.error != nil },
            set: { if !$0 { vm.error = nil } }
        )) {
            Button("OK", role: .cancel) { vm.error = nil }
        } message: {
            Text(vm.error ?? "")
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
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.textMuted)
                    .font(.system(size: 15, weight: .medium))
                TextField("Search products or scan barcode...", text: $vm.searchText)
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

            // Quick actions
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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppTheme.bg)
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
                    label: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: vm.selectedCategory == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        vm.selectedCategory = nil
                    }
                }

                ForEach(vm.categories) { cat in
                    CategoryTab(
                        label: cat.nameEn,
                        icon: nil,
                        isSelected: vm.selectedCategory?.id == cat.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.selectedCategory = cat
                        }
                    }
                }
            }
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
                }
            }
            .padding(20)
        }
    }

    private func handleProductTap(_ product: Product) {
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
            Text(vm.searchText.isEmpty ? "No products available" : "No results for \"\(vm.searchText)\"")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - Order Type Sheet
    private var orderTypeSheet: some View {
        SheetContainer(title: "Order Type") {
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
        SheetContainer(title: "Select Table") {
            if vm.tables.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "table.furniture.fill")
                        .font(.system(size: 40))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No tables configured")
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
                            Text("None")
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
        SheetContainer(title: "Apply Discount") {
            VStack(spacing: 20) {
                Text("Cart Subtotal: \(vm.cartSubtotal.sarFormatted)")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                ThemeTextField(icon: "tag.fill", placeholder: "Discount amount (SAR)", text: $discountInput, keyboardType: .decimalPad)

                Button {
                    if let amount = Double(discountInput) {
                        vm.applyDiscount(amount)
                        showDiscountSheet = false
                        discountInput = ""
                    }
                } label: {
                    Text("Apply Discount")
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                .disabled(discountInput.isEmpty)

                if vm.discountAmount > 0 {
                    Button {
                        vm.discountAmount = 0
                        showDiscountSheet = false
                    } label: {
                        Text("Remove Discount")
                    }
                    .buttonStyle(DangerButtonStyle())
                }
            }
            .padding(24)
        }
    }

    // MARK: - Note Sheet
    private var noteSheet: some View {
        SheetContainer(title: "Order Notes") {
            VStack(spacing: 16) {
                TextEditor(text: $vm.orderNotes)
                    .font(AppTheme.body())
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.card)
                    .frame(height: 120)
                    .cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                        .strokeBorder(AppTheme.border, lineWidth: 1))

                Button {
                    showNoteSheet = false
                } label: {
                    Text("Save Notes")
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            }
            .padding(24)
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPressed = false }
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Image / Color block
                ZStack(alignment: .topTrailing) {
                    if let imgUrl = product.imageUrl, let url = URL(string: imgUrl) {
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
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.nameEn)
                        .font(AppTheme.headline(14))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)

                    HStack {
                        Text(product.price.sarFormatted)
                            .font(AppTheme.mono(14))
                            .foregroundColor(AppTheme.accent)
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
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                ScrollView { content() }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.accent)
                        .font(AppTheme.headline())
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Modifier Selection View
struct ModifierSelectionView: View {
    let product: Product
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
        SheetContainer(title: product.nameEn) {
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
                            Text(group.nameEn)
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
                                    Text(option.nameEn)
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
                    Text("Add to Cart")
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
            }
            .padding(20)
        }
        .onAppear {
            // Pre-select defaults
            for group in product.modifiers ?? [] {
                let defaults = group.options.filter { $0.isDefault }.map { $0.id }
                if !defaults.isEmpty { selections[group.id] = Set(defaults) }
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
