// ReportsView.swift — Analytics dashboard with KPIs and charts
import SwiftUI
import Charts

struct ReportsView: View {
    @State private var dashboard: DashboardSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRange = "7d"
    @State private var topProducts: [TopProduct] = []

    private let api = APIService.shared
    private let ranges: [(String, String, String)] = [
        ("Today", "اليوم", "1d"),
        ("7 Days", "٧ أيام", "7d"),
        ("30 Days", "٣٠ يوم", "30d"),
        ("90 Days", "٩٠ يوم", "90d")
    ]

    private var isArabic: Bool { L10n.shared.isArabic }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                reportsHeader

                if isLoading {
                    kpiLoadingState
                } else if let error = errorMessage {
                    errorView(error)
                } else if dashboard != nil {
                    kpiCards
                    todayHighlightCards
                    hourlyTrendChart
                    if !topProducts.isEmpty { topProductsChart }
                    paymentBreakdown
                    orderTypeBreakdown
                } else {
                    emptyState
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
                Text(isArabic ? "التقارير" : "Reports")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text(isArabic ? "نظرة عامة على المبيعات والتحليلات" : "Sales & analytics overview")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(ranges, id: \.2) { labelEn, labelAr, value in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedRange = value
                        }
                    } label: {
                        Text(isArabic ? labelAr : labelEn)
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
                title: isArabic ? "إجمالي الإيرادات" : "Total Revenue",
                value: (dashboard?.totalRevenue ?? 0).sarFormatted,
                icon: "chart.line.uptrend.xyaxis",
                color: AppTheme.accent,
                trend: nil)

            KPICard(
                title: isArabic ? "الطلبات" : "Orders",
                value: "\(dashboard?.totalOrders ?? 0)",
                icon: "cart.fill",
                color: AppTheme.info,
                trend: nil)

            KPICard(
                title: isArabic ? "متوسط قيمة الطلب" : "Avg Order Value",
                value: (dashboard?.avgOrderValue ?? 0).sarFormatted,
                icon: "arrow.up.right",
                color: AppTheme.success,
                trend: nil)

