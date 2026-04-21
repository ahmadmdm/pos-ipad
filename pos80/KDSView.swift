// KDSView.swift — Kitchen Display System
import SwiftUI
import Combine

struct KDSView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var orders: [Order] = []
    @State private var stations: [KitchenStation] = []
    @State private var selectedStationId: String?
    @State private var isLoading = false
    @State private var showStationSettings = false

    private let refreshTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            stationPicker

            if isLoading && orders.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if orders.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundColor(AppTheme.textMuted)
                    Text(l10n.noKDSOrders).font(AppTheme.body(15)).foregroundColor(AppTheme.textMuted)
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
        .task { await loadAll() }
        .onReceive(refreshTimer) { _ in Task { await loadOrders() } }
        .sheet(isPresented: $showStationSettings) { KitchenStationsSheet(stations: $stations) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.kds).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.kdsSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
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
        stations = (try? await api.fetchKitchenStations()) ?? []
        await loadOrders()
        isLoading = false
    }

    private func loadOrders() async {
        orders = (try? await api.fetchKDSOrders(stationId: selectedStationId)) ?? []
    }

    private func bumpOrder(_ order: Order) async {
        let nextStatus = order.status == "received" ? "preparing" : "ready"
        try? await api.bumpKDSOrder(order.id, body: BumpOrder(status: nextStatus))
        await loadOrders()
    }
}

// MARK: - Kitchen Stations Sheet
struct KitchenStationsSheet: View {
    @Binding var stations: [KitchenStation]
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(stations) { station in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.isArabic ? station.nameAr : station.nameEn)
                                .font(AppTheme.body(15))
                            Text("\(station.categoryIds?.count ?? 0) \(l10n.categories)")
                                .font(AppTheme.caption(12)).foregroundColor(AppTheme.textMuted)
                        }
                        Spacer()
                        if station.isActive == true {
                            Circle().fill(AppTheme.success).frame(width: 8, height: 8)
                        } else {
                            Circle().fill(AppTheme.textMuted).frame(width: 8, height: 8)
                        }
                    }
                }
                .onDelete { indexSet in
                    Task {
                        for i in indexSet {
                            try? await api.deleteKitchenStation(stations[i].id)
                        }
                        stations = (try? await api.fetchKitchenStations()) ?? []
                    }
                }
            }
            .navigationTitle(l10n.kitchenStations)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.done) { dismiss() } }
            }
        }
    }
}
