// OrdersView.swift — Orders list and detail view
import SwiftUI
import QuickLook

struct OrdersView: View {
    @EnvironmentObject var appState: AppState
    private let l10n = L10n.shared
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var selectedStatus: String? = nil
    @State private var selectedOrderType: String? = nil
    @State private var filterDate = Date()
    @State private var useDateFilter = false
    @State private var resultLimit = 50
    @State private var selectedOrder: Order?
    @State private var searchText = ""
    @State private var pdfData: Data?
    @State private var showPDFPreview = false
    @State private var isDownloadingPDF = false

    private let api = APIService.shared

    private var statusFilters: [(label: String, value: String?)] {
        [(l10n.allStatus, nil), (l10n.received, "received"), (l10n.preparing, "preparing"),
         (l10n.ready, "ready"), (l10n.paid, "paid"), (l10n.cancelled, "cancelled")]
    }

    private var orderTypeFilters: [(label: String, value: String?)] {
        [("All Types", nil), ("Dine In", "dine_in"), ("Takeaway", "takeaway"), (l10n.delivery, "delivery")]
    }

    private var filteredOrders: [Order] {
        var base = orders
        if let s = selectedStatus { base = base.filter { $0.status == s } }
        if !searchText.isEmpty {
            base = base.filter {
                ($0.orderNumber ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.customerName ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.tableNumber ?? "").contains(searchText)
            }
        }
        return base
    }

    var body: some View {
        HStack(spacing: 0) {
            // List panel
            VStack(spacing: 0) {
                ordersHeader
                statusFilterBar
                advancedFilterBar
                if isLoading {
                    LoadingRows()
                } else if filteredOrders.isEmpty {
                    emptyState
                } else {
                    ordersList
                }
            }
            .background(AppTheme.bg)

            // Detail panel
            if let order = selectedOrder {
                OrderDetailView(order: order, onStatusChange: { updated in
                    if let idx = orders.firstIndex(where: { $0.id == updated.id }) {
                        orders[idx] = updated
                        selectedOrder = updated
                    }
                })
                .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
                .overlay(alignment: .leading) {
                    Rectangle().fill(AppTheme.border).frame(width: 1)
                }
            } else {
                VStack {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.textMuted)
                    Text("Select an order to view details")
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
                .overlay(alignment: .leading) {
                    Rectangle().fill(AppTheme.border).frame(width: 1)
                }
            }
        }
        .task { await loadOrders() }
        .task(id: appState.spotlightOrderId) {
            guard let targetId = appState.spotlightOrderId else { return }
            // Wait for orders to load if needed
            if orders.isEmpty { await loadOrders() }
            if let match = orders.first(where: { $0.id == targetId }) {
                withAnimation { selectedOrder = match }
            }
            appState.spotlightOrderId = nil
        }
        .sheet(isPresented: $showPDFPreview) {
            if let data = pdfData {
                PDFPreviewSheet(data: data)
            }
        }
    }

