// DeliveryView.swift — Delivery Partners & Orders
import SwiftUI

struct DeliveryView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    enum Tab: String, CaseIterable { case orders, partners }
    @State private var tab: Tab = .orders

    @State private var deliveryOrders: [DeliveryOrder] = []
    @State private var partners: [DeliveryPartner] = []
    @State private var isLoading = false
    @State private var showAddPartner = false
    @State private var editingPartner: DeliveryPartner?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.delivery).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                    Text(l10n.deliverySubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                if tab == .partners {
                    Button { showAddPartner = true } label: {
                        Label(l10n.addPartner, systemImage: "plus.circle.fill")
                            .font(AppTheme.caption(13)).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

            Picker("", selection: $tab) {
                Text(l10n.deliveryOrders).tag(Tab.orders)
                Text(l10n.deliveryPartners).tag(Tab.partners)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20).padding(.bottom, 10)

            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else {
                switch tab {
                case .orders: ordersTab
                case .partners: partnersTab
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task { await loadAll() }
        .sheet(isPresented: $showAddPartner) { DeliveryPartnerFormSheet(partner: nil, onSave: { await loadPartners() }) }
        .sheet(item: $editingPartner) { p in DeliveryPartnerFormSheet(partner: p, onSave: { await loadPartners() }) }
    }

    private var ordersTab: some View {
        Group {
            if deliveryOrders.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bicycle").font(.system(size: 40)).foregroundColor(AppTheme.textMuted)
                    Text(l10n.noDeliveryOrders).font(AppTheme.body(15)).foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(deliveryOrders) { order in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(order.orderId ?? "-").font(AppTheme.body(14)).foregroundColor(AppTheme.textPrimary)
                                    if let addr = order.deliveryAddress {
                                        Text(addr).font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary).lineLimit(1)
                                    }
                                    HStack(spacing: 8) {
                                        if let fee = order.deliveryFee {
                                            Text("\(l10n.fee): \(String(format: "%.2f", fee))")
                                                .font(AppTheme.caption(11)).foregroundColor(AppTheme.textMuted)
                                        }
                                        if let status = order.deliveryStatus {
                                            Text(status.capitalized)
                                                .font(AppTheme.caption(10)).foregroundColor(AppTheme.info)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(AppTheme.info.opacity(0.12)).cornerRadius(4)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(AppTheme.card).cornerRadius(AppTheme.r12)
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
                        }
                    }.padding(20)
                }
            }
        }
    }

    private var partnersTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(partners) { partner in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(partner.name).font(AppTheme.body(15)).foregroundColor(AppTheme.textPrimary)
                                Circle()
                                    .fill(partner.isActive == true ? AppTheme.success : AppTheme.textMuted)
                                    .frame(width: 8, height: 8)
                            }
                            HStack(spacing: 12) {
                                if let phone = partner.phone {
                                    Label(phone, systemImage: "phone.fill").font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                                }
                                if let vehicle = partner.vehicleLabel {
                                    Label(vehicle, systemImage: "car.fill").font(AppTheme.caption(12)).foregroundColor(AppTheme.textMuted)
                                }
                            }
                        }
                        Spacer()
                        Button { editingPartner = partner } label: {
                            Image(systemName: "pencil.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.accent)
                        }
                        Button { Task { await deletePartner(partner.id) } } label: {
                            Image(systemName: "trash.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.danger)
                        }
                    }
                    .padding(14)
                    .background(AppTheme.card).cornerRadius(AppTheme.r12)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
                }
            }.padding(20)
        }
    }

    private func loadAll() async {
        isLoading = true
        await loadPartners()
        deliveryOrders = (try? await api.fetchDeliveryOrders()) ?? []
        isLoading = false
    }

    private func loadPartners() async { partners = (try? await api.fetchDeliveryPartners()) ?? [] }
    private func deletePartner(_ id: String) async {
        try? await api.deleteDeliveryPartner(id)
        await loadPartners()
    }
}

// MARK: - Delivery Partner Form
struct DeliveryPartnerFormSheet: View {
    let partner: DeliveryPartner?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var name = ""
    @State private var phone = ""
    @State private var vehicleLabel = ""
    @State private var isActive = true
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    TextField(l10n.name, text: $name)
                    TextField(l10n.phone, text: $phone).keyboardType(.phonePad)
                    TextField(l10n.vehicleLabel, text: $vehicleLabel)
                    if partner != nil { Toggle(l10n.active, isOn: $isActive) }
                }
            }
            .navigationTitle(partner == nil ? l10n.addPartner : l10n.editPartner)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }.disabled(saving || name.isEmpty)
                }
            }
            .onAppear {
                if let p = partner {
                    name = p.name; phone = p.phone ?? ""
                    vehicleLabel = p.vehicleLabel ?? ""; isActive = p.isActive ?? true
                }
            }
        }
    }

    private func save() async {
        saving = true
        if let p = partner {
            let body = DeliveryPartnerUpdate(
                name: name, phone: phone.isEmpty ? nil : phone,
                vehicleLabel: vehicleLabel.isEmpty ? nil : vehicleLabel,
                isActive: isActive
            )
            _ = try? await api.updateDeliveryPartner(p.id, body: body)
        } else {
            let body = DeliveryPartnerCreate(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                vehicleLabel: vehicleLabel.isEmpty ? nil : vehicleLabel
            )
            _ = try? await api.createDeliveryPartner(body)
        }
        await onSave()
        saving = false
        dismiss()
    }
}