            KPICard(
                title: isArabic ? "ضريبة القيمة المضافة" : "VAT (15%)",
                value: (dashboard?.totalVat ?? 0).sarFormatted,
                icon: "percent",
                color: AppTheme.warning,
                trend: nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Today Highlight Cards
    private var todayHighlightCards: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()),
                      GridItem(.flexible()), GridItem(.flexible())],
            spacing: 16
        ) {
            KPICard(
                title: isArabic ? "إيرادات اليوم" : "Revenue Today",
                value: (dashboard?.revenueToday ?? 0).sarFormatted,
                icon: "sun.max.fill",
                color: Color(hex: "F59E0B"),
                trend: nil)

            KPICard(
                title: isArabic ? "طلبات اليوم" : "Orders Today",
                value: "\(dashboard?.ordersToday ?? 0)",
                icon: "bag.fill",
                color: Color(hex: "3B82F6"),
                trend: nil)

            KPICard(
                title: isArabic ? "متوسط وقت الطلب" : "Avg Order Time",
                value: String(format: "%.1f %@", dashboard?.avgOrderTimeMin ?? 0, isArabic ? "دقيقة" : "min"),
                icon: "clock.fill",
                color: Color(hex: "8B5CF6"),
                trend: nil)

            KPICard(
                title: isArabic ? "إجمالي الخصومات" : "Discounts",
                value: (dashboard?.totalDiscounts ?? 0).sarFormatted,
                icon: "tag.fill",
                color: AppTheme.danger,
                trend: nil)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Hourly Trend Chart
    @ViewBuilder
    private var hourlyTrendChart: some View {
        let trend = dashboard?.hourlyTrend ?? []
        if !trend.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "الإيرادات بالساعة (اليوم)" : "Hourly Revenue (Today)")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                Chart {
                    ForEach(trend) { entry in
                        AreaMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Revenue", entry.revenue))
                        .foregroundStyle(AppTheme.accent.opacity(0.15))

                        LineMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Revenue", entry.revenue))
                        .foregroundStyle(AppTheme.accentGrad)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Hour", entry.hour),
                            y: .value("Revenue", entry.revenue))
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
            Text(isArabic ? "المنتجات الأكثر مبيعاً" : "Top Products")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)

            Chart {
                ForEach(topProducts.prefix(8)) { product in
                    BarMark(
                        x: .value("Qty", Double(product.totalQty)),
                        y: .value("Product", isArabic ? product.nameAr : product.nameEn))
                    .foregroundStyle(AppTheme.accentGrad)
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(product.totalRevenue.sarFormatted)
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            .frame(height: CGFloat(min(topProducts.count, 8)) * 44 + 40)
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
        let methods = dashboard?.revenueByPaymentMethod ?? [:]
        if !methods.isEmpty {
            let colorMap: [String: Color] = [
                "CASH": AppTheme.cash, "cash": AppTheme.cash,
                "CARD": AppTheme.card_pay, "card": AppTheme.card_pay,
                "APPLE_PAY": AppTheme.apple, "apple_pay": AppTheme.apple,
                "MADA": AppTheme.mada, "mada": AppTheme.mada,
            ]
            let nameMap: [String: (String, String)] = [
                "CASH": ("Cash", "نقدي"), "cash": ("Cash", "نقدي"),
                "CARD": ("Card", "بطاقة"), "card": ("Card", "بطاقة"),
                "APPLE_PAY": ("Apple Pay", "آبل باي"), "apple_pay": ("Apple Pay", "آبل باي"),
                "MADA": ("Mada", "مدى"), "mada": ("Mada", "مدى"),
            ]
            let items = methods.map { key, value in
                (nameMap[key]?.0 ?? key,
                 nameMap[key]?.1 ?? key,
                 value,
                 colorMap[key] ?? AppTheme.accent2)
            }.sorted { $0.2 > $1.2 }

            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "طرق الدفع" : "Payment Methods")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                // Proportional bar
                let total = items.reduce(0.0) { $0 + $1.2 }
                if total > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(items, id: \.0) { _, _, amount, color in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color)
                                    .frame(width: max(geo.size.width * amount / total - 2, 0))
                            }
                        }
                    }
                    .frame(height: 12)
                    .clipShape(Capsule())
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.0) { nameEn, nameAr, amount, color in
                        HStack(spacing: 10) {
                            Circle().fill(color).frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isArabic ? nameAr : nameEn).font(AppTheme.caption()).foregroundColor(AppTheme.textSecondary)
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
        }
    }

    // MARK: - Order Type Breakdown
    @ViewBuilder
    private var orderTypeBreakdown: some View {
        let types = dashboard?.revenueByOrderType ?? [:]
        if !types.isEmpty {
            let nameMap: [String: (String, String)] = [
                "dine_in": ("Dine In", "محلي"),
                "takeaway": ("Takeaway", "سفري"),
                "delivery": ("Delivery", "توصيل"),
            ]
            let items = types.map { key, value in
                (nameMap[key]?.0 ?? key.replacingOccurrences(of: "_", with: " ").capitalized,
                 nameMap[key]?.1 ?? key,
                 value)
            }.sorted { $0.2 > $1.2 }

            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "إيرادات حسب نوع الطلب" : "Revenue by Order Type")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                Chart {
                    ForEach(items, id: \.0) { nameEn, nameAr, revenue in
                        BarMark(
                            x: .value("Type", isArabic ? nameAr : nameEn),
                            y: .value("Revenue", revenue))
                        .foregroundStyle(AppTheme.accentGrad)
                        .cornerRadius(8)
                    }
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel().foregroundStyle(AppTheme.textSecondary)
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
            .padding(.bottom, 32)
        }
    }

    // MARK: - Loading State
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

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)
            Text(isArabic ? "خطأ في تحميل التقارير" : "Error Loading Reports")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textPrimary)
            Text(message)
                .font(AppTheme.body(14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await loadData() }
            } label: {
                Text(isArabic ? "إعادة المحاولة" : "Retry")
                    .font(AppTheme.headline(14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.accent)
                    .cornerRadius(AppTheme.r12)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)
            Text(isArabic ? "لا توجد بيانات" : "No data available")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            let dash = try await api.fetchDashboard(range: selectedRange)
            dashboard = dash
            // Top products from dedicated endpoint (may fail for non-managers — graceful)
            do {
                topProducts = try await api.request(path: "/reports/top-products?limit=10&range=\(selectedRange)")
            } catch {
                topProducts = []
            }
        } catch let error as NSError {
            if error.code == 403 {
                errorMessage = isArabic
                    ? "هذه الصفحة متاحة فقط للمدراء"
                    : "Reports require manager access."
            } else {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
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
