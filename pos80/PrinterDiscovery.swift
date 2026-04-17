// PrinterDiscovery.swift — Automatic network printer scanner (ESC/POS port 9100)
import SwiftUI
import Network
import Combine

// MARK: - Discovered Printer

struct DiscoveredPrinter: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    let port: UInt16
}

// MARK: - Printer Discovery Engine

@MainActor
final class PrinterDiscovery: ObservableObject {

    @Published var isScanning    = false
    @Published var discovered:   [DiscoveredPrinter] = []
    @Published var scannedCount  = 0
    let totalCount    = 254

    var progress: Double {
        totalCount > 0 ? Double(scannedCount) / Double(totalCount) : 0
    }

    var localIP: String? { getLocalIPAddress() }

    private var scanTask: Task<Void, Never>?

    // MARK: - Start Scan

    func startScan(port: UInt16 = 9100) {
        guard !isScanning, let ip = localIP else { return }
        let prefix = subnetPrefix(from: ip)

        discovered    = []
        scannedCount  = 0
        isScanning    = true

        scanTask = Task {
            await withTaskGroup(of: DiscoveredPrinter?.self) { group in
                for i in 1...254 {
                    if Task.isCancelled { break }
                    let hostIP = "\(prefix)\(i)"
                    group.addTask { await Self.probe(ip: hostIP, port: port) }
                }
                for await result in group {
                    if Task.isCancelled { break }
                    scannedCount = min(scannedCount + 1, totalCount)
                    if let p = result {
                        discovered.append(p)
                        discovered.sort { Self.ipSortValue($0.ip) < Self.ipSortValue($1.ip) }
                    }
                }
            }
            isScanning   = false
            scannedCount = totalCount
        }
    }

    // MARK: - Stop Scan

    func stopScan() {
        scanTask?.cancel()
        isScanning = false
    }

    // MARK: - TCP Probe (nonisolated — runs off MainActor on background threads)

    nonisolated private static func probe(ip: String, port: UInt16) async -> DiscoveredPrinter? {
        await withCheckedContinuation { continuation in
            // Use a class-based box so the closure captures a reference, not a var,
            // which satisfies Swift 6 Sendable checking.
            final class ResumeOnce: @unchecked Sendable {
                private let lock = NSLock()
                private var done = false
                func tryResume(_ continuation: CheckedContinuation<DiscoveredPrinter?, Never>,
                               result: DiscoveredPrinter?) {
                    lock.lock(); defer { lock.unlock() }
                    guard !done else { return }
                    done = true
                    continuation.resume(returning: result)
                }
            }
            let guard_ = ResumeOnce()
            let conn = NWConnection(host: .init(ip), port: .init(rawValue: port)!, using: .tcp)
            let timer = DispatchWorkItem { conn.cancel() }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard_.tryResume(continuation, result: DiscoveredPrinter(ip: ip, port: port))
                    conn.cancel()
                case .failed, .cancelled:
                    guard_.tryResume(continuation, result: nil)
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.8, execute: timer)
        }
    }

    // MARK: - Helpers

    func subnetPrefix(from ip: String) -> String {
        ip.split(separator: ".").prefix(3).joined(separator: ".") + "."
    }

    nonisolated private static func ipSortValue(_ ip: String) -> Int {
        let p = ip.split(separator: ".").compactMap { Int($0) }
        guard p.count == 4 else { return 0 }
        return (p[0] << 24) | (p[1] << 16) | (p[2] << 8) | p[3]
    }

    private func getLocalIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        var fallback: String?
        while let cur = ptr {
            let ifa = cur.pointee
            if ifa.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: ifa.ifa_name)
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len),
                            &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST)
                let ip = String(cString: buf)
                guard !ip.hasPrefix("127."), name != "lo0" else { ptr = ifa.ifa_next; continue }
                if name == "en0" { return ip }   // WiFi first
                fallback = ip
            }
            ptr = ifa.ifa_next
        }
        return fallback
    }
}

// MARK: - Printer Discovery Sheet

struct PrinterDiscoverySheet: View {
    let onSelectReceipt: (String, UInt16) -> Void
    let onSelectKitchen: (String, UInt16) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var discovery = PrinterDiscovery()

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ────────────────────────────────────────────────────
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "wifi")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }

                if let ip = discovery.localIP {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Device IP: \(ip)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Scanning \(discovery.subnetPrefix(from: ip))1 – 254  •  Port 9100")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No WiFi connection")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.danger)
                        Text("Connect to WiFi to scan for printers")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }

                Spacer()

                // Scan / Stop button
                Button {
                    if discovery.isScanning { discovery.stopScan() }
                    else { discovery.startScan(port: 9100) }
                } label: {
                    HStack(spacing: 6) {
                        if discovery.isScanning {
                            ProgressView().scaleEffect(0.7).tint(.white)
                            Text("Stop")
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Scan Network")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(discovery.isScanning ? AppTheme.danger : AppTheme.accent)
                    .cornerRadius(10)
                }
                .disabled(discovery.localIP == nil)

                Button {
                    discovery.stopScan()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.cardHover)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(AppTheme.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }

            // ── Progress bar ───────────────────────────────────────────────
            if discovery.isScanning || discovery.scannedCount > 0 {
                VStack(spacing: 6) {
                    ProgressView(value: discovery.progress)
                        .tint(AppTheme.accent)
                        .animation(.linear(duration: 0.05), value: discovery.progress)
                    HStack {
                        Text(discovery.isScanning ? "Scanning…" : "Scan complete")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Spacer()
                        Text("\(discovery.scannedCount) / \(discovery.totalCount) hosts  •  \(discovery.discovered.count) found")
                            .font(.system(size: 11))
                            .foregroundColor(discovery.discovered.isEmpty ? AppTheme.textMuted : AppTheme.success)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppTheme.bg)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.border).frame(height: 1)
                }
            }

            // ── Results ────────────────────────────────────────────────────
            if discovery.discovered.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(discovery.discovered) { printer in
                            printerRow(printer)
                        }
                    }
                    .padding(20)
                }
                .background(AppTheme.bg)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onDisappear { discovery.stopScan() }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: discovery.isScanning ? "wifi" : "printer.fill")
                .font(.system(size: 56))
                .foregroundColor(AppTheme.textMuted.opacity(0.35))
                .scaleEffect(discovery.isScanning ? 1.06 : 1)
                .animation(
                    discovery.isScanning
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: discovery.isScanning
                )
            Text(
                discovery.isScanning        ? "Searching for printers on WiFi…" :
                discovery.scannedCount > 0  ? "No printers found on port 9100.\nMake sure the printer is on and connected to the same network." :
                                              "Tap 'Scan Network' to automatically find\nESC/POS printers on your WiFi."
            )
            .font(AppTheme.caption())
            .foregroundColor(AppTheme.textMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 48)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.bg)
    }

    // MARK: - Printer Row

    private func printerRow(_ printer: DiscoveredPrinter) -> some View {
        HStack(spacing: 16) {

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: "printer.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppTheme.success)
            }

            // IP + status
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 7, height: 7)
                    Text(printer.ip)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                }
                Text("Port \(printer.port)  •  TCP open  •  ESC/POS")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                Button {
                    onSelectReceipt(printer.ip, printer.port)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "printer.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Receipt")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.success)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    onSelectKitchen(printer.ip, printer.port)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Kitchen")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.warning)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .cornerRadius(AppTheme.r12)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.r12)
                .strokeBorder(AppTheme.success.opacity(0.25), lineWidth: 1)
        )
    }
}
