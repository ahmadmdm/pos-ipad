// CouponsView.swift — Coupons CRUD Management
import SwiftUI

struct CouponsView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var coupons: [Coupon] = []
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var editingCoupon: Coupon?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.coupons).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                    Text(l10n.couponsSubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
                }
                Spacer()
                Button { showAdd = true } label: {
                    Label(l10n.addCoupon, systemImage: "plus.circle.fill")
                        .font(AppTheme.caption(13)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
                }
            }
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

            if isLoading {
                Spacer(); ProgressView(); Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(coupons) { coupon in
                            couponRow(coupon)
                        }
                    }.padding(20)
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task { await load() }
        .sheet(isPresented: $showAdd) { CouponFormSheet(coupon: nil, onSave: { await load() }) }
        .sheet(item: $editingCoupon) { c in CouponFormSheet(coupon: c, onSave: { await load() }) }
    }

    private func couponRow(_ coupon: Coupon) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(coupon.code).font(AppTheme.body(16)).foregroundColor(AppTheme.textPrimary)
                    if coupon.isActive == true {
                        Text(l10n.active).font(AppTheme.caption(10)).foregroundColor(AppTheme.success)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.success.opacity(0.15)).cornerRadius(4)
                    } else {
                        Text(l10n.inactive).font(AppTheme.caption(10)).foregroundColor(AppTheme.textMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppTheme.surface).cornerRadius(4)
                    }
                }
                HStack(spacing: 12) {
                    Text("\(l10n.value): \(String(format: "%.2f", coupon.value))")
                        .font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                    if let used = coupon.usedCount, let max = coupon.maxUses {
                        Text("\(l10n.usage): \(used)/\(max)")
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.textMuted)
                    }
                    if let until = coupon.validUntil {
                        Text("\(l10n.expires): \(until)")
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.warning)
                    }
                }
            }
            Spacer()
            Button { editingCoupon = coupon } label: {
                Image(systemName: "pencil.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.accent)
            }
            Button { Task { await delete(coupon.id) } } label: {
                Image(systemName: "trash.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.danger)
            }
        }
        .padding(14)
        .background(AppTheme.card).cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
    }

    private func load() async {
        isLoading = true
        coupons = (try? await api.fetchCoupons()) ?? []
        isLoading = false
    }

    private func delete(_ id: String) async {
        try? await api.deleteCoupon(id)
        await load()
    }
}

// MARK: - Coupon Form
struct CouponFormSheet: View {
    let coupon: Coupon?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var code = ""
    @State private var value = ""
    @State private var description = ""
    @State private var minOrderValue = ""
    @State private var maxDiscountAmount = ""
    @State private var maxUses = ""
    @State private var validFrom = ""
    @State private var validUntil = ""
    @State private var isActive = true
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    TextField(l10n.couponCode, text: $code).autocapitalization(.allCharacters)
                    TextField(l10n.value, text: $value).keyboardType(.decimalPad)
                    TextField(l10n.description, text: $description)
                }
                Section(l10n.limits) {
                    TextField(l10n.minOrderValue, text: $minOrderValue).keyboardType(.decimalPad)
                    TextField(l10n.maxDiscountAmount, text: $maxDiscountAmount).keyboardType(.decimalPad)
                    TextField(l10n.maxUses, text: $maxUses).keyboardType(.numberPad)
                }
                Section(l10n.validity) {
                    TextField(l10n.validFrom, text: $validFrom)
                    TextField(l10n.validUntil, text: $validUntil)
                    if coupon != nil { Toggle(l10n.active, isOn: $isActive) }
                }
            }
            .navigationTitle(coupon == nil ? l10n.addCoupon : l10n.editCoupon)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }.disabled(saving || code.isEmpty)
                }
            }
            .onAppear {
                if let c = coupon {
                    code = c.code; value = "\(c.value)"
                    description = c.description ?? ""
                    minOrderValue = c.minOrderValue.map { "\($0)" } ?? ""
                    maxDiscountAmount = c.maxDiscountAmount.map { "\($0)" } ?? ""
                    maxUses = c.maxUses.map { "\($0)" } ?? ""
                    validFrom = c.validFrom ?? ""; validUntil = c.validUntil ?? ""
                    isActive = c.isActive ?? true
                }
            }
        }
    }

    private func save() async {
        saving = true
        if let c = coupon {
            let body = CouponUpdate(
                description: description.isEmpty ? nil : description,
                isActive: isActive,
                minOrderValue: Double(minOrderValue),
                maxDiscountAmount: Double(maxDiscountAmount),
                maxUses: Int(maxUses),
                validFrom: validFrom.isEmpty ? nil : validFrom,
                validUntil: validUntil.isEmpty ? nil : validUntil,
                value: Double(value)
            )
            _ = try? await api.updateCoupon(c.id, body: body)
        } else {
            let body = CouponCreate(
                code: code, value: Double(value) ?? 0,
                description: description.isEmpty ? nil : description,
                minOrderValue: Double(minOrderValue) ?? 0,
                maxDiscountAmount: Double(maxDiscountAmount),
                maxUses: Int(maxUses),
                validFrom: validFrom.isEmpty ? nil : validFrom,
                validUntil: validUntil.isEmpty ? nil : validUntil
            )
            _ = try? await api.createCoupon(body)
        }
        await onSave()
        saving = false
        dismiss()
    }
}
