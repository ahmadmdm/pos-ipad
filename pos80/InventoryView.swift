// InventoryView.swift — Raw Materials, Stock, Recipes & Batches
import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var appState: AppState
    private let api = APIService.shared
    private let l10n = L10n.shared

    enum Tab: String, CaseIterable { case materials, batches, recipes }
    @State private var tab: Tab = .materials

    // Materials
    @State private var materials: [RawMaterial] = []
    @State private var showAddMaterial = false
    @State private var editingMaterial: RawMaterial?

    // Batches
    @State private var batches: [InventoryBatch] = []
    @State private var showAddBatch = false

    // Recipes
    @State private var products: [Product] = []
    @State private var selectedProductId: String?
    @State private var recipe: Recipe?

    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Picker("", selection: $tab) {
                Text(l10n.rawMaterials).tag(Tab.materials)
                Text(l10n.batches).tag(Tab.batches)
                Text(l10n.recipes).tag(Tab.recipes)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                switch tab {
                case .materials: materialsTab
                case .batches: batchesTab
                case .recipes: recipesTab
                }
            }
        }
        .background(AppTheme.bgGradient.ignoresSafeArea())
        .task { await loadAll() }
        .sheet(isPresented: $showAddMaterial) { MaterialFormSheet(material: nil, onSave: { await loadMaterials() }) }
        .sheet(item: $editingMaterial) { mat in MaterialFormSheet(material: mat, onSave: { await loadMaterials() }) }
        .sheet(isPresented: $showAddBatch) { BatchFormSheet(materials: materials, onSave: { await loadBatches() }) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.inventory).font(AppTheme.title2(22)).foregroundColor(AppTheme.textPrimary)
                Text(l10n.inventorySubtitle).font(AppTheme.caption(13)).foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            if tab == .materials {
                Button { showAddMaterial = true } label: {
                    Label(l10n.addMaterial, systemImage: "plus.circle.fill")
                        .font(AppTheme.caption(13)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
                }
            } else if tab == .batches {
                Button { showAddBatch = true } label: {
                    Label(l10n.addBatch, systemImage: "plus.circle.fill")
                        .font(AppTheme.caption(13)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(AppTheme.accentGrad).cornerRadius(AppTheme.r12)
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: Materials
    private var materialsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(materials) { mat in
                    materialRow(mat)
                }
            }.padding(20)
        }
    }

    private func materialRow(_ mat: RawMaterial) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(l10n.isArabic ? mat.nameAr : mat.nameEn)
                    .font(AppTheme.body(15)).foregroundColor(AppTheme.textPrimary)
                HStack(spacing: 12) {
                    Text("\(l10n.stock): \(String(format: "%.1f", mat.currentStock ?? 0)) \(mat.unit)")
                        .font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                    if let cost = mat.costPerUnit {
                        Text("\(l10n.cost): \(String(format: "%.2f", cost))")
                            .font(AppTheme.caption(12)).foregroundColor(AppTheme.textMuted)
                    }
                }
            }
            Spacer()
            if let threshold = mat.lowStockThreshold, (mat.currentStock ?? 0) < threshold {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppTheme.warning).font(.system(size: 16))
            }
            Button { editingMaterial = mat } label: {
                Image(systemName: "pencil.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.accent)
            }
            Button { Task { await deleteMaterial(mat.id) } } label: {
                Image(systemName: "trash.circle.fill").font(.system(size: 20)).foregroundColor(AppTheme.danger)
            }
        }
        .padding(14)
        .background(AppTheme.card).cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12).strokeBorder(AppTheme.border, lineWidth: 1))
    }

    // MARK: Batches
    private var batchesTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(batches) { batch in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(batch.materialName ?? batch.rawMaterialId ?? "-")
                                .font(AppTheme.body(15)).foregroundColor(AppTheme.textPrimary)
                            HStack(spacing: 12) {
                                if let bn = batch.batchNumber { Text("#\(bn)").font(AppTheme.caption(12)).foregroundColor(AppTheme.accent) }
                                Text("\(l10n.qty): \(String(format: "%.1f", batch.quantity ?? 0))")
                                    .font(AppTheme.caption(12)).foregroundColor(AppTheme.textSecondary)
                                if let exp = batch.expiryDate {
                                    Text("\(l10n.expiry): \(exp)").font(AppTheme.caption(12)).foregroundColor(AppTheme.warning)
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

    // MARK: Recipes
    private var recipesTab: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(products) { prod in
                        Button {
                            selectedProductId = prod.id
                            Task { await loadRecipe(prod.id) }
                        } label: {
                            Text(l10n.isArabic ? prod.nameAr : prod.nameEn)
                                .font(AppTheme.caption(12))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(selectedProductId == prod.id ? AppTheme.accent : AppTheme.surface)
                                .foregroundColor(selectedProductId == prod.id ? .white : AppTheme.textPrimary)
                                .cornerRadius(999)
                        }
                    }
                }.padding(.horizontal, 20)
            }

            if let recipe = recipe, let ingredients = recipe.ingredients {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(ingredients) { ing in
                            HStack {
                                Text(ing.materialName ?? ing.rawMaterialId ?? "-")
                                    .font(AppTheme.body(14)).foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Text("\(String(format: "%.2f", ing.quantity ?? 0)) \(ing.unit ?? "")")
                                    .font(AppTheme.caption(13)).foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(12)
                            .background(AppTheme.card).cornerRadius(AppTheme.r12)
                        }
                    }.padding(20)
                }
            } else {
                Spacer()
                Text(l10n.selectProduct).font(AppTheme.body(14)).foregroundColor(AppTheme.textMuted)
                Spacer()
            }
        }
    }

    // MARK: Data
    private func loadAll() async {
        isLoading = true
        await loadMaterials()
        await loadBatches()
        products = (try? await api.fetchProducts()) ?? []
        isLoading = false
    }

    private func loadMaterials() async { materials = (try? await api.fetchRawMaterials()) ?? [] }
    private func loadBatches() async { batches = (try? await api.fetchBatches()) ?? [] }
    private func loadRecipe(_ productId: String) async { recipe = try? await api.fetchRecipe(productId: productId) }

    private func deleteMaterial(_ id: String) async {
        try? await api.deleteRawMaterial(id)
        await loadMaterials()
    }
}

