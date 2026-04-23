// KDSView.swift — Kitchen Display System
import SwiftUI
import Combine

struct KDSView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    private let api = APIService.shared
    private let l10n = L10n.shared
    @StateObject private var realtime = KDSRealtimeService()

    @State private var orders: [Order] = []
    @State private var stations: [KitchenStation] = []
    @State private var selectedStationId: String?
    @State private var isLoading = false
    @State private var showStationSettings = false
    @State private var loadError: String?

    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    private let kdsChangedNotification = Notification.Name("kdsOrdersDidChange")

    var body: some View {
        VStack(spacing: 0) {
            header
            if let diagnosticBannerText {
                realtimeDiagnosticBanner(text: diagnosticBannerText)
            }
            stationPicker

            if isLoading && orders.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if orders.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: loadError == nil ? "tray" : "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(loadError == nil ? AppTheme.textMuted : AppTheme.warning)
                    Text(loadError ?? l10n.noKDSOrders)
                        .font(AppTheme.body(15))
                        .foregroundColor(loadError == nil ? AppTheme.textMuted : AppTheme.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button { Task { await loadAll() } } label: {
                        Text(l10n.retry).font(AppTheme.caption(13))
                    }
                }
                Spacer()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(orders) { order in
                            kdsCard(order)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task {
            await loadAll()
            realtime.connect(branchId: appState.currentUser?.branchId, accessToken: api.accessToken)
        }
        .onReceive(refreshTimer) { _ in
            guard !realtime.isConnected else { return }
            Task { await loadOrders() }
        }
        .onReceive(NotificationCenter.default.publisher(for: kdsChangedNotification)) { _ in
            Task { await loadOrders() }
        }
        .onChange(of: appState.currentUser?.branchId) { _ in
            realtime.connect(branchId: appState.currentUser?.branchId, accessToken: api.accessToken)
            selectedStationId = nil
            Task { await loadAll() }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                realtime.connect(branchId: appState.currentUser?.branchId, accessToken: api.accessToken)
            default:
                realtime.disconnect()
            }
        }
        .onDisappear {
            realtime.disconnect()
        }
        .sheet(isPresented: $showStationSettings) {
            KitchenStationsSheet(
                stations: $stations,
                branchId: appState.currentUser?.branchId
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.kds).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.kdsSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            Text(connectionBadgeLabel)
                .font(AppTheme.caption(11))
                .foregroundColor(connectionBadgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(connectionBadgeColor.opacity(0.12))
                .cornerRadius(999)
            Button { showStationSettings = true } label: {
                Label(l10n.stations, systemImage: "gearshape.2.fill")
                    .font(AppTheme.caption(13)).foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(AppTheme.surface).cornerRadius(AppTheme.r12)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    private var stationPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedStationId = nil
                    Task { await loadOrders() }
                } label: {
                    Text(l10n.allStations)
                        .font(AppTheme.caption(12))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(selectedStationId == nil ? AppTheme.accent : AppTheme.surface)
                        .foregroundColor(selectedStationId == nil ? .white : AppTheme.textPrimary)
                        .cornerRadius(999)
                }
                ForEach(stations) { station in
                    Button {
                        selectedStationId = station.id
                        Task { await loadOrders() }
                    } label: {
                        Text(l10n.isArabic ? station.nameAr : station.nameEn)
                            .font(AppTheme.caption(12))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(selectedStationId == station.id ? AppTheme.accent : AppTheme.surface)
                            .foregroundColor(selectedStationId == station.id ? .white : AppTheme.textPrimary)
                            .cornerRadius(999)
                    }
                }
            }.padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    private var connectionBadgeLabel: String {
        if realtime.isConnected {
            return l10n.live
        }
        if realtime.isConnecting && realtime.retryAttempt > 0 {
            return l10n.retrying
        }
        if realtime.isConnecting {
            return l10n.connecting
        }
        return l10n.pollingFallback
    }

    private var connectionBadgeColor: Color {
        if realtime.isConnected {
            return AppTheme.success
        }
        if realtime.isConnecting {
            return AppTheme.info
        }
        return AppTheme.warning
    }

    private var diagnosticBannerText: String? {
        if realtime.isConnected {
            return nil
        }
        if realtime.isConnecting && realtime.retryAttempt > 0 {
            return l10n.kdsRetryingRealtime(realtime.retryAttempt, realtime.maxRetryCount)
        }
        if realtime.fallbackStatusCode == 404 {
            return l10n.kdsRealtimeEndpointUnavailable
        }
        if let status = realtime.fallbackStatusCode {
            return l10n.kdsRealtimeUpgradeRejected(status)
        }
        if realtime.hasFallbackDiagnostic {
            return l10n.kdsRealtimePollingFallback
        }
        return nil
    }

    private func realtimeDiagnosticBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: realtime.isConnecting ? "arrow.clockwise" : "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(AppTheme.caption(12))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background((realtime.isConnecting ? AppTheme.info : AppTheme.warning).opacity(0.12))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill((realtime.isConnecting ? AppTheme.info : AppTheme.warning).opacity(0.2))
                .frame(height: 1)
        }
    }

    private func kdsCard(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(order.orderNumber ?? String(order.id.prefix(6)))")
                    .font(AppTheme.body(16)).foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(order.status.capitalized)
                    .font(AppTheme.caption(11)).foregroundColor(statusColor(order.status))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(statusColor(order.status).opacity(0.15)).cornerRadius(6)
            }

            Text(order.orderType.uppercased())
                .font(AppTheme.caption(10)).foregroundColor(AppTheme.info)

            Divider()

            if let items = order.items {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    HStack {
                        Text("\(item.quantity)x")
                            .font(AppTheme.caption(13)).foregroundColor(AppTheme.accent)
                        Text(l10n.isArabic ? (item.productNameAr ?? "-") : (item.productNameEn ?? "-"))
                            .font(AppTheme.body(13)).foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if order.status == "received" || order.status == "preparing" {
                    Button {
                        Task { await bumpOrder(order) }
                    } label: {
                        Text(order.status == "received" ? l10n.startPreparing : l10n.markReady)
                            .font(AppTheme.caption(12)).foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(order.status == "received" ? AppTheme.info : AppTheme.success)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
        .background(AppTheme.card).cornerRadius(AppTheme.r16)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r16).strokeBorder(statusColor(order.status).opacity(0.3), lineWidth: 1))
        .shadow(color: AppTheme.shadow, radius: 8, y: 4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "received": return AppTheme.info
        case "preparing": return AppTheme.warning
        case "ready": return AppTheme.success
        default: return AppTheme.textMuted
        }
    }

    private func loadAll() async {
        isLoading = true
        loadError = nil
        do {
            stations = try await api.fetchKitchenStations(branchId: appState.currentUser?.branchId)
        } catch {
            // Stations are optional; don't block KDS if endpoint missing
            stations = []
        }
        await loadOrders()
        isLoading = false
    }

    private func loadOrders() async {
        do {
            orders = try await api.fetchKDSOrders(stationId: selectedStationId)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func bumpOrder(_ order: Order) async {
        let nextStatus = order.status == "received" ? "preparing" : "ready"
        do {
            try await api.bumpKDSOrder(order.id, body: BumpOrder(status: nextStatus))
        } catch {
            loadError = error.localizedDescription
        }
        await loadOrders()
    }
}

// MARK: - Kitchen Stations Sheet
struct KitchenStationsSheet: View {
    @Binding var stations: [KitchenStation]
    let branchId: String?
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        CompatNavigationContainer {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                if isLoading && stations.isEmpty {
                    ProgressView()
                } else if stations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: loadError == nil ? "fork.knife.circle" : "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(loadError == nil ? AppTheme.textMuted : AppTheme.warning)
                        Text(loadError ?? l10n.noData)
                            .font(AppTheme.body(15))
                            .foregroundColor(loadError == nil ? AppTheme.textMuted : AppTheme.warning)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button {
                            Task { await refreshStations() }
                        } label: {
                            Text(l10n.retry)
                                .font(AppTheme.headline(13))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(stations) { station in
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(l10n.isArabic ? station.nameAr : station.nameEn)
                                            .font(AppTheme.body(15))
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text("\(station.categoryIds?.count ?? 0) \(l10n.categories)")
                                            .font(AppTheme.caption(12))
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                    Spacer()
                                    Circle()
                                        .fill(station.isActive == true ? AppTheme.success : AppTheme.textMuted)
                                        .frame(width: 10, height: 10)
                                }
                                .padding(14)
                                .background(AppTheme.card)
                                .cornerRadius(AppTheme.r12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.r12)
                                        .strokeBorder(AppTheme.border, lineWidth: 1)
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await deleteStation(station.id) }
                                    } label: {
                                        Label(l10n.delete, systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(l10n.kitchenStations)
            .navigationBarTitleDisplayMode(.inline)
            .compatSheetNavigationChrome()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.done) { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshStations() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if stations.isEmpty {
                await refreshStations()
            }
        }
    }

    private func refreshStations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await api.fetchKitchenStations(branchId: branchId)
            loadError = nil
        } catch {
            stations = []
            loadError = error.localizedDescription
        }
    }

    private func deleteStation(_ stationId: String) async {
        do {
            try await api.deleteKitchenStation(stationId)
            stations.removeAll { $0.id == stationId }
            if stations.isEmpty {
                await refreshStations()
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