    private func downloadPDF(for order: Order) async {
        isDownloadingPDF = true
        do {
            let data = try await api.downloadInvoicePDF(order.id)
            guard isValidPDF(data) else {
                throw NSError(domain: "PDF", code: 0, userInfo: [NSLocalizedDescriptionKey: "The server returned an invalid invoice file."])
            }
            pdfData = data
            showPDFPreview = true
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
        isDownloadingPDF = false
    }

    // MARK: - Header
    private var ordersHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SERVICE MONITOR")
                        .font(AppTheme.caption(11))
                        .tracking(2)
                        .foregroundColor(AppTheme.accent)
                    Text(l10n.orders)
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(l10n.ordersCount(filteredOrders.count))
                        .font(AppTheme.caption())
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button {
                    Task { await loadOrders() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.card)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(AppTheme.border, lineWidth: 1)
                        )
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Search
            ThemeTextField(icon: "magnifyingglass", placeholder: l10n.searchOrders, text: $searchText)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Status Filter Bar
    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(statusFilters, id: \.label) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedStatus = filter.value
                        }
                    } label: {
                        Text(filter.label)
                            .font(AppTheme.headline(13))
                            .foregroundColor(selectedStatus == filter.value ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedStatus == filter.value ? AppTheme.accent : AppTheme.card)
                            .cornerRadius(8)
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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private var advancedFilterBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(orderTypeFilters, id: \.label) { filter in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedOrderType = filter.value
                            }
                            Task { await loadOrders() }
                        } label: {
                            Text(filter.label)
                                .font(AppTheme.caption(12))
                                .foregroundColor(selectedOrderType == filter.value ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedOrderType == filter.value ? AppTheme.info : AppTheme.card)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Toggle("Date", isOn: $useDateFilter)
                    .toggleStyle(SwitchToggleStyle(tint: AppTheme.accent))
                    .font(AppTheme.caption(12))

                DatePicker("", selection: $filterDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!useDateFilter)

                Picker("Limit", selection: $resultLimit) {
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await loadOrders() }
                } label: {
                    Text("Apply")
                        .font(AppTheme.caption(12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.accent)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - Orders List
    private var ordersList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(filteredOrders) { order in
                    OrderRow(order: order, isSelected: selectedOrder?.id == order.id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedOrder = order
                        }
                    } onPDF: {

                        Task { await downloadPDF(for: order) }
                    } onStatusChange: { newStatus in
                        Task { await quickUpdateStatus(for: order, to: newStatus) }
                    }
                    .contextMenu {
                        Button {
                            withAnimation { selectedOrder = order }
                        } label: {
                            Label("View Details", systemImage: "doc.text.magnifyingglass")
                        }
                        if order.status == "paid" {
                            Button {
                                Task { await downloadPDF(for: order) }
                            } label: {
                                Label("Download Invoice", systemImage: "arrow.down.doc")
                            }
                        }
                        Button {
                            UIPasteboard.general.string = order.orderNumber ?? order.id
                        } label: {
                            Label("Copy Order #", systemImage: "doc.on.doc")
                        }
                        .compatOrderContextMenuTip()
                        if order.status == "draft" {
                            Button {
                                Task { await quickActivateDraftOrder(order) }
                            } label: {
                                Label(L10n.shared.sendToKitchen, systemImage: "flame.fill")
                            }
                        }
                        if order.status == "received" {
                            Button {
                                Task { await quickUpdateStatus(for: order, to: "preparing") }
                            } label: {
                                Label(L10n.shared.startPreparing, systemImage: "flame.fill")
                            }
                        }
                        if order.status == "preparing" {
                            Button {
                                Task { await quickUpdateStatus(for: order, to: "ready") }
                            } label: {
                                Label(L10n.shared.markReady, systemImage: "checkmark.seal.fill")
                            }
                        }
                        if order.status == "ready" {
                            Button {
                                Task { await quickUpdateStatus(for: order, to: "served") }
                            } label: {
                                Label(L10n.shared.markServed, systemImage: "fork.knife")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textMuted)
            Text(l10n.noOrdersFound)
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    private func loadOrders() async {
        isLoading = true
        do {
            orders = try await api.fetchOrders(
                status: selectedStatus,
                page: 1,
                orderTypes: selectedOrderType.map { [$0] } ?? [],
                date: useDateFilter ? formattedDate(filterDate) : nil,
                limit: resultLimit
            )
            SpotlightManager.shared.indexOrders(orders)
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
        isLoading = false
    }

    private func quickUpdateStatus(for order: Order, to newStatus: String) async {
        do {
            let updated = try await api.transitionOrder(order.id, currentStatus: order.status, newStatus: newStatus)
            if let idx = orders.firstIndex(where: { $0.id == updated.id }) {
                orders[idx] = updated
            }
            if selectedOrder?.id == updated.id {
                selectedOrder = updated
            }
            appState.showSuccess(newStatus.capitalized)
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func quickActivateDraftOrder(_ order: Order) async {
        do {
            let updated = try await api.activateDraftOrder(order.id)
            if let idx = orders.firstIndex(where: { $0.id == updated.id }) {
                orders[idx] = updated
            }
            if selectedOrder?.id == updated.id {
                selectedOrder = updated
            }
            appState.showSuccess(l10n.sentToKitchen)
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isValidPDF(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return String(data: data.prefix(4), encoding: .ascii) == "%PDF"
    }
}

// MARK: - Order Row
struct OrderRow: View {
    let order: Order
    let isSelected: Bool
    let onTap: () -> Void
    var onPDF: (() -> Void)? = nil
    var onStatusChange: ((String) -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: order.orderStatus.color))
                        .frame(width: 10, height: 10)
                    Text("#\(order.displayNumber ?? 0)")
                        .font(AppTheme.mono(11))
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(order.orderNumber ?? "Order")
                            .font(AppTheme.headline(14))
                            .foregroundColor(AppTheme.textPrimary)
                        PillBadge(text: order.orderStatus.displayName,
                                  color: Color(hex: order.orderStatus.color))
                    }

                    HStack(spacing: 8) {
                        if let table = order.displayTableNumber {
                            Label(table, systemImage: "table.furniture.fill")
                                .font(AppTheme.caption(11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        if let name = order.customerName {
                            Label(name, systemImage: "person.fill")
                                .font(AppTheme.caption(11))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        Text(order.orderType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(order.totalSafe.sarFormatted)
                        .font(AppTheme.mono(14))
                        .foregroundColor(AppTheme.textPrimary)
                    if let createdAt = order.createdAt {
                        Text(formatOrderTime(createdAt))
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                // PDF button
                if order.status == "paid" {
                    Button {
                        onPDF?()
                    } label: {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.accent.opacity(0.12))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .fill(isSelected ? AppTheme.accent.opacity(0.08) : AppTheme.card)
            )
            .overlay(alignment: .trailing) {
                if isSelected {
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(width: 3)
                        .padding(.vertical, 12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(isSelected ? AppTheme.accent.opacity(0.25) : AppTheme.border, lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.accent.opacity(0.08) : AppTheme.shadow.opacity(0.55), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func formatOrderTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return isoString }
        let display = DateFormatter()
        display.dateFormat = "HH:mm"
        return display.string(from: date)
    }
}

// MARK: - Loading Rows
struct LoadingRows: View {
    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle().fill(AppTheme.card).frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.card).frame(width: 140, height: 14)
                        RoundedRectangle(cornerRadius: 4).fill(AppTheme.card).frame(width: 90, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4).fill(AppTheme.card).frame(width: 70, height: 14)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .shimmer()
            }
        }
    }
}

// MARK: - Order Detail View
struct OrderDetailView: View {
    let order: Order
    let onStatusChange: (Order) -> Void

    @EnvironmentObject var appState: AppState
    @State private var isUpdating = false
    @State private var showPaySheet = false
    @State private var isDownloadingPDF = false
    @State private var detailPdfData: Data?
    @State private var showPDFPreview = false
    @State private var showManagerApproval = false
    @State private var pendingVoidItem: OrderItem?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showChargeSheet = false
    private let api = APIService.shared
    private let l10n = L10n.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Order \(order.orderNumber ?? "#\(order.displayNumber ?? 0)")")
                            .font(AppTheme.title2())
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 8) {
                            PillBadge(text: order.orderStatus.displayName,
                                      color: Color(hex: order.orderStatus.color))
                            Text(order.orderType.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(AppTheme.caption())
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(order.totalSafe.sarFormatted)
                            .font(AppTheme.display(32))
                            .foregroundStyle(AppTheme.accentGrad)
                        if order.status == "paid" {
                            HStack(spacing: 8) {
                                // Receipt-sized print/share
                                Button {
                                    printOrderReceipt()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "printer.fill")
                                        Text(l10n.printReceipt)
                                    }
                                    .font(AppTheme.headline(12))
                                    .foregroundColor(AppTheme.success)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.success.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                Button {
                                    shareReceiptPDF()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "square.and.arrow.up")
                                        Text(l10n.downloadInvoice)
                                    }
                                    .font(AppTheme.headline(12))
                                    .foregroundColor(AppTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.accent.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)

                                // A4 Invoice PDF
                                Button {
                                    Task { await downloadDetailPDF() }
                                } label: {
                                    HStack(spacing: 4) {
                                        if isDownloadingPDF {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "doc.text.fill")
                                        }
                                        Text(l10n.invoicePDF)
                                    }
                                    .font(AppTheme.headline(12))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppTheme.card)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AppTheme.border, lineWidth: 1))
                                }
                                .disabled(isDownloadingPDF)
                            }
                        }
                    }
                }
                .padding(20)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r16)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: 1))

                // Meta info
                HStack(spacing: 12) {
                    if let table = order.tableNumber {
                        MetaChip(icon: "table.furniture.fill", value: "Table \(table)")
                    }
                    if let name = order.customerName {
                        MetaChip(icon: "person.fill", value: name)
                    }
                    if let method = order.paymentMethod {
                        MetaChip(icon: "creditcard.fill", value: method.capitalized)
                    }
                }

                // Items
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.items_label).font(AppTheme.headline()).foregroundColor(AppTheme.textSecondary)
                    ForEach(order.items ?? []) { item in
                        HStack(spacing: 12) {
                            Text("×\(item.quantity)")
                                .font(AppTheme.mono(14))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 28)
                            Text(item.productNameEn ?? "")
                                .font(AppTheme.body())
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text((item.lineTotal ?? item.unitPrice * Double(item.quantity)).sarFormatted)
                                .font(AppTheme.mono(14))
                                .foregroundColor(AppTheme.textSecondary)
                            if canVoidItems {
                                Button {
                                    Task { await requestVoidApproval(for: item) }
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.danger)
                                        .frame(width: 28, height: 28)
                                        .background(AppTheme.danger.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.r8)
                    }
                }

                // Totals
                VStack(spacing: 8) {
                    SummaryRow(label: l10n.subtotal, value: (order.subtotal ?? 0).sarFormatted)
                    if let disc = order.discountAmount, disc > 0 {
                        SummaryRow(label: l10n.discount, value: "-\(disc.sarFormatted)", valueColor: AppTheme.success)
                    }
                    SummaryRow(label: l10n.vat, value: (order.vatAmount ?? 0).sarFormatted)
                    Divider().background(AppTheme.border)
                    SummaryRow(label: l10n.total, value: order.totalSafe.sarFormatted,
                               labelFont: AppTheme.headline(), valueFont: AppTheme.title2(), valueColor: AppTheme.accent)
                }
                .padding(16)
                .background(AppTheme.card)
                .cornerRadius(AppTheme.r12)

                // Status actions
                if order.status != "paid" && order.status != "cancelled" && order.status != "void" {
                    statusActions
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showPDFPreview) {
            if let data = detailPdfData {
                PDFPreviewSheet(data: data)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $showChargeSheet) {
            ChargeOrderSheet(order: order) { paid in
                onStatusChange(paid)
                appState.showSuccess("\(l10n.paymentSuccessfulOrder) #\(paid.displayNumber ?? 0)")
            }
            .environmentObject(appState)
        }
        .sheet(isPresented: $showManagerApproval) {
            ManagerApprovalSheet(
                actionTitle: pendingVoidItem == nil ? l10n.cancelOrderApproval : l10n.voidItemApproval,
                message: l10n.managerApprovalRequired
            ) { _ in
                if let item = pendingVoidItem {
                    Task { await voidItem(item) }
                } else {
                    Task { await updateStatus("cancelled") }
                }
            }
        }
        // Handoff — advertise this order so it can be continued on another device
        .userActivity("com.ampos.pos80.viewOrder") { activity in
            activity.title = "Order \(order.orderNumber ?? "#\(order.displayNumber ?? 0)")"
            activity.userInfo = ["orderId": order.id]
            activity.isEligibleForHandoff = true
        }
    }

    private var statusActions: some View {
        VStack(spacing: 12) {
            Text(l10n.actions).font(AppTheme.headline()).foregroundColor(AppTheme.textSecondary)

            // Collect payment for any unpaid order (incl. those sent to kitchen)
            StatusActionButton(label: "\(l10n.payment) — \(order.totalSafe.sarFormatted)",
                               icon: "creditcard.fill", color: AppTheme.success) {
                showChargeSheet = true
            }

            if order.status == "draft" {
                StatusActionButton(label: l10n.sendToKitchen, icon: "flame.fill", color: AppTheme.warning) {
                    await activateDraftOrder()
                }
            }
            if order.status == "received" {
                StatusActionButton(label: l10n.startPreparing, icon: "flame.fill", color: AppTheme.warning) {
                    await updateStatus("preparing")
                }
            }
            if order.status == "preparing" {
                StatusActionButton(label: l10n.markReady, icon: "checkmark.seal.fill", color: AppTheme.success) {
                    await updateStatus("ready")
                }
            }
            if order.status == "ready" {
                StatusActionButton(label: l10n.markServed, icon: "fork.knife", color: AppTheme.accent) {
                    await updateStatus("served")
                }
            }

            // Cancel
            StatusActionButton(label: l10n.cancelOrder, icon: "xmark.circle.fill", color: AppTheme.danger) {
                await requestCancelApproval()
            }
        }
    }

    private var canVoidItems: Bool {
        order.status != "paid" && order.status != "cancelled" && order.status != "void"
    }

    private func requestCancelApproval() async {
        pendingVoidItem = nil
        if appState.currentUser?.isManager ?? false {
            await updateStatus("cancelled")
        } else {
            showManagerApproval = true
        }
    }

    private func requestVoidApproval(for item: OrderItem) async {
        pendingVoidItem = item
        if appState.currentUser?.isManager ?? false {
            await voidItem(item)
        } else {
            showManagerApproval = true
        }
    }

    private func downloadDetailPDF() async {
        isDownloadingPDF = true
        do {
            let data = try await api.downloadInvoicePDF(order.id)
            guard isValidPDF(data) else {
                throw NSError(domain: "PDF", code: 0, userInfo: [NSLocalizedDescriptionKey: "The server returned an invalid invoice file."])
            }
            detailPdfData = data
            showPDFPreview = true
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
        isDownloadingPDF = false
    }

    private func updateStatus(_ newStatus: String) async {
        isUpdating = true
        do {
            let updated = try await api.transitionOrder(order.id, currentStatus: order.status, newStatus: newStatus)
            onStatusChange(updated)
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
        isUpdating = false
    }

    private func activateDraftOrder() async {
        isUpdating = true
        do {
            let updated = try await api.activateDraftOrder(order.id)
            onStatusChange(updated)
            appState.showSuccess(l10n.sentToKitchen)
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
        isUpdating = false
    }

    private func voidItem(_ item: OrderItem) async {
        isUpdating = true
        defer {
            pendingVoidItem = nil
            isUpdating = false
        }
        do {
            let updated = try await api.voidOrderItem(orderId: order.id, itemId: item.id)
            onStatusChange(updated)
            appState.showSuccess(l10n.voidItem)
        } catch {
            appState.toast = ToastMessage(type: .error, text: error.localizedDescription)
        }
    }

    private func buildReceiptDataFromOrder(_ order: Order) -> ReceiptData {
        // 1) Try to find saved ZATCA QR from LocalInvoiceStore (most reliable)
        let savedQR: String? = LocalInvoiceStore.shared.invoices
            .first(where: { inv in inv.orderLocalId == order.id || inv.orderNumber == order.orderNumber })
            .flatMap { $0.qrCodeBase64.isEmpty ? nil : $0.qrCodeBase64 }

        // 2) If not saved, generate on the fly
        let zatcaQR: String?
        if let qr = savedQR {
            zatcaQR = qr
        } else {
            let sellerName = APIService.shared.tenantNameAr
                ?? UserDefaults.standard.string(forKey: "seller_name_ar")
                ?? APIService.shared.tenantName ?? "AMPOS"
            let vatNumber = UserDefaults.standard.string(forKey: "vat_number") ?? ""
            let timestamp = order.paidAt ?? order.createdAt ?? ISO8601DateFormatter().string(from: Date())
            if !vatNumber.isEmpty {
                zatcaQR = ZATCALocalSigner.generateQRBase64(
                    sellerName: sellerName,
                    vatNumber: vatNumber,
                    timestamp: timestamp,
                    totalWithVAT: order.totalSafe,
                    vatAmount: order.vatAmount ?? 0
                )
            } else {
                zatcaQR = nil
            }
        }

        return ReceiptData(
            storeName: APIService.shared.tenantName ?? "AMPOS",
            storeNameAr: APIService.shared.tenantNameAr,
            vatNumber: UserDefaults.standard.string(forKey: "vat_number"),
            branchName: nil,
            orderNumber: "\(order.displayNumber ?? 0)",
            orderType: order.orderType,
            cashierName: appState.currentUser?.nameEn ?? "Cashier",
            items: (order.items ?? []).map { item in
                ReceiptData.ReceiptItem(
                    nameAr: item.productNameAr ?? "",
                    nameEn: item.productNameEn ?? "",
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    total: item.lineTotal ?? item.unitPrice * Double(item.quantity),
                    modifiers: nil
                )
            },
            subtotal: order.subtotal ?? 0,
            vatAmount: order.vatAmount ?? 0,
            total: order.totalSafe,
            paymentMethod: order.paymentMethod?.capitalized ?? "N/A",
            amountPaid: order.totalSafe,
            change: 0,
            qrData: zatcaQR,
            footer: UserDefaults.standard.string(forKey: "receipt_footer")
        )
    }

    private func printOrderReceipt() {
        let receipt = buildReceiptDataFromOrder(order)
        let paperSize = UserDefaults.standard.string(forKey: "paper_size") ?? "80mm"

        Task {
            // Try ESC/POS first
            if let ip = UserDefaults.standard.string(forKey: "receipt_printer_ip"),
               !ip.isEmpty,
               let portStr = UserDefaults.standard.string(forKey: "receipt_printer_port"),
               let port = UInt16(portStr) {
                _ = await ReceiptPrinter.shared.printReceipt(receipt: receipt, ip: ip, port: port, paperSize: paperSize)
                return
            }
            // Fallback: AirPrint
            ReceiptPrinter.shared.printViaAirPrint(receipt: receipt, paperSize: paperSize)
        }
    }

    private func shareReceiptPDF() {
        let data = ReceiptPrinter.shared.generateReceiptPDF(
            receipt: buildReceiptDataFromOrder(order),
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

    private func isValidPDF(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return String(data: data.prefix(4), encoding: .ascii) == "%PDF"
    }
}

// MARK: - Supporting Views
struct MetaChip: View {
    let icon: String
    let value: String
    var body: some View {
        Label(value, systemImage: icon)
            .font(AppTheme.caption())
            .foregroundColor(AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppTheme.card)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.border, lineWidth: 1))
    }
}

struct StatusActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(AppTheme.headline())
                Spacer()
            }
            .foregroundColor(color)
            .padding(14)
            .background(color.opacity(0.1))
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PDF Preview Sheet
import PDFKit

struct PDFPreviewSheet: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private var hasValidDocument: Bool {
        PDFDocument(data: data) != nil
    }

    var body: some View {
        CompatNavigationContainer {
            Group {
                if hasValidDocument {
                    PDFViewerController(data: data)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.warning)
                        Text("The invoice preview is unavailable for this order.")
                            .font(AppTheme.body(15))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.bg.ignoresSafeArea())
                }
            }
            .navigationTitle("Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        sharePreviewPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!hasValidDocument)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    private func sharePreviewPDF() {
        if let url = makeTemporaryPDFURL(filename: "Invoice.pdf", data: data) {
            shareItems = [url]
        } else {
            shareItems = [data]
        }
        showShareSheet = true
    }
}

struct PDFViewerController: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .white

        let pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        pdfView.overrideUserInterfaceStyle = .light

        vc.view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
        ])

        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

