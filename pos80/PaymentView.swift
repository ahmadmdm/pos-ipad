// PaymentView.swift — Payment processing sheet
import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var offlineManager = OfflineManager.shared

    @State private var selectedMethod: PaymentMethod = .cash
    @State private var cashInput = ""
    @State private var customerNameInput = ""
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
        .preferredColorScheme(.dark)
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
                Text("Payment")
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
            Text("Total Amount")
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
                Text("Order Summary")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text("\(vm.cartCount) items")
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
                SummaryRow(label: "Subtotal", value: vm.cartSubtotal.sarFormatted)
                if vm.discountAmount > 0 {
                    SummaryRow(label: "Discount", value: "-\(vm.discountAmount.sarFormatted)", valueColor: AppTheme.success)
                }
                SummaryRow(label: "VAT (15%)", value: vm.cartVAT.sarFormatted)
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
                Text("Payment Method")
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
                        Text(isSplitMode ? "Single" : "Split")
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
                        TextField("Amount", text: $splitAmountInput)
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
                            Text("Rest")
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
                Text("Remaining")
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
            Text("Cash Tendered")
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
                            Text(amount == 0 ? "Exact" : "\(Int(amount))")
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
                placeholder: "Amount received",
                text: $cashInput,
                keyboardType: .decimalPad)

            // Change calculation
            if let tendered = Double(cashInput), tendered > 0 {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Change")
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text(cashChange.sarFormatted)
                            .font(AppTheme.title2())
                            .foregroundColor(cashChange >= 0 ? AppTheme.success : AppTheme.danger)
                    }
                    Spacer()
                    if cashChange < 0 {
                        Text("Insufficient amount")
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Customer (Optional)")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            ThemeTextField(icon: "person.fill", placeholder: "Customer name", text: $customerNameInput)
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
                    Text("Offline mode — order will sync when connected")
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
                        Text(isSplitMode ? "Confirm Split Payment" : "Confirm \(selectedMethod.displayName) Payment")
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
    @State private var invoiceData: Data?
    @State private var showShareSheet = false

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
                Text("Payment Successful!")
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
                // Download Invoice button
                if let order = placedOrder {
                    Button {
                        Task {
                            invoiceData = await vm.downloadInvoicePDF(orderId: order.id)
                            if invoiceData != nil {
                                showShareSheet = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Download Invoice")
                                .font(AppTheme.headline(14))
                        }
                        .foregroundColor(AppTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AppTheme.accent.opacity(0.12))
                        .cornerRadius(AppTheme.r12)
                    }
                    .buttonStyle(.plain)
                }

                // Print Receipt button
                if let order = placedOrder {
                    Button {
                        Task { await autoPrintReceipt(order: order) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Print Receipt")
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
                    Text("New Order")
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
        .sheet(isPresented: $showShareSheet) {
            if let data = invoiceData {
                ShareSheet(items: [data])
            }
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

            // Auto-print receipt
            Task { await autoPrintReceipt(order: placedOrder!) }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { dismiss() }
        }
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
        // Check if printer is configured
        guard let ip = UserDefaults.standard.string(forKey: "receipt_printer_ip"),
              !ip.isEmpty,
              let portStr = UserDefaults.standard.string(forKey: "receipt_printer_port"),
              let port = UInt16(portStr) else {
            // Try from API settings if saved
            if let settings = try? await APIService.shared.fetchSettings(),
               let ip = settings.receiptPrinterIp, !ip.isEmpty,
               let p = settings.receiptPrinterPort, let port = UInt16(exactly: p) {
                await doPrint(order: order, ip: ip, port: port)
            }
            return
        }
        await doPrint(order: order, ip: ip, port: port)
    }

    private func doPrint(order: Order, ip: String, port: UInt16) async {
        let receipt = ReceiptData(
            storeName: "AMPOS",
            storeNameAr: nil,
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
            qrData: nil,
            footer: UserDefaults.standard.string(forKey: "receipt_footer")
        )
        _ = await ReceiptPrinter.shared.printReceipt(receipt: receipt, ip: ip, port: port)
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
