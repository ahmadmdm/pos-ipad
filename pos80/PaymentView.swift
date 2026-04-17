// PaymentView.swift — Payment processing sheet
import SwiftUI
import AVFoundation

struct PaymentView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    private let offlineManager = OfflineManager.shared
    private let l10n = L10n.shared

    @State private var selectedMethod: PaymentMethod = .cash
    @State private var cashInput = ""
    @State private var orderPlaced = false
    @State private var placedOrder: Order?
    @State private var isPlacing = false
    @State private var successScale: CGFloat = 0.5
    @State private var successOpacity: Double = 0

    // Split payment state
    @State private var isSplitMode = false
    @State private var splitEntries: [SplitEntryUI] = []
    @State private var splitMethodSelection: PaymentMethod = .cash
    @State private var splitAmountInput = ""
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private var cashChange: Double {
        guard selectedMethod == .cash, let tendered = Double(cashInput) else { return 0 }
        return max(0, tendered - vm.cartTotal)
    }

    private var cashIsValid: Bool {
        if isSplitMode { return splitIsValid }
        guard selectedMethod == .cash else { return true }
        guard let tendered = Double(cashInput) else { return false }
        return tendered >= vm.cartTotal
    }

    private var splitTotal: Double {
        splitEntries.reduce(0) { $0 + $1.amount }
    }

    private var splitRemaining: Double {
        max(0, vm.cartTotal - splitTotal)
    }

    private var splitIsValid: Bool {
        !splitEntries.isEmpty && abs(splitTotal - vm.cartTotal) < 0.02
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                if orderPlaced {
                    successScreen
                } else {
                    paymentScreen(geo: geo)
                }
            }
        }
        .task {
            if vm.customerInsights.isEmpty {
                await vm.loadCustomerInsights()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Payment Screen
    private func paymentScreen(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.card)
                        .cornerRadius(10)
                }
                Spacer()
                Text(l10n.payment)
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Total card
                    totalDisplay

                    // Order Summary (mini)
                    orderSummaryMini

                    // Payment methods
                    paymentMethods

                    // Cash input
                    if selectedMethod == .cash {
                        cashInputSection
                    }

                    // Customer name
                    customerSection

                    // Action button
                    actionButton
                }
                .padding(24)
            }
        }
    }

    // MARK: - Total Display
    private var totalDisplay: some View {
        VStack(spacing: 4) {
            Text(l10n.totalAmount)
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textSecondary)
            Text(vm.cartTotal.sarFormatted)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(AppTheme.accentGrad)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r20)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r20)
            .strokeBorder(AppTheme.border, lineWidth: 1))
    }

    // MARK: - Order Summary mini
    private var orderSummaryMini: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l10n.orderSummary)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(l10n.itemsCount(vm.cartCount))
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ForEach(vm.cartItems) { item in
                HStack {
                    Text("×\(item.quantity)")
                        .font(AppTheme.mono(13))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 28)
                    Text(item.product.nameEn)
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(item.lineTotal.sarFormatted)
                        .font(AppTheme.mono(13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            Divider().background(AppTheme.border).padding(.horizontal, 16).padding(.top, 8)

            VStack(spacing: 6) {
                SummaryRow(label: l10n.subtotal, value: vm.cartSubtotal.sarFormatted)
                if vm.discountAmount > 0 {
                    SummaryRow(label: vm.discountSummaryLabel, value: "-\(vm.discountAmount.sarFormatted)", valueColor: AppTheme.success)
                }
                SummaryRow(label: l10n.vat15, value: vm.cartVAT.sarFormatted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
    }

    // MARK: - Payment Methods
    private var paymentMethods: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.paymentMethod)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSplitMode.toggle()
                        if isSplitMode {
                            splitEntries = []
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.branch")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSplitMode ? l10n.single : l10n.split)
                            .font(AppTheme.caption(12))
                    }
                    .foregroundColor(isSplitMode ? .white : AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isSplitMode ? AppTheme.accent : AppTheme.accent.opacity(0.12))
                    .cornerRadius(8)
                }
            }

            if isSplitMode {
                splitPaymentSection
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach([PaymentMethod.cash, .card, .apple_pay, .mada], id: \.self) { method in
                        PaymentMethodButton(
                            method: method,
                            isSelected: selectedMethod == method
                        ) { selectedMethod = method }
                    }
                }
            }
        }
    }

    // MARK: - Split Payment Section
    private var splitPaymentSection: some View {
        VStack(spacing: 12) {
            // Existing splits
            ForEach(Array(splitEntries.enumerated()), id: \.element.id) { idx, entry in
                HStack {
                    Image(systemName: entry.method.icon)
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 24)
                    Text(entry.method.displayName)
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text(entry.amount.sarFormatted)
                        .font(AppTheme.mono(13))
                        .foregroundColor(AppTheme.textPrimary)
                    Button {
                        splitEntries.remove(at: idx)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.danger.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r8)
            }

            // Add new split
            if splitRemaining > 0.01 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach([PaymentMethod.cash, .card, .apple_pay, .mada], id: \.self) { method in
                            Button {
                                splitMethodSelection = method
                            } label: {
                                Image(systemName: method.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(splitMethodSelection == method ? .white : AppTheme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(splitMethodSelection == method ? AppTheme.accent : AppTheme.card)
                                    .cornerRadius(8)
                            }
                        }
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        TextField(l10n.amount, text: $splitAmountInput)
                            .font(AppTheme.body(14))
                            .foregroundColor(AppTheme.textPrimary)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.card)
                            .cornerRadius(AppTheme.r8)
                        Button {
                            splitAmountInput = String(format: "%.2f", splitRemaining)
                        } label: {
                            Text(l10n.rest)
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .background(AppTheme.accent.opacity(0.12))
                                .cornerRadius(AppTheme.r8)
                        }
                        Button {
                            guard let amount = Double(splitAmountInput), amount > 0 else { return }
                            splitEntries.append(SplitEntryUI(method: splitMethodSelection, amount: min(amount, splitRemaining)))
                            splitAmountInput = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }

            // Remaining label
            HStack {
                Text(l10n.remaining)
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textMuted)
                Spacer()
                Text(splitRemaining.sarFormatted)
                    .font(AppTheme.headline(14))
                    .foregroundColor(splitRemaining > 0.01 ? AppTheme.warning : AppTheme.success)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Cash Input
    private var cashInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.cashTendered)
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)

            // Quick amounts
            let quickAmounts = quickCashAmounts(for: vm.cartTotal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.self) { amount in
                        Button {
                            cashInput = String(format: "%.0f", amount)
                        } label: {
                            Text(amount == 0 ? l10n.exact : "\(Int(amount))")
                                .font(AppTheme.headline(14))
                                .foregroundColor(cashInput == String(format: "%.0f", amount) || (amount == 0 && cashInput == String(format: "%.2f", vm.cartTotal)) ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.card)
                                .cornerRadius(AppTheme.r8)
                                .overlay(RoundedRectangle(cornerRadius: AppTheme.r8)
                                    .strokeBorder(AppTheme.border, lineWidth: 1))
                        }
                    }
                }
            }

            ThemeTextField(
                icon: "banknote.fill",
                placeholder: l10n.amountReceived,
                text: $cashInput,
                keyboardType: .decimalPad)

            // Change calculation
            if let tendered = Double(cashInput), tendered > 0 {
                HStack {
                    VStack(alignment: .leading) {
                        Text(l10n.change)
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text(cashChange.sarFormatted)
                            .font(AppTheme.title2())
                            .foregroundColor(cashChange >= 0 ? AppTheme.success : AppTheme.danger)
                    }
                    Spacer()
                    if cashChange < 0 {
                        Text(l10n.insufficientAmount)
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.danger)
                    }
                }
                .padding(16)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)
            }
        }
    }

    // MARK: - Customer Section
    private var customerSection: some View {
        return VStack(alignment: .leading, spacing: 10) {
            Text(l10n.customerOptional)
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)

            ThemeTextField(
                icon: "person.fill",
                placeholder: l10n.customerName,
                text: Binding(
                    get: { vm.customerName },
                    set: { vm.customerName = $0 }
                )
            )

            HStack(spacing: 10) {
                ThemeTextField(
                    icon: "phone.fill",
                    placeholder: l10n.customerPhone,
                    text: Binding(
                        get: { vm.customerPhone },
                        set: { vm.customerPhone = $0 }
                    ),
                    keyboardType: .phonePad,
                    autocapitalization: .never)

                Button {
                    Task { await vm.lookupLoyaltyCustomer() }
                } label: {
                    HStack(spacing: 6) {
                        if vm.isLookingUpLoyaltyCustomer {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "person.text.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(l10n.lookupLoyalty)
                            .font(AppTheme.caption(12))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(AppTheme.info)
                    .cornerRadius(AppTheme.r12)
                }
                .buttonStyle(.plain)
                .disabled(vm.customerPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLookingUpLoyaltyCustomer)
            }

            if let customer = vm.loyaltyCustomer {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(customer.name)
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\(customer.pointsBalance) \(l10n.points)")
                            .font(AppTheme.caption(12))
                            .foregroundColor(AppTheme.success)
                    }

                    HStack(spacing: 12) {
                        if let totalOrders = customer.totalOrders {
                            Label("\(totalOrders)", systemImage: "cart")
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        if let totalSpent = customer.totalSpent {
                            Label(totalSpent.sarFormatted, systemImage: "banknote")
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(AppTheme.success.opacity(0.08))
                .cornerRadius(AppTheme.r12)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                    .strokeBorder(AppTheme.success.opacity(0.2), lineWidth: 1))
            }

            if !vm.customerInsights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.recentCustomers)
                        .font(AppTheme.caption(12))
                        .foregroundColor(AppTheme.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(vm.customerInsights.prefix(8))) { insight in
                                Button {
                                    vm.selectCustomerInsight(insight)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(insight.name)
                                            .font(AppTheme.caption(12))
                                            .foregroundColor(AppTheme.textPrimary)
                                            .lineLimit(1)
                                        if let phone = insight.phone, !phone.isEmpty {
                                            Text(phone)
                                                .font(AppTheme.caption(10))
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        Text("\(insight.pointsBalance) \(l10n.points)")
                                            .font(AppTheme.caption(10))
                                            .foregroundColor(AppTheme.accent)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.card)
                                    .cornerRadius(AppTheme.r12)
                                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                                        .strokeBorder(AppTheme.border, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(l10n.couponCode)
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 10) {
                    ThemeTextField(
                        icon: "ticket.fill",
                        placeholder: l10n.enterCouponCode,
                        text: Binding(
                            get: { vm.couponCode },
                            set: { vm.couponCode = $0 }
                        ),
                        autocapitalization: .never)

                    Button {
                        if vm.discountOrigin == .coupon {
                            vm.removeCoupon()
                        } else {
                            Task { await vm.applyCoupon() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isApplyingCoupon {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: vm.discountOrigin == .coupon ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text(vm.discountOrigin == .coupon ? l10n.removeCoupon : l10n.applyCoupon)
                                .font(AppTheme.caption(12))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(vm.discountOrigin == .coupon ? AppTheme.danger : AppTheme.accent)
                        .cornerRadius(AppTheme.r12)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isApplyingCoupon || (vm.discountOrigin != .coupon && vm.couponCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }

                if let coupon = vm.appliedCoupon, vm.discountOrigin == .coupon {
                    Text(coupon.message.isEmpty ? l10n.couponApplied(coupon.code ?? vm.couponCode) : coupon.message)
                        .font(AppTheme.caption(12))
                        .foregroundColor(AppTheme.success)
                }
            }
        }
    }

    // MARK: - Action Button
    private var actionButton: some View {
        VStack(spacing: 8) {
            // Offline indicator
            if !offlineManager.isOnline {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                    Text(l10n.offlineMode)
                        .font(AppTheme.caption(11))
                }
                .foregroundColor(AppTheme.warning)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(AppTheme.warning.opacity(0.1))
                .cornerRadius(AppTheme.r8)
            }

            Button {
                Task { await processPayment() }
            } label: {
                HStack(spacing: 12) {
                    if isPlacing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: isSplitMode ? "arrow.branch" : selectedMethod.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(isSplitMode ? l10n.confirmSplitPayment : l10n.confirmPayment(selectedMethod.displayName))
                            .font(AppTheme.headline(16))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(isPlacing ? AnyShapeStyle(AppTheme.accent.opacity(0.5)) : AnyShapeStyle(AppTheme.accentGradH))
                .cornerRadius(AppTheme.r16)
                .shadow(color: AppTheme.accent.opacity(0.4), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPlacing || !cashIsValid)
            .opacity(!cashIsValid ? 0.5 : 1)
        }
    }

    // MARK: - Success Screen

    private var successScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Check mark animation
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.15))
                    .frame(width: 140, height: 140)
                Circle()
                    .strokeBorder(AppTheme.success.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(AppTheme.success)
            }
            .scaleEffect(successScale)
            .opacity(successOpacity)

            VStack(spacing: 8) {
                Text(l10n.paymentSuccessful)
                    .font(AppTheme.title1())
                    .foregroundColor(AppTheme.textPrimary)
                if let order = placedOrder {
                    Text("Order #\(order.displayNumber ?? 0)")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                }
                if cashChange > 0 && !isSplitMode {
                    HStack(spacing: 8) {
                        Image(systemName: "banknote.fill")
                            .foregroundColor(AppTheme.success)
                        Text("Change: \(cashChange.sarFormatted)")
                            .font(AppTheme.title2())
                            .foregroundColor(AppTheme.success)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppTheme.success.opacity(0.1))
                    .cornerRadius(AppTheme.r12)
                }
            }
            .opacity(successOpacity)

            Spacer()

            VStack(spacing: 12) {
                // Print Receipt button
                if let order = placedOrder {
                    Button {
                        shareReceipt(for: order)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                            Text(l10n.downloadInvoice)
                                .font(AppTheme.headline(14))
                        }
                        .foregroundColor(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.accent.opacity(0.12))
                        .cornerRadius(AppTheme.r12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await autoPrintReceipt(order: order) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(l10n.printReceipt)
                                .font(AppTheme.headline(14))
                        }
                        .foregroundColor(AppTheme.success)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.success.opacity(0.12))
                        .cornerRadius(AppTheme.r12)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dismiss()
                } label: {
                    Text(l10n.newOrder)
                        .font(AppTheme.headline())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppTheme.accentGradH)
                        .cornerRadius(AppTheme.r16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .opacity(successOpacity)
        }
    }

    // MARK: - Process Payment
    private func processPayment() async {
        isPlacing = true
        let cashTendered = selectedMethod == .cash ? Double(cashInput) : nil

        // Offline mode: queue order locally
        if !offlineManager.isOnline {
            vm.placeOrderOffline(paymentMethod: isSplitMode ? .split : selectedMethod, cashTendered: cashTendered)
            isPlacing = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                orderPlaced = true
                successScale = 1
                successOpacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            announceSaleCompletion(orderLabel: nil, isOfflineQueued: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { dismiss() }
            return
        }

        // Online mode
        guard let order = await vm.placeOrder() else {
            isPlacing = false
            return
        }

        var success = false
        if isSplitMode {
            let splits = splitEntries.map { SplitEntry(method: $0.method.rawValue, amount: $0.amount) }
            success = await vm.splitPayOrder(order: order, splits: splits)
        } else {
            success = await vm.payOrder(order: order, method: selectedMethod, cashTendered: cashTendered)
        }
        isPlacing = false

        if success {
            placedOrder = vm.lastCompletedOrder ?? order
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                orderPlaced = true
                successScale = 1
                successOpacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            let orderLabel = placedOrder.flatMap { $0.orderNumber } ?? ""
            let cashChange = (Double(cashInput) ?? 0) - vm.cartTotal
            announceSaleCompletion(orderLabel: orderLabel, cashChange: cashChange)

            // Auto-print receipt
            Task { await autoPrintReceipt(order: placedOrder!) }

            // Auto-open cash drawer for cash payments
            if selectedMethod == .cash || (isSplitMode && splitEntries.contains(where: { $0.method == .cash })) {
                Task { await autoOpenCashDrawer() }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { dismiss() }
        }
    }

    private func announceSaleCompletion(orderLabel: String?, cashChange: Double = 0, isOfflineQueued: Bool = false) {
        guard appState.isSaleCompletionSoundEnabled else { return }

        var speech = "Payment successful"
        if isOfflineQueued {
            speech += ". Order queued offline"
        }
        if let orderLabel, !orderLabel.isEmpty {
            speech += ". Order \(orderLabel)"
        }
        if selectedMethod == .cash && cashChange > 0.01 {
            speech += ". Change \(String(format: "%.2f", cashChange)) riyals"
        }

        let utterance = AVSpeechUtterance(string: speech)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    private func quickCashAmounts(for total: Double) -> [Double] {
        let next5 = ceil(total / 5) * 5
        let next10 = ceil(total / 10) * 10
        let next50 = ceil(total / 50) * 50
        let next100 = ceil(total / 100) * 100
        var amounts: [Double] = [0] // 0 = exact
        for a in [next5, next10, next50, next100] {
            if a > total && !amounts.contains(a) { amounts.append(a) }
        }
        return amounts
    }

    private func autoPrintReceipt(order: Order) async {
        let receipt = buildReceiptData(order: order)
        // Check if ESC/POS printer is configured
        if let ip = UserDefaults.standard.string(forKey: "receipt_printer_ip"),
           !ip.isEmpty,
           let portStr = UserDefaults.standard.string(forKey: "receipt_printer_port"),
           let port = UInt16(portStr) {
            let paperSize = UserDefaults.standard.string(forKey: "paper_size") ?? "80mm"
            _ = await ReceiptPrinter.shared.printReceipt(receipt: receipt, ip: ip, port: port, paperSize: paperSize)
            return
        }
        // Try from API settings
        if let settings = try? await APIService.shared.fetchSettings(),
           let ip = settings.receiptPrinterIp, !ip.isEmpty,
           let p = settings.receiptPrinterPort, let port = UInt16(exactly: p) {
            let paperSize = settings.paperSize ?? "80mm"
            _ = await ReceiptPrinter.shared.printReceipt(receipt: receipt, ip: ip, port: port, paperSize: paperSize)
            return
        }
        // Fallback: AirPrint with receipt-sized PDF
        let paperSize = UserDefaults.standard.string(forKey: "paper_size") ?? "80mm"
        ReceiptPrinter.shared.printViaAirPrint(receipt: receipt, paperSize: paperSize)
    }

    private func autoOpenCashDrawer() async {
        if let ip = UserDefaults.standard.string(forKey: "receipt_printer_ip"),
           !ip.isEmpty,
           let portStr = UserDefaults.standard.string(forKey: "receipt_printer_port"),
           let port = UInt16(portStr) {
            _ = await ReceiptPrinter.shared.openCashDrawer(ip: ip, port: port)
        }
    }

    private func buildReceiptData(order: Order) -> ReceiptData {
        ReceiptData(
            storeName: APIService.shared.tenantName ?? "AMPOS",
            storeNameAr: APIService.shared.tenantNameAr,
            vatNumber: UserDefaults.standard.string(forKey: "vat_number"),
            branchName: nil,
            orderNumber: "\(order.displayNumber ?? 0)",
            orderType: order.orderType,
            cashierName: appState.currentUser?.nameEn ?? "Cashier",
            items: vm.cartItems.map { item in
                ReceiptData.ReceiptItem(
                    nameAr: item.product.nameAr,
                    nameEn: item.product.nameEn,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    total: item.lineTotal,
                    modifiers: item.modifierSummary.isEmpty ? nil : item.modifierSummary
                )
            },
            subtotal: vm.cartSubtotal,
            vatAmount: vm.cartVAT,
            total: vm.cartTotal,
            paymentMethod: (isSplitMode ? "Split" : selectedMethod.displayName),
            amountPaid: selectedMethod == .cash ? (Double(cashInput) ?? vm.cartTotal) : vm.cartTotal,
            change: cashChange > 0 ? cashChange : 0,
            qrData: vm.lastCompletedOrderQR,
            footer: UserDefaults.standard.string(forKey: "receipt_footer")
        )
    }

    private func shareReceipt(for order: Order) {
        let data = ReceiptPrinter.shared.generateReceiptPDF(
            receipt: buildReceiptData(order: order),
            paperSize: UserDefaults.standard.string(forKey: "paper_size") ?? "80mm"
        )
        let filename = "Receipt-\(order.displayNumber ?? 0).pdf"
        if let url = makeTemporaryPDFURL(filename: filename, data: data) {
            shareItems = [url]
        } else {
            shareItems = [data]
        }
        showShareSheet = true
    }
}

// MARK: - Payment Method Button
struct PaymentMethodButton: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void

    var methodColor: Color {
        switch method {
        case .cash:      return AppTheme.cash
        case .card:      return AppTheme.card_pay
        case .apple_pay: return AppTheme.apple
        case .mada:      return AppTheme.mada
        default:         return AppTheme.accent
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : methodColor)
                Text(method.displayName)
                    .font(AppTheme.caption(12))
                    .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(isSelected ? methodColor : AppTheme.card)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(isSelected ? .clear : AppTheme.border, lineWidth: 1))
            .shadow(color: isSelected ? methodColor.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Split Entry UI Model
struct SplitEntryUI: Identifiable {
    let id = UUID()
    let method: PaymentMethod
    let amount: Double
}

// MARK: - Share Sheet (for invoice PDF)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
