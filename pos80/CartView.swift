// CartView.swift — Cart panel and PaymentView sheet
import SwiftUI

// MARK: - Cart View
struct CartView: View {
    @EnvironmentObject var vm: POSViewModel
    @EnvironmentObject var appState: AppState

    let showPayment: () -> Void
    let showOrderType: () -> Void
    let showTablePicker: () -> Void
    let showDiscount: () -> Void
    let showNote: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            cartHeader

            // Items
            if vm.isEmpty {
                emptyCart
            } else {
                cartItemsList
            }

            // Summary + Pay
            if !vm.isEmpty {
                cartSummary
            }
        }
    }

    // MARK: - Header
    private var cartHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Order")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                HStack(spacing: 8) {
                    // Order type chip
                    Button(action: showOrderType) {
                        HStack(spacing: 4) {
                            Image(systemName: vm.orderType.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(vm.orderType.displayName)
                                .font(AppTheme.caption())
                        }
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.12))
                        .cornerRadius(6)
                    }

                    // Table chip
                    Button(action: showTablePicker) {
                        HStack(spacing: 4) {
                            Image(systemName: "table.furniture.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(vm.selectedTable != nil ? "T\(vm.selectedTable!.number)" : "No Table")
                                .font(AppTheme.caption())
                        }
                        .foregroundColor(vm.selectedTable != nil ? AppTheme.success : AppTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background((vm.selectedTable != nil ? AppTheme.success : AppTheme.textMuted).opacity(0.12))
                        .cornerRadius(6)
                    }
                }
            }

            Spacer()

            if !vm.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        vm.clearCart()
                    }
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.danger.opacity(0.12))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - Empty Cart
    private var emptyCart: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 100, height: 100)
                Image(systemName: "cart")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accent.opacity(0.5))
            }
            Text("Cart is empty")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Text("Tap a product to add it")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
            Spacer()
        }
    }

    // MARK: - Items List
    private var cartItemsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(vm.cartItems) { item in
                    CartItemRow(item: item,
                                onIncrement: { vm.incrementItem(item) },
                                onDecrement: { vm.decrementItem(item) },
                                onRemove: { withAnimation { vm.removeItem(item) } })
                }
            }
        }
    }

    // MARK: - Summary
    private var cartSummary: some View {
        VStack(spacing: 0) {
            Divider().background(AppTheme.border)

            VStack(spacing: 10) {
                // Quick actions
                HStack(spacing: 8) {
                    QuickActionButton(icon: "note.text", label: "Note",
                                      hasValue: !vm.orderNotes.isEmpty, action: showNote)
                    QuickActionButton(icon: "tag.fill", label: "Discount",
                                      hasValue: vm.discountAmount > 0, action: showDiscount)
                    QuickActionButton(icon: "clock.fill", label: "Hold") {
                        Task { await vm.holdCurrentOrder() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Subtotal rows
                VStack(spacing: 6) {
                    SummaryRow(label: "Subtotal", value: vm.cartSubtotal.sarFormatted)
                    if vm.discountAmount > 0 {
                        SummaryRow(label: "Discount",
                                   value: "-\(vm.discountAmount.sarFormatted)",
                                   valueColor: AppTheme.success)
                    }
                    SummaryRow(label: "VAT (15%)", value: vm.cartVAT.sarFormatted)
                    Divider().background(AppTheme.border)
                    SummaryRow(label: "Total",
                                value: vm.cartTotal.sarFormatted,
                                labelFont: AppTheme.headline(),
                                valueFont: AppTheme.title2(),
                                valueColor: AppTheme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                // Pay button
                Button {
                    showPayment()
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Charge  \(vm.cartTotal.sarFormatted)")
                            .font(AppTheme.headline(17))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppTheme.accentGradH)
                    .cornerRadius(AppTheme.r16)
                    .shadow(color: AppTheme.accent.opacity(0.5), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .disabled(appState.currentShift == nil)
                .overlay(alignment: .top) {
                    if appState.currentShift == nil {
                        Text("Open a shift to accept payments")
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.warning)
                            .padding(.top, -18)
                    }
                }
            }
        }
    }
}

// MARK: - Cart Item Row
struct CartItemRow: View {
    let item: CartItem
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Qty controls
            HStack(spacing: 0) {
                Button(action: onDecrement) {
                    Image(systemName: item.quantity == 1 ? "trash" : "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(item.quantity == 1 ? AppTheme.danger : AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(item.quantity == 1 ? AppTheme.danger.opacity(0.1) : AppTheme.cardHover)
                        .clipShape(Circle())
                }

                Text("\(item.quantity)")
                    .font(AppTheme.mono(14))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 28)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.product.nameEn)
                    .font(AppTheme.headline(13))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                if !item.modifierSummary.isEmpty {
                    Text(item.modifierSummary)
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Price
            Text(item.lineTotal.sarFormatted)
                .font(AppTheme.mono(13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border.opacity(0.5)).frame(height: 0.5)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash.fill")
            }
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let label: String
    let value: String
    var labelFont: Font = AppTheme.body()
    var valueFont: Font = AppTheme.body()
    var valueColor: Color = AppTheme.textSecondary

    var body: some View {
        HStack {
            Text(label).font(labelFont).foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value).font(valueFont).foregroundColor(valueColor)
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let label: String
    var hasValue: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(hasValue ? AppTheme.accent : AppTheme.textSecondary)
                    if hasValue {
                        Circle().fill(AppTheme.accent).frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(label)
                    .font(AppTheme.caption(10))
                    .foregroundColor(hasValue ? AppTheme.accent : AppTheme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(hasValue ? AppTheme.accent.opacity(0.1) : AppTheme.card)
            .cornerRadius(AppTheme.r8)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r8)
                .strokeBorder(hasValue ? AppTheme.accent.opacity(0.3) : AppTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
