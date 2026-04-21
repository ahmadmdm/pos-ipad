// TablesView.swift — Restaurant table management and floor map
import SwiftUI

struct TablesView: View {
    @EnvironmentObject var posVM: POSViewModel
    @EnvironmentObject var appState: AppState
    @State private var tables: [RestaurantTable] = []
    @State private var isLoading = false
    @State private var viewMode: ViewMode = .grid
    @State private var showAddTable = false
    @State private var editingTable: RestaurantTable?
    @State private var qrPreviewImage: UIImage?
    @State private var showQRPreview = false
    @State private var isPerformingAction = false

    enum ViewMode { case grid, map }

    private let api = APIService.shared

    private var availableCount: Int { tables.filter { !$0.isOccupied }.count }
    private var occupiedCount: Int { tables.filter { $0.isOccupied }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            tablesHeader
            // Stats bar
            statsBar
            viewModePicker
            // Content
            if isLoading {
                loadingState
            } else if tables.isEmpty {
                emptyState
            } else {
                if viewMode == .grid {
                    tableGrid
                } else {
                    floorMap
                }
            }
        }
        .background(AppTheme.bg)
        .sheet(isPresented: $showAddTable) {
            TableFormSheet { payload in
                Task { await addTable(payload) }
            }
        }
        .sheet(item: $editingTable) { table in
            TableFormSheet(table: table) { payload in
                Task { await updateTable(table.id, payload) }
            }
        }
        .sheet(isPresented: $showQRPreview) {
            if let qrPreviewImage {
                TableQRPreviewSheet(image: qrPreviewImage)
            }
        }
        .task { await loadTables() }
    }

    // MARK: Header
    private var tablesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dining Room")
                    .font(AppTheme.caption(11))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Text("Tables")
                    .font(AppTheme.title2())
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(tables.count) total tables")
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
            Spacer()
            HStack(spacing: 8) {
                Picker("", selection: $viewMode) {
                    Text("Grid").tag(ViewMode.grid)
                    Text("Map").tag(ViewMode.map)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Button {
                    Task { await loadTables() }
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
                }
                if appState.currentUser?.isManager ?? false {
                    Button { showAddTable = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.accentGradH)
                            .cornerRadius(10)
                            .shadow(color: AppTheme.accent.opacity(0.2), radius: 12, y: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private var viewModePicker: some View {
        EmptyView()
    }

    // MARK: Stats bar
    private var statsBar: some View {
        HStack(spacing: 12) {
            TableStatCard(label: "Available", count: availableCount,
                          color: AppTheme.success, icon: "checkmark.circle.fill")
            TableStatCard(label: "Occupied", count: occupiedCount,
                          color: AppTheme.danger, icon: "person.fill")
            TableStatCard(label: "Total", count: tables.count,
                          color: AppTheme.accent, icon: "table.furniture.fill")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: Table grid
    private var tableGrid: some View {
        ScrollView(showsIndicators: false) {
            // Group by section
            let sections = groupedBySections()
            ForEach(sections, id: \.0) { section, sectionTables in
                VStack(alignment: .leading, spacing: 12) {
                    if !section.isEmpty {
                        Text(section)
                            .font(AppTheme.headline())
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 24)
                    }
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(sectionTables) { table in
                            TableCard(table: table) {
                                // Tap: assign to current POS order
                                posVM.selectedTable = table
                                appState.selectedTab = .pos
                            }
                            .contextMenu {
                                if appState.currentUser?.isManager ?? false {
                                    Button {
                                        editingTable = table
                                    } label: {
                                        Label(L10n.shared.editTable, systemImage: "pencil")
                                    }
                                    Button {
                                        Task { await ringBell(for: table) }
                                    } label: {
                                        Label(L10n.shared.ringBell, systemImage: "bell.fill")
                                    }
                                    Button {
                                        Task { await showQR(for: table) }
                                    } label: {
                                        Label(L10n.shared.viewQR, systemImage: "qrcode")
                                    }
                                    Button(role: .destructive) {
                                        Task { await deleteTable(table) }
                                    } label: {
                                        Label(L10n.shared.deleteTable, systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 8)
    }

    private var floorMap: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.r16)
                    .fill(AppTheme.card)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                        .strokeBorder(AppTheme.border, lineWidth: 1))

                ForEach(Array(tables.enumerated()), id: \.element.id) { index, table in
                    TableMapNode(table: table)
                        .position(position(for: table, index: index, in: geo.size))
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    guard appState.currentUser?.isManager == true else { return }
                                    Task {
                                        await updateTablePosition(
                                            table.id,
                                            x: max(0, min(value.location.x / max(geo.size.width, 1), 1)),
                                            y: max(0, min(value.location.y / max(geo.size.height, 1), 1))
                                        )
                                    }
                                }
                        )
                        .onTapGesture {
                            posVM.selectedTable = table
                            appState.selectedTab = .pos
                        }
                        .contextMenu {
                            if appState.currentUser?.isManager ?? false {
                                Button {
                                    editingTable = table
                                } label: {
                                    Label(L10n.shared.editTable, systemImage: "pencil")
                                }
                                Button {
                                    Task { await ringBell(for: table) }
                                } label: {
                                    Label(L10n.shared.ringBell, systemImage: "bell.fill")
                                }
                                Button {
                                    Task { await showQR(for: table) }
                                } label: {
                                    Label(L10n.shared.viewQR, systemImage: "qrcode")
                                }
                            }
                        }
                }
            }
            .padding(24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "table.furniture.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)
            Text("No tables configured")
                .font(AppTheme.headline())
                .foregroundColor(AppTheme.textSecondary)
            Text("Add tables in Settings or via the + button")
                .font(AppTheme.body())
                .foregroundColor(AppTheme.textMuted)
            Spacer()
        }
    }

    private var loadingState: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 12)], spacing: 12) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: AppTheme.r16)
                        .fill(AppTheme.card)
                        .frame(height: 130)
                        .shimmer()
                }
            }
            .padding(24)
        }
    }

    // MARK: Helpers
    private func groupedBySections() -> [(String, [RestaurantTable])] {
        var dict: [String: [RestaurantTable]] = [:]
        for table in tables {
            let sec = table.section ?? ""
            dict[sec, default: []].append(table)
        }
        return dict.sorted { $0.key < $1.key }
    }

    private func loadTables() async {
        isLoading = true
        do { tables = try await api.fetchTables() } catch {}
        isLoading = false
    }

    private func addTable(_ payload: TableCreate) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            _ = try await api.createTable(payload)
            await loadTables()
            showAddTable = false
            appState.showSuccess("Table created")
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func updateTable(_ id: String, _ payload: TableCreate) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            _ = try await api.updateTable(id, body: TableUpdate(
                number: payload.number,
                nameAr: payload.nameAr,
                nameEn: payload.nameEn,
                capacity: payload.capacity,
                section: payload.section
            ))
            await loadTables()
            editingTable = nil
            appState.showSuccess(L10n.shared.tableUpdated)
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func deleteTable(_ table: RestaurantTable) async {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        do {
            try await api.deleteTable(table.id)
            tables.removeAll { $0.id == table.id }
            appState.showSuccess(L10n.shared.tableDeleted)
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func ringBell(for table: RestaurantTable) async {
        do {
            try await api.ringTableBell(table.id)
            appState.showSuccess("\(L10n.shared.bellRung) \(table.displayLabel)")
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func showQR(for table: RestaurantTable) async {
        do {
            let data = try await api.generateTableQR(table.id)
            qrPreviewImage = UIImage(data: data)
            showQRPreview = qrPreviewImage != nil
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func updateTablePosition(_ id: String, x: Double, y: Double) async {
        do {
            try await api.updateTablePosition(id, body: TablePositionUpdate(posX: x, posY: y))
            if let idx = tables.firstIndex(where: { $0.id == id }) {
                let table = tables[idx]
                tables[idx] = RestaurantTable(
                    id: table.id,
                    number: table.number,
                    nameAr: table.nameAr,
                    nameEn: table.nameEn,
                    capacity: table.capacity,
                    section: table.section,
                    posX: x,
                    posY: y,
                    status: table.status,
                    currentOrderId: table.currentOrderId
                )
            }
        } catch {
            appState.showError(error.localizedDescription)
        }
    }

    private func position(for table: RestaurantTable, index: Int, in size: CGSize) -> CGPoint {
        let fallbackX = 0.18 + (Double(index % 4) * 0.2)
        let fallbackY = 0.18 + (Double(index / 4) * 0.22)
        let x = (table.posX ?? fallbackX) * size.width
        let y = (table.posY ?? fallbackY) * size.height
        return CGPoint(x: min(max(44, x), size.width - 44), y: min(max(44, y), size.height - 44))
    }
}

// MARK: - Table Card
struct TableCard: View {
    let table: RestaurantTable
    let onTap: () -> Void
    @State private var isPressed = false

    private var statusColor: Color {
        table.isOccupied ? AppTheme.danger : AppTheme.success
    }

    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isPressed = false }
            onTap()
        }) {
            VStack(spacing: 10) {
                // Table icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 54, height: 54)
                    Image(systemName: "table.furniture.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(statusColor)
                }

                Text("#\(table.number)")
                    .font(AppTheme.title2(20))
                    .foregroundColor(AppTheme.textPrimary)

                if let section = table.section {
                    Text(section)
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }

                HStack(spacing: 4) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(table.isOccupied ? "Occupied" : "Available")
                        .font(AppTheme.caption(11))
                        .foregroundColor(statusColor)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                    Text("\(table.capacity)")
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.card, statusColor.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .cornerRadius(AppTheme.r16)
            .overlay(RoundedRectangle(cornerRadius: AppTheme.r16)
                .strokeBorder(table.isOccupied ? AppTheme.danger.opacity(0.3) : AppTheme.border, lineWidth: 1))
            .shadow(color: statusColor.opacity(0.14), radius: 16, y: 8)
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Table Stat Card
struct TableStatCard: View {
    let label: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(AppTheme.title2(22))
                    .foregroundColor(AppTheme.textPrimary)
                Text(label)
                    .font(AppTheme.caption())
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
            .strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.7), radius: 14, y: 6)
    }
}

struct TableMapNode: View {
    let table: RestaurantTable

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "table.furniture.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(table.isOccupied ? AppTheme.danger : AppTheme.success)
            Text(table.displayLabel)
                .font(AppTheme.caption(12))
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(width: 78, height: 62)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.r12)
            .strokeBorder(table.isOccupied ? AppTheme.danger.opacity(0.25) : AppTheme.border, lineWidth: 1))
        .shadow(color: AppTheme.shadow.opacity(0.5), radius: 10, y: 4)
    }
}

