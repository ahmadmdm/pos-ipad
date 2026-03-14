// ReportsView.swift — Analytics dashboard with KPIs and charts
import SwiftUI
import Charts

struct ReportsView: View {
    @State private var dashboard: DashboardSummary?
    @State private var isLoading = false
    @State private var selectedRange = "7d"
    @State private var topProducts: [TopProduct] = []

    private let api = APIService.shared
    private let ranges = [("Today", "1d"), ("7 Days", "7d"), ("30 Days", "30d"), ("90 Days", "90d")]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                reportsHeader
                // KPI Cards
                if isLoading {
                    kpiLoadingState
                } else {
                    kpiCards
                    if !topProducts.isEmpty { topProductsChart }
                    revenueChart
                    paymentBreakdown
                }
            }
        }
        .background(AppTheme.bg)
        .task { await loadData() }
        .onChange(of: selectedRange) { Task { await loadData() } }
    }

    // MARK: - Header
    private var reportsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reports")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text("Sales & analytics overview")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            // Range picker
            HStack(spacing: 4) {
                ForEach(ranges, id: \.0) { label, value in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedRange = value
                        }
                    } label: {
                        Text(label)
                            .font(AppTheme.caption(12))
                            .foregroundColor(selectedRange == value ? .white : AppTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(selectedRange == value ? AppTheme.accent : AppTheme.card)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(4)
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.r12)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.border, lineWidth: 1))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    // MARK: - KPI Cards
    private var kpiCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()),
                      GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            KPICard(
                title: "Total Revenue",
                value: (dashboard?.totalRevenue ?? 0).sarFormatted,
                icon: "chart.line.uptrend.xyaxis",
                color: AppTheme.accent,
                trend: nil)

            KPICard(
                title: "Orders",
                value: "\(dashboard?.totalOrders ?? 0)",
                icon: "cart.fill",
                color: AppTheme.info,
                trend: nil)

            KPICard(
                title: "Avg Order Value",
                value: (dashboard?.averageOrderValue ?? 0).sarFormatted,
                icon: "arrow.up.right",
                color: AppTheme.success,
                trend: nil)

            KPICard(
                title: "Top Product",
                value: topProducts.first?.productNameEn ?? "—",
                icon: "star.fill",
                color: AppTheme.warning,
                trend: nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var kpiLoadingState: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .fill(AppTheme.card)
                    .frame(height: 110)
                    .shimmer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Revenue Chart
    @ViewBuilder
    private var revenueChart: some View {
        if let days = dashboard?.revenueByDay, !days.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Revenue Trend")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                Chart {
                    ForEach(days) { day in
                        AreaMark(
                            x: .value("Date", day.date),
                            y: .value("Revenue", day.revenue))
                        .foregroundStyle(AppTheme.accent.opacity(0.15))

                        LineMark(
                            x: .value("Date", day.date),
                            y: .value("Revenue", day.revenue))
                        .foregroundStyle(AppTheme.accentGrad)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Date", day.date),
                            y: .value("Revenue", day.revenue))
                        .foregroundStyle(AppTheme.accent)
                        .symbolSize(40)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.border)
                        AxisTick().foregroundStyle(AppTheme.border)
                        AxisValueLabel().foregroundStyle(AppTheme.textMuted)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.border)
                        AxisValueLabel().foregroundStyle(AppTheme.textMuted)
                    }
                }
            }
            .padding(20)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    // MARK: - Top Products Chart
    @ViewBuilder
    private var topProductsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Products")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)

            Chart {
                ForEach(topProducts.prefix(8)) { product in
                    BarMark(
                        x: .value("Qty", Double(product.totalQuantity)),
                        y: .value("Product", product.productNameEn))
                    .foregroundStyle(AppTheme.accentGrad)
                    .cornerRadius(6)
                }
            }
            .frame(height: CGFloat(min(topProducts.count, 8)) * 40 + 40)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.border)
                    AxisValueLabel().foregroundStyle(AppTheme.textMuted)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(AppTheme.textSecondary)
                        .font(.system(size: 11, design: .rounded))
                }
            }
        }
        .padding(20)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Payment Breakdown
    @ViewBuilder
    private var paymentBreakdown: some View {
        if let pb = dashboard?.paymentBreakdown {
            let items: [(String, Double, Color)] = [
                ("Cash", pb.cash ?? 0, AppTheme.cash),
                ("Card", pb.card ?? 0, AppTheme.card_pay),
                ("Apple Pay", pb.applePay ?? 0, AppTheme.apple),
                ("Mada", pb.mada ?? 0, AppTheme.mada)
            ].filter { $0.1 > 0 }

            VStack(alignment: .leading, spacing: 16) {
                Text("Payment Methods")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 0) {
                    // Pie-like bar
                    let total = items.reduce(0) { $0 + $1.1 }
                    if total > 0 {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(items, id: \.0) { name, amount, color in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(color)
                                        .frame(width: max(geo.size.width * amount / total - 2, 0))
                                }
                            }
                        }
                        .frame(height: 12)
                        .clipShape(Capsule())
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.0) { name, amount, color in
                        HStack(spacing: 10) {
                            Circle().fill(color).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(AppTheme.caption()).foregroundColor(AppTheme.textSecondary)
                                Text(amount.sarFormatted).font(AppTheme.headline(14)).foregroundColor(AppTheme.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(AppTheme.cardHover)
                        .cornerRadius(AppTheme.r8)
                    }
                }
            }
            .padding(20)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
    }

    private func loadData() async {
        isLoading = true
        async let dash = api.fetchDashboard(range: selectedRange)
        async let tops = fetchTopProducts()
        do {
            let (d, t) = try await (dash, tops)
            dashboard = d
            topProducts = t
        } catch {}
        isLoading = false
    }

    private func fetchTopProducts() async throws -> [TopProduct] {
        struct TopProductsResponse: Codable {
            let products: [TopProduct]
        }
        do {
            let resp: TopProductsResponse = try await api.request(path: "/reports/top-products?limit=10")
            return resp.products
        } catch {
            // Fallback: try as array
            let arr: [TopProduct] = try await api.request(path: "/reports/top-products?limit=10")
            return arr
        }
    }
}

// MARK: - KPI Card
struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12))
                    .cornerRadius(10)

                Spacer()

                if let trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(Int(trend)))%")
                            .font(AppTheme.caption(11))
                    }
                    .foregroundColor(trend >= 0 ? AppTheme.success : AppTheme.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((trend >= 0 ? AppTheme.success : AppTheme.danger).opacity(0.1))
                    .cornerRadius(6)
                }
            }

            Text(value)
                .font(AppTheme.title2(22))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(AppTheme.caption())
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
    }
}
