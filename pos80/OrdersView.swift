// OrdersView.swift — Orders list and detail view
import SwiftUI
import QuickLook

struct OrdersView: View {
    @EnvironmentObject var appState: AppState
    @State private var orders: [Order] = []
    @State private var isLoading = false
    @State private var selectedStatus: String? = nil
    @State private var selectedOrder: Order?
    @State private var searchText = ""
    @State private var pdfData: Data?
    @State private var showPDFPreview = false
    @State private var isDownloadingPDF = false

    private let api = APIService.shared

    private let statusFilters: [(label: String, value: String?)] = [
        ("All", nil), ("Received", "received"), ("Preparing", "preparing"),
        ("Ready", "ready"), ("Paid", "paid"), ("Cancelled", "cancelled")
    ]

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
            pdfData = data
            showPDFPreview = true
        } catch {}
        isDownloadingPDF = false
    }

    // MARK: - Header
    private var ordersHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Orders")
                        .font(AppTheme.title2())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(filteredOrders.count) orders")
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
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Search
            ThemeTextField(icon: "magnifyingglass", placeholder: "Search orders...", text: $searchText)
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
            LazyVStack(spacing: 1) {
                ForEach(filteredOrders) { order in
                    OrderRow(order: order, isSelected: selectedOrder?.id == order.id) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedOrder = order
                        }
                    } onPDF: {

                        Task { await downloadPDF(for: order) }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.textMuted)
            Text("No orders found")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }

    private func loadOrders() async {
        isLoading = true
        do {
            orders = try await api.fetchOrders()
        } catch {
            // Silently handle
        }
        isLoading = false
    }
}

// MARK: - Order Row
struct OrderRow: View {
    let order: Order
    let isSelected: Bool
    let onTap: () -> Void
    var onPDF: (() -> Void)? = nil

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
                        if let table = order.tableNumber {
                            Label("T\(table)", systemImage: "table.furniture.fill")
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
            .background(isSelected ? AppTheme.accent.opacity(0.08) : AppTheme.surface)
            .overlay(alignment: .trailing) {
                if isSelected {
                    Rectangle()
                        .fill(AppTheme.accent)
                        .frame(width: 3)
                }
            }
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

    @State private var isUpdating = false
    @State private var showPaySheet = false
    @State private var isDownloadingPDF = false
    @State private var detailPdfData: Data?
    @State private var showPDFPreview = false
    private let api = APIService.shared

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
                            Button {
                                Task { await downloadDetailPDF() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isDownloadingPDF {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "doc.text.fill")
                                    }
                                    Text("Invoice PDF")
                                }
                                .font(AppTheme.headline(13))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .disabled(isDownloadingPDF)
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
                    Text("Items").font(AppTheme.headline()).foregroundColor(AppTheme.textSecondary)
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
                        }
                        .padding(12)
                        .background(AppTheme.card)
                        .cornerRadius(AppTheme.r8)
                    }
                }

                // Totals
                VStack(spacing: 8) {
                    SummaryRow(label: "Subtotal", value: (order.subtotal ?? 0).sarFormatted)
                    if let disc = order.discountAmount, disc > 0 {
                        SummaryRow(label: "Discount", value: "-\(disc.sarFormatted)", valueColor: AppTheme.success)
                    }
                    SummaryRow(label: "VAT", value: (order.vatAmount ?? 0).sarFormatted)
                    Divider().background(AppTheme.border)
                    SummaryRow(label: "Total", value: order.totalSafe.sarFormatted,
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
    }

    private var statusActions: some View {
        VStack(spacing: 12) {
            Text("Actions").font(AppTheme.headline()).foregroundColor(AppTheme.textSecondary)

            if order.status == "received" || order.status == "draft" {
                StatusActionButton(label: "Mark Preparing", icon: "flame.fill", color: AppTheme.warning) {
                    await updateStatus("preparing")
                }
            }
            if order.status == "preparing" {
                StatusActionButton(label: "Mark Ready", icon: "checkmark.seal.fill", color: AppTheme.success) {
                    await updateStatus("ready")
                }
            }
            if order.status == "ready" {
                StatusActionButton(label: "Mark Served", icon: "fork.knife", color: AppTheme.accent) {
                    await updateStatus("served")
                }
            }

            // Cancel
            StatusActionButton(label: "Cancel Order", icon: "xmark.circle.fill", color: AppTheme.danger) {
                await updateStatus("cancelled")
            }
        }
    }

    private func downloadDetailPDF() async {
        isDownloadingPDF = true
        do {
            let data = try await api.downloadInvoicePDF(order.id)
            detailPdfData = data
            showPDFPreview = true
        } catch {}
        isDownloadingPDF = false
    }

    private func updateStatus(_ newStatus: String) async {
        isUpdating = true
        do {
            struct StatusUpdate: Codable { let status: String }
            let updated: Order = try await api.request(
                path: "/orders/\(order.id)/status",
                method: .patch,
                body: StatusUpdate(status: newStatus))
            onStatusChange(updated)
        } catch {}
        isUpdating = false
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

    var body: some View {
        NavigationStack {
            PDFViewerController(data: data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Invoice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            let tmp = FileManager.default.temporaryDirectory
                                .appendingPathComponent("Invoice.pdf")
                            try? data.write(to: tmp)
                            let ac = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let vc = scene.windows.first?.rootViewController {
                                vc.present(ac, animated: true)
                            }
                        } label: { Image(systemName: "square.and.arrow.up") }
                    }
                }
        }
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