// MARK: - Material Form Sheet
struct MaterialFormSheet: View {
    let material: RawMaterial?
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var nameAr = ""
    @State private var nameEn = ""
    @State private var unit = ""
    @State private var stock = ""
    @State private var threshold = ""
    @State private var cost = ""
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    TextField(l10n.nameAr, text: $nameAr)
                    TextField(l10n.nameEn, text: $nameEn)
                    TextField(l10n.unit, text: $unit)
                    TextField(l10n.currentStock, text: $stock).keyboardType(.decimalPad)
                    TextField(l10n.lowStockThreshold, text: $threshold).keyboardType(.decimalPad)
                    TextField(l10n.costPerUnit, text: $cost).keyboardType(.decimalPad)
                }
            }
            .navigationTitle(material == nil ? l10n.addMaterial : l10n.editMaterial)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }.disabled(saving || nameEn.isEmpty)
                }
            }
            .onAppear {
                if let m = material {
                    nameAr = m.nameAr; nameEn = m.nameEn; unit = m.unit
                    stock = "\(m.currentStock ?? 0)"
                    threshold = m.lowStockThreshold.map { "\($0)" } ?? ""
                    cost = m.costPerUnit.map { "\($0)" } ?? ""
                }
            }
        }
    }

    private func save() async {
        saving = true
        let body = RawMaterialCreate(
            nameAr: nameAr, nameEn: nameEn, unit: unit,
            currentStock: Double(stock) ?? 0,
            lowStockThreshold: Double(threshold),
            costPerUnit: Double(cost)
        )
        if let m = material {
            _ = try? await api.updateRawMaterial(m.id, body: body)
        } else {
            _ = try? await api.createRawMaterial(body)
        }
        await onSave()
        saving = false
        dismiss()
    }
}

// MARK: - Batch Form Sheet
struct BatchFormSheet: View {
    let materials: [RawMaterial]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss
    private let api = APIService.shared
    private let l10n = L10n.shared

    @State private var selectedMaterialId = ""
    @State private var quantity = ""
    @State private var cost = ""
    @State private var batchNumber = ""
    @State private var expiryDate = ""
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                Section(l10n.details) {
                    Picker(l10n.rawMaterial, selection: $selectedMaterialId) {
                        Text(l10n.selectMaterial).tag("")
                        ForEach(materials) { mat in
                            Text(l10n.isArabic ? mat.nameAr : mat.nameEn).tag(mat.id)
                        }
                    }
                    TextField(l10n.quantity, text: $quantity).keyboardType(.decimalPad)
                    TextField(l10n.costPerUnit, text: $cost).keyboardType(.decimalPad)
                    TextField(l10n.batchNumber, text: $batchNumber)
                    TextField(l10n.expiryDate, text: $expiryDate)
                }
            }
            .navigationTitle(l10n.addBatch)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(l10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.save) { Task { await save() } }
                        .disabled(saving || selectedMaterialId.isEmpty || quantity.isEmpty)
                }
            }
        }
    }

    private func save() async {
        saving = true
        let body = BatchCreate(
            rawMaterialId: selectedMaterialId,
            quantity: Double(quantity) ?? 0,
            costPerUnit: Double(cost),
            batchNumber: batchNumber.isEmpty ? nil : batchNumber,
            expiryDate: expiryDate.isEmpty ? nil : expiryDate
        )
        _ = try? await api.createBatch(body)
        await onSave()
        saving = false
        dismiss()
    }
}
