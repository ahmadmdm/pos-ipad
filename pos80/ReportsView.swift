// ReportsView.swift — Analytics dashboard with KPIs and charts
import SwiftUI
import Charts

@available(iOS 16.0, *)
struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var dashboard: DashboardSummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRange = "7d"
    @State private var topProducts: [TopProduct] = []
    @State private var paymentsSummary: [PaymentSummaryRow] = []
    @State private var zatcaReport: ZATCAReport?
    @State private var dailyReport: DailyReport?
    @State private var monthlyReport: MonthlyReport?
    @State private var profitabilityRows: [ProfitabilityRow] = []
    @State private var ordersReport: [Order] = []
    @State private var managerOverrideToken: String?
    @State private var managerApproverName: String?
    @State private var showManagerApproval = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    private let api = APIService.shared
    private let ranges: [(String, String, String)] = [
        ("Today", "اليوم", "1d"),
        ("7 Days", "٧ أيام", "7d"),
        ("30 Days", "٣٠ يوم", "30d"),
        ("90 Days", "٩٠ يوم", "90d")
    ]

    private var isArabic: Bool { L10n.shared.isArabic }
    private var hasNativeReportAccess: Bool { appState.currentUser?.isManager ?? false }
    private var hasUnlockedReports: Bool { hasNativeReportAccess || managerOverrideToken != nil }
    private var reportAccessToken: String? { hasNativeReportAccess ? nil : managerOverrideToken }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                reportsHeader

                if isLoading {
                    kpiLoadingState
                } else if !hasUnlockedReports {
                    lockedState
                } else if let error = errorMessage {
                    errorView(error)
                } else if dashboard != nil {
                    kpiCards
                    extendedReportsSection
                    todayHighlightCards
                    hourlyTrendChart
                    if !topProducts.isEmpty { topProductsChart }
                    paymentBreakdown
                    detailedPaymentSummary
                    zatcaComplianceCard
                    orderTypeBreakdown
                } else {
                    emptyState
                }
            }
        }
        .background(AppTheme.bgGradient)
        .task { await reloadIfAuthorized() }
        .onChange(of: selectedRange) { _ in Task { await reloadIfAuthorized() } }
        .sheet(isPresented: $showManagerApproval) {
            ManagerApprovalSheet(
                actionTitle: L10n.shared.managerApproval,
                message: L10n.shared.managerOnlyReports
            ) { result in
                managerOverrideToken = result.token.accessToken
                managerApproverName = L10n.shared.isArabic ? (result.manager.nameAr.isEmpty ? result.manager.displayName : result.manager.nameAr) : result.manager.displayName
                Task { await loadData() }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Header
    private var reportsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("BUSINESS HEALTH")
                    .font(AppTheme.caption(11))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Text(isArabic ? "التقارير" : "Reports")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text(isArabic ? "نظرة عامة على المبيعات والتحليلات" : "Sales & analytics overview")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
                if let managerApproverName, !hasNativeReportAccess {
                    Text("\(L10n.shared.approvedBy): \(managerApproverName)")
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.success)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    if !hasUnlockedReports {
                        Button {
                            showManagerApproval = true
                        } label: {
                            Label(L10n.shared.unlockReports, systemImage: "lock.open.fill")
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.accent.opacity(0.12))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    if hasUnlockedReports, dashboard != nil {
                        Button {
                            exportCurrentReports()
                        } label: {
                            Label(L10n.shared.shareReports, systemImage: "square.and.arrow.up")
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.card)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

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
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.surface.opacity(0.55))
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
                color: AppTheme.warning,
                trend: nil)

            KPICard(
                title: isArabic ? "طلبات اليوم" : "Orders Today",
                value: "\(dashboard?.ordersToday ?? 0)",
                icon: "bag.fill",
                color: AppTheme.info,
                trend: nil)

            KPICard(
                title: isArabic ? "متوسط وقت الطلب" : "Avg Order Time",
                value: String(format: "%.1f %@", dashboard?.avgOrderTimeMin ?? 0, isArabic ? "دقيقة" : "min"),
                icon: "clock.fill",
                color: AppTheme.accent,
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
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
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
        .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
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
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var detailedPaymentSummary: some View {
        if !paymentsSummary.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "ملخص المدفوعات التفصيلي" : "Detailed Payments Summary")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(paymentsSummary.sorted { $0.total > $1.total }) { row in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(paymentMethodName(row.method))
                                    .font(AppTheme.headline(14))
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Text(orderCountLabel(row.count))
                                    .font(AppTheme.caption(11))
                                    .foregroundColor(AppTheme.textMuted)
                            }

                            HStack {
                                metricTile(
                                    title: isArabic ? "الإجمالي" : "Total",
                                    value: row.total.sarFormatted,
                                    color: AppTheme.accent
                                )
                                metricTile(
                                    title: isArabic ? "الضريبة" : "VAT",
                                    value: row.vat.sarFormatted,
                                    color: AppTheme.warning
                                )
                            }
                        }
                        .padding(16)
                        .background(AppTheme.cardHover)
                        .cornerRadius(AppTheme.r12)
                    }
                }
            }
            .padding(20)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var zatcaComplianceCard: some View {
        if let zatcaReport {
            VStack(alignment: .leading, spacing: 16) {
                Text(isArabic ? "امتثال هيئة الزكاة" : "ZATCA Compliance")
                    .font(AppTheme.headline())
                    .foregroundColor(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    metricTile(
                        title: isArabic ? "الفواتير" : "Invoices",
                        value: "\(zatcaReport.totalInvoices)",
                        color: AppTheme.success
                    )
                    metricTile(
                        title: isArabic ? "ضريبة محصلة" : "VAT Collected",
                        value: zatcaReport.totalVatCollected.sarFormatted,
                        color: AppTheme.warning
                    )
                }

                if !zatcaReport.byStatus.isEmpty {
                    FlowLayout(spacing: 10) {
                        ForEach(zatcaReport.byStatus.keys.sorted(), id: \.self) { status in
                            let count = zatcaReport.byStatus[status] ?? 0
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor(status))
                                    .frame(width: 8, height: 8)
                                Text("\(statusTitle(status)): \(count)")
                                    .font(AppTheme.caption(12))
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.cardHover)
                            .cornerRadius(999)
                        }
                    }
                }
            }
            .padding(20)
            .background(AppTheme.card)
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(AppTheme.border, lineWidth: 1))
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
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
            .shadow(color: AppTheme.shadow.opacity(0.7), radius: 18, y: 8)
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

    private var lockedState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.warning)
            Text(L10n.shared.managerOnlyReports)
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Button {
                showManagerApproval = true
            } label: {
                Text(L10n.shared.unlockReports)
            }
            .buttonStyle(PrimaryButtonStyle(isFullWidth: false))
        }
        .padding(.horizontal, 32)
    }

    private var extendedReportsSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                reportSnapshotCard(
                    title: L10n.shared.dailyReport,
                    value: (dailyReport?.totalRevenue ?? 0).sarFormatted,
                    subtitle: "\(dailyReport?.totalOrders ?? 0) \(L10n.shared.orders)",
                    color: AppTheme.info
                )

                reportSnapshotCard(
                    title: L10n.shared.monthlyReport,
                    value: (monthlyReport?.totalRevenue ?? 0).sarFormatted,
                    subtitle: "\(monthlyReport?.totalOrders ?? 0) \(L10n.shared.orders)",
                    color: AppTheme.success
                )
            }
            .padding(.horizontal, 24)

            if !profitabilityRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.shared.profitabilityReport)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textPrimary)

                    VStack(spacing: 10) {
                        ForEach(Array(profitabilityRows.prefix(5))) { row in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(isArabic ? (row.nameAr ?? row.nameEn ?? "-") : (row.nameEn ?? row.nameAr ?? "-"))
                                        .font(AppTheme.caption(13))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("\(L10n.shared.revenue): \((row.totalRevenue ?? 0).sarFormatted)")
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text((row.profit ?? 0).sarFormatted)
                                        .font(AppTheme.mono(13))
                                        .foregroundColor(AppTheme.success)
                                    Text(String(format: "%.1f%%", row.marginPct ?? 0))
                                        .font(AppTheme.caption(11))
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.card)
                            .cornerRadius(AppTheme.r12)
                        }
                    }
                }
                .padding(20)
                .background(AppTheme.surface)
                .cornerRadius(AppTheme.r16)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: 1))
                .padding(.horizontal, 24)
            }

            if !ordersReport.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.shared.ordersReport)
                        .font(AppTheme.headline())
                        .foregroundColor(AppTheme.textPrimary)
                    ForEach(Array(ordersReport.prefix(5))) { order in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.orderNumber ?? order.id)
                                    .font(AppTheme.caption(13))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(order.orderType.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(AppTheme.caption(11))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            Spacer()
                            Text(order.totalSafe.sarFormatted)
                                .font(AppTheme.mono(13))
                                .foregroundColor(AppTheme.accent)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(20)
                .background(AppTheme.surface)
                .cornerRadius(AppTheme.r16)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                    .strokeBorder(AppTheme.border, lineWidth: 1))
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 20)
    }

    private func reportSnapshotCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.caption(12))
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.title2())
                .foregroundColor(AppTheme.textPrimary)
            Text(subtitle)
                .font(AppTheme.caption(11))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface)
        .cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
            .strokeBorder(AppTheme.border, lineWidth: 1))
    }

    // MARK: - Data Loading
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        paymentsSummary = []
        zatcaReport = nil
        dailyReport = nil
        monthlyReport = nil
        profitabilityRows = []
        ordersReport = []

        // Fetch dashboard first — if it fails the remaining requests are skipped,
        // avoiding the async-let implicit-cancellation deallocation crash.
        let dash: DashboardSummary
        do {
            dash = try await api.fetchDashboard(range: selectedRange, authToken: reportAccessToken)
        } catch {
            let nsError = error as NSError
            if nsError.code == 403 {
                if !hasNativeReportAccess {
                    managerOverrideToken = nil
                    managerApproverName = nil
                }
                errorMessage = isArabic
                    ? "هذه الصفحة متاحة فقط للمدراء"
                    : "Reports require manager access."
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            return
        }

        dashboard = dash

        // Fetch remaining data concurrently — all tasks are always awaited.
        async let paymentsTask = try? api.fetchPaymentsSummary(range: selectedRange, authToken: reportAccessToken)
        async let zatcaTask = try? api.fetchZATCAReport(range: selectedRange, authToken: reportAccessToken)
        async let productsTask = try? api.fetchTopProducts(limit: 10, range: selectedRange, authToken: reportAccessToken)
        async let dailyTask = try? api.fetchDailyReport()
        async let monthlyTask = try? api.fetchMonthlyReport()
        async let profitabilityTask = try? api.fetchProfitabilityReport(range: selectedRange)
        async let ordersTask = try? api.fetchOrdersReport(range: selectedRange, skip: 0, limit: 20)

        paymentsSummary = await paymentsTask ?? []
        zatcaReport = await zatcaTask
        topProducts = await productsTask ?? []
        dailyReport = await dailyTask
        monthlyReport = await monthlyTask
        profitabilityRows = await profitabilityTask ?? []
        ordersReport = await ordersTask ?? []

        isLoading = false
    }

    private func reloadIfAuthorized() async {
        guard hasUnlockedReports else {
            dashboard = nil
            topProducts = []
            paymentsSummary = []
            zatcaReport = nil
            dailyReport = nil
            monthlyReport = nil
            profitabilityRows = []
            ordersReport = []
            errorMessage = nil
            return
        }
        await loadData()
    }

    private func exportCurrentReports() {
        guard dashboard != nil else { return }
        do {
            let summaryURL = try writeTempFile(named: L10n.shared.reportSummaryFile, contents: reportSummaryText())
            let metricsURL = try writeTempFile(named: L10n.shared.reportMetricsFile, contents: metricsCSV())
            let paymentsURL = try writeTempFile(named: L10n.shared.reportPaymentsFile, contents: paymentsCSV())
            let productsURL = try writeTempFile(named: L10n.shared.reportProductsFile, contents: topProductsCSV())
            let zatcaURL = try writeTempFile(named: L10n.shared.reportZATCAFile, contents: zatcaCSV())
            let trendURL = try writeTempFile(named: L10n.shared.reportTrendFile, contents: trendsCSV())
            let orderTypesURL = try writeTempFile(named: L10n.shared.reportOrderTypesFile, contents: orderTypesCSV())
            shareItems = [summaryURL, metricsURL, paymentsURL, productsURL, zatcaURL, trendURL, orderTypesURL]
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func writeTempFile(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try contents.data(using: .utf8)?.write(to: url) ?? Data().write(to: url)
        return url
    }

    private func reportSummaryText() -> String {
        let dash = dashboard
        let lines: [String] = [
            isArabic ? "تقرير المبيعات" : "Sales Report",
            "Range: \(selectedRange)",
            "",
            "Revenue: \((dash?.totalRevenue ?? 0).sarFormatted)",
            "Orders: \(dash?.totalOrders ?? 0)",
            "Avg Order Value: \((dash?.avgOrderValue ?? 0).sarFormatted)",
            "VAT: \((dash?.totalVat ?? 0).sarFormatted)",
            "Discounts: \((dash?.totalDiscounts ?? 0).sarFormatted)",
            "",
            "Payments:",
        ]
        let paymentLines = paymentsSummary.sorted { $0.total > $1.total }.map {
            "- \(paymentMethodName($0.method)): \($0.total.sarFormatted) | VAT \($0.vat.sarFormatted) | \($0.count)"
        }
        let zatcaLines: [String]
        if let zatcaReport {
            zatcaLines = [
                "",
                "ZATCA:",
                "Invoices: \(zatcaReport.totalInvoices)",
                "VAT Collected: \(zatcaReport.totalVatCollected.sarFormatted)",
            ] + zatcaReport.byStatus.keys.sorted().map { "- \(statusTitle($0)): \(zatcaReport.byStatus[$0] ?? 0)" }
        } else {
            zatcaLines = []
        }
        let productLines: [String]
        if topProducts.isEmpty {
            productLines = []
        } else {
            productLines = ["", "Top Products:"] + topProducts.prefix(10).map {
                "- \(isArabic ? $0.nameAr : $0.nameEn): qty \($0.totalQty), revenue \($0.totalRevenue.sarFormatted)"
            }
        }
        return (lines + paymentLines + zatcaLines + productLines).joined(separator: "\n")
    }

    private func metricsCSV() -> String {
        var rows = ["metric,value"]
        if let dashboard {
            rows.append("total_revenue,\(dashboard.totalRevenue)")
            rows.append("total_orders,\(dashboard.totalOrders)")
            rows.append("avg_order_value,\(dashboard.avgOrderValue)")
            rows.append("total_vat,\(dashboard.totalVat)")
            rows.append("total_discounts,\(dashboard.totalDiscounts)")
            rows.append("revenue_today,\(dashboard.revenueToday)")
            rows.append("orders_today,\(dashboard.ordersToday)")
            rows.append("avg_order_time_min,\(dashboard.avgOrderTimeMin)")
        }
        return rows.joined(separator: "\n")
    }

    private func paymentsCSV() -> String {
        var rows = ["method,total,vat,count"]
        for row in paymentsSummary {
            rows.append("\(csvEscape(paymentMethodName(row.method))),\(row.total),\(row.vat),\(row.count)")
        }
        return rows.joined(separator: "\n")
    }

    private func zatcaCSV() -> String {
        var rows = ["section,name,value"]
        if let zatcaReport {
            rows.append("summary,total_invoices,\(zatcaReport.totalInvoices)")
            rows.append("summary,total_vat_collected,\(zatcaReport.totalVatCollected)")
            for status in zatcaReport.byStatus.keys.sorted() {
                rows.append("status,\(csvEscape(statusTitle(status))),\(zatcaReport.byStatus[status] ?? 0)")
            }
        }
        return rows.joined(separator: "\n")
    }

    private func topProductsCSV() -> String {
        var rows = ["product,quantity,revenue"]
        for product in topProducts.prefix(10) {
            rows.append("\(csvEscape(isArabic ? product.nameAr : product.nameEn)),\(product.totalQty),\(product.totalRevenue)")
        }
        return rows.joined(separator: "\n")
    }

    private func trendsCSV() -> String {
        var rows = ["hour,revenue,orders"]
        for entry in dashboard?.hourlyTrend ?? [] {
            rows.append("\(csvEscape(entry.hour)),\(entry.revenue),\(entry.orders)")
        }
        return rows.joined(separator: "\n")
    }

    private func orderTypesCSV() -> String {
        var rows = ["order_type,revenue"]
        for (type, revenue) in (dashboard?.revenueByOrderType ?? [:]).sorted(by: { $0.key < $1.key }) {
            rows.append("\(csvEscape(type)),\(revenue)")
        }
        return rows.joined(separator: "\n")
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func paymentMethodName(_ method: String) -> String {
        switch method.uppercased() {
        case "CASH": return isArabic ? "نقدي" : "Cash"
        case "CARD": return isArabic ? "بطاقة" : "Card"
        case "APPLE_PAY": return isArabic ? "آبل باي" : "Apple Pay"
        case "MADA": return isArabic ? "مدى" : "Mada"
        default: return method.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func orderCountLabel(_ count: Int) -> String {
        isArabic ? "\(count) طلب" : "\(count) orders"
    }

    private func statusTitle(_ status: String) -> String {
        switch status.lowercased() {
        case "reported": return isArabic ? "مبلغ" : "Reported"
        case "cleared": return isArabic ? "معتمد" : "Cleared"
        case "pending": return isArabic ? "قيد الانتظار" : "Pending"
        case "failed": return isArabic ? "فشل" : "Failed"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "reported", "cleared": return AppTheme.success
        case "pending": return AppTheme.warning
        case "failed": return AppTheme.danger
        default: return AppTheme.info
        }
    }

    private func metricTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.caption(11))
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.headline(14))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(AppTheme.r12)
    }
}

struct ReportsUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundColor(AppTheme.textMuted)
            Text("Reports require iOS 16 or newer")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textPrimary)
            Text("Basic POS screens remain available on iOS 15.")
                .font(AppTheme.body(14))
                .foregroundColor(AppTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.bg)
    }
}

struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
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