// MARK: - Charge Order Sheet
/// Lets the cashier collect payment for an existing (unpaid) order — used after
/// the order was sent to the kitchen with the "Send to Kitchen" action.
struct ChargeOrderSheet: View {
    let order: Order
    let onPaid: (Order) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var selectedMethod: PaymentMethod = .cash
    @State private var cashInput: String = ""
    @State private var isProcessing = false
    @State private var errorText: String?
    private let api = APIService.shared
    private let l10n = L10n.shared

    private var total: Double { order.totalSafe }
    private var cashTendered: Double? { selectedMethod == .cash ? Double(cashInput) : nil }
    private var change: Double {
        guard let t = cashTendered else { return 0 }
        return max(0, t - total)
    }
    private var isCashSufficient: Bool {
        selectedMethod != .cash || (cashTendered ?? 0) >= total
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Total
                    VStack(spacing: 4) {
                        Text(l10n.totalAmount)
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.textMuted)
                        Text(total.sarFormatted)
                            .font(AppTheme.display(40))
                            .foregroundStyle(AppTheme.accentGrad)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(AppTheme.card)
                    .cornerRadius(AppTheme.r16)

                    // Method picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.paymentMethod)
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textSecondary)
                        Picker("", selection: $selectedMethod) {
                            Text(l10n.cash).tag(PaymentMethod.cash)
                            Text(l10n.card).tag(PaymentMethod.card)
                            Text(l10n.mada).tag(PaymentMethod.mada)
                            Text(l10n.applePay).tag(PaymentMethod.apple_pay)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Cash input
                    if selectedMethod == .cash {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(l10n.cashTendered)
                                .font(AppTheme.headline())
                                .foregroundColor(AppTheme.textSecondary)
                            HStack {
                                TextField(l10n.amountReceived, text: $cashInput)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .background(AppTheme.card)
                                    .cornerRadius(AppTheme.r8)
                                Button(l10n.exact) {
                                    cashInput = String(format: "%.2f", total)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(AppTheme.accent.opacity(0.1))
                                .foregroundColor(AppTheme.accent)
                                .cornerRadius(AppTheme.r8)
                            }
                            if let t = cashTendered, t >= total {
                                SummaryRow(label: l10n.change,
                                           value: change.sarFormatted,
                                           valueColor: AppTheme.success)
                            } else if !cashInput.isEmpty {
                                Text(l10n.insufficientAmount)
                                    .font(AppTheme.caption())
                                    .foregroundColor(AppTheme.danger)
                            }
                        }
                    }

                    if let err = errorText {
                        Text(err)
                            .font(AppTheme.caption())
                            .foregroundColor(AppTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Pay button
                    Button {
                        Task { await charge() }
                    } label: {
                        HStack {
                            if isProcessing { ProgressView().tint(.white) }
                            Text(l10n.confirmPayment(methodLabel))
                                .font(AppTheme.headline(16))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isCashSufficient ? AppTheme.accentGradH : LinearGradient(colors: [AppTheme.textMuted], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.r16)
                    }
                    .disabled(isProcessing || !isCashSufficient)
                }
                .padding(20)
            }
            .background(AppTheme.bg)
            .navigationTitle(l10n.payment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.cancel) { dismiss() }
                }
            }
        }
    }

    private var methodLabel: String {
        switch selectedMethod {
        case .cash: return l10n.cash
        case .card: return l10n.card
        case .mada: return l10n.mada
        case .apple_pay: return l10n.applePay
        default: return l10n.payment
        }
    }

    private func charge() async {
        isProcessing = true
        errorText = nil
        do {
            let payment = OrderPayment(
                paymentMethod: selectedMethod.rawValue,
                paymentReference: nil,
                cashTendered: cashTendered)
            let paid = try await api.payOrder(order.id, payment: payment)
            onPaid(paid)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
        isProcessing = false
    }
}