struct TableFormSheet: View {
    let table: RestaurantTable?
    let onSave: (TableCreate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var number = ""
    @State private var nameAr = ""
    @State private var nameEn = ""
    @State private var section = ""
    @State private var capacity = "4"

    init(table: RestaurantTable? = nil, onSave: @escaping (TableCreate) -> Void) {
        self.table = table
        self.onSave = onSave
    }

    var body: some View {
        SheetContainer(title: table == nil ? L10n.shared.addTable : L10n.shared.editTable) {
            VStack(spacing: 16) {
                ThemeTextField(icon: "number", placeholder: L10n.shared.tableNumber, text: $number)
                ThemeTextField(icon: "textformat", placeholder: L10n.shared.nameAr, text: $nameAr)
                ThemeTextField(icon: "textformat", placeholder: L10n.shared.nameEn, text: $nameEn)
                ThemeTextField(icon: "rectangle.split.3x1.fill", placeholder: L10n.shared.section, text: $section)
                ThemeTextField(icon: "person.2.fill", placeholder: L10n.shared.capacity, text: $capacity, keyboardType: .numberPad)

                Button {
                    onSave(TableCreate(
                        number: number,
                        nameAr: nameAr.isEmpty ? nil : nameAr,
                        nameEn: nameEn.isEmpty ? nil : nameEn,
                        capacity: Int(capacity) ?? 4,
                        section: section.isEmpty ? nil : section,
                        posX: table?.posX,
                        posY: table?.posY
                    ))
                    dismiss()
                } label: {
                    Text(L10n.shared.save)
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                .disabled(number.isEmpty)
            }
            .padding(24)
            .onAppear {
                guard let table else { return }
                number = table.number
                nameAr = table.nameAr ?? ""
                nameEn = table.nameEn ?? ""
                section = table.section ?? ""
                capacity = String(table.capacity)
            }
        }
    }
}

struct TableQRPreviewSheet: View {
    let image: UIImage

    var body: some View {
        CompatNavigationContainer {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .background(.white)
                    .cornerRadius(AppTheme.r16)
                Spacer()
            }
            .padding(24)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle(L10n.shared.viewQR)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
