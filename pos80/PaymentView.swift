// PaymentView.swift — Payment processing sheet
import SwiftUI

struct PaymentView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var selectedMethod: PaymentMethod = .cash
    @State private var cashInput = ""
    @State private var customerNameInput = ""
    @State private var orderPlaced = false
    @State private var placedOrder: Order?
    @State private var isPlacing = false
    @State private var successScale: CGFloat = 0.5
    @State private var successOpacity: Double = 0

    private var cashChange: Double {
        guard selectedMethod == .cash, let tendered = Double(cashInput) else { return 0 }
        return max(0, tendered - vm.cartTotal)
    }

    private var cashIsValid: Bool {
        guard selectedMethod == .cash else { return true }
        guard let tendered = Double(cashInput) else { return false }
        return tendered >= vm.cartTotal
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
            Text("Payment Method")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)

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
        Button {
            Task { await processPayment() }
        } label: {
            HStack(spacing: 12) {
                if isPlacing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: selectedMethod.icon)
                        .font(.system(size: 18, weight: .semibold))
                    Text("Confirm \(selectedMethod.displayName) Payment")
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
                Text("Payment Successful!")
                    .font(AppTheme.title1())
                    .foregroundColor(AppTheme.textPrimary)
                if let order = placedOrder {
                    Text("Order #\(order.displayNumber ?? 0)")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textSecondary)
                }
                if cashChange > 0 {
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
    }

    // MARK: - Process Payment
    private func processPayment() async {
        isPlacing = true
        guard let order = await vm.placeOrder() else {
            isPlacing = false
            // vm.placeOrder() already calls appState.showError on failure
            return
        }
        let cashTendered = selectedMethod == .cash ? Double(cashInput) : nil
        let success = await vm.payOrder(order: order, method: selectedMethod, cashTendered: cashTendered)
        isPlacing = false

        if success {
            placedOrder = vm.lastCompletedOrder ?? order
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                orderPlaced = true
                successScale = 1
                successOpacity = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Auto-close after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
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
