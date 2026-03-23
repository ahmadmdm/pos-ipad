// TablesView.swift — Restaurant table management and floor map
import SwiftUI

struct TablesView: View {
    @Environment(POSViewModel.self) var posVM
    @Environment(AppState.self) var appState
    @State private var tables: [RestaurantTable] = []
    @State private var isLoading = false
    @State private var viewMode: ViewMode = .grid
    @State private var showAddTable = false

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
            // Content
            if isLoading {
                loadingState
            } else if tables.isEmpty {
                emptyState
            } else {
                tableGrid
            }
        }
        .background(AppTheme.bg)
        .sheet(isPresented: $showAddTable) { addTableSheet }
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
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.top, 8)
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

    // MARK: Add Table Sheet
    @State private var newTableNumber = ""
    @State private var newTableSection = ""
    @State private var newTableCapacity = "4"

    private var addTableSheet: some View {
        SheetContainer(title: "Add Table") {
            VStack(spacing: 16) {
                ThemeTextField(icon: "number", placeholder: "Table number (e.g. 1, A1)",
                               text: $newTableNumber)
                ThemeTextField(icon: "rectangle.split.3x1.fill", placeholder: "Section (optional)",
                               text: $newTableSection)
                ThemeTextField(icon: "person.2.fill", placeholder: "Capacity",
                               text: $newTableCapacity, keyboardType: .numberPad)

                Button {
                    Task { await addTable() }
                } label: {
                    Text("Add Table")
                }
                .buttonStyle(PrimaryButtonStyle(isFullWidth: true))
                .disabled(newTableNumber.isEmpty)
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

    private func addTable() async {
        struct TableCreate: Codable {
            let number: String
            let section: String?
            let capacity: Int
        }
        do {
            let _: RestaurantTable = try await api.request(
                path: "/tables",
                method: .post,
                body: TableCreate(number: newTableNumber,
                                  section: newTableSection.isEmpty ? nil : newTableSection,
                                  capacity: Int(newTableCapacity) ?? 4))
            await loadTables()
            showAddTable = false
            newTableNumber = ""
            newTableSection = ""
        } catch {}
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
