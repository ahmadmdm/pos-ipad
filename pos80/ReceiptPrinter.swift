// ReceiptPrinter.swift — ESC/POS network receipt printer for iPad
import Foundation
import Network

/// ESC/POS command constants
private enum ESC {
    static let init_    : [UInt8] = [0x1B, 0x40]           // Initialize printer
    static let cut      : [UInt8] = [0x1D, 0x56, 0x42, 0x03] // Paper cut (partial)
    static let lineFeed : [UInt8] = [0x0A]                 // Line feed
    static let center   : [UInt8] = [0x1B, 0x61, 0x01]    // Center align
    static let left     : [UInt8] = [0x1B, 0x61, 0x00]    // Left align
    static let right    : [UInt8] = [0x1B, 0x61, 0x02]    // Right align
    static let boldOn   : [UInt8] = [0x1B, 0x45, 0x01]    // Bold on
    static let boldOff  : [UInt8] = [0x1B, 0x45, 0x00]    // Bold off
    static let dblHeight: [UInt8] = [0x1D, 0x21, 0x01]    // Double height
    static let normal   : [UInt8] = [0x1D, 0x21, 0x00]    // Normal size
    static let dblWidth : [UInt8] = [0x1D, 0x21, 0x10]    // Double width
    static let large    : [UInt8] = [0x1D, 0x21, 0x11]    // Double width+height

    // QR code commands: store + print
    static func qrCode(_ data: String) -> [UInt8] {
        let bytes = Array(data.utf8)
        let len = bytes.count + 3
        var cmd: [UInt8] = []
        // Set QR model 2
        cmd += [0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]
        // Set QR size (module size 6)
        cmd += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]
        // Set error correction level L
        cmd += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]
        // Store QR data
        cmd += [0x1D, 0x28, 0x6B, UInt8(len & 0xFF), UInt8((len >> 8) & 0xFF), 0x31, 0x50, 0x30]
        cmd += bytes
        // Print QR
        cmd += [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]
        return cmd
    }
}

// MARK: - Receipt Data Model
struct ReceiptData {
    let storeName: String
    let storeNameAr: String?
    let vatNumber: String?
    let branchName: String?
    let orderNumber: String
    let orderType: String
    let cashierName: String
    let items: [ReceiptItem]
    let subtotal: Double
    let vatAmount: Double
    let total: Double
    let paymentMethod: String
    let amountPaid: Double
    let change: Double
    let qrData: String? // ZATCA TLV QR base64
    let footer: String?

    struct ReceiptItem {
        let nameAr: String
        let nameEn: String
        let quantity: Int
        let unitPrice: Double
        let total: Double
        let modifiers: String?
    }
}

// MARK: - Receipt Printer
final class ReceiptPrinter {
    static let shared = ReceiptPrinter()

    private init() {}

    /// Print a full receipt
    func printReceipt(receipt: ReceiptData, ip: String, port: UInt16) async -> Bool {
        let data = buildReceipt(receipt)
        return await sendToNetwork(data: Data(data), ip: ip, port: port)
    }

    /// Test print — sends a small test receipt, returns true if successful
    @discardableResult
    func testPrint(ip: String, port: UInt16) async -> Bool {
        var cmd: [UInt8] = []
        cmd += ESC.init_
        cmd += ESC.center
        cmd += ESC.boldOn + ESC.dblHeight
        cmd += text("AMPOS POS")
        cmd += ESC.normal + ESC.boldOff
        cmd += ESC.lineFeed
        cmd += text("--- Test Print ---")
        cmd += ESC.lineFeed
        cmd += ESC.left
        cmd += text("Printer connection OK")
        cmd += ESC.lineFeed
        cmd += text(dateString())
        cmd += ESC.lineFeed + ESC.lineFeed + ESC.lineFeed
        cmd += ESC.cut
        return await sendToNetwork(data: Data(cmd), ip: ip, port: port)
    }

    // MARK: - Build Receipt

    private func buildReceipt(_ r: ReceiptData) -> [UInt8] {
        var cmd: [UInt8] = []

        // Initialize
        cmd += ESC.init_

        // Header
        cmd += ESC.center
        cmd += ESC.boldOn + ESC.large
        cmd += text(r.storeName)
        cmd += ESC.normal + ESC.boldOff + ESC.lineFeed

        if let ar = r.storeNameAr, !ar.isEmpty {
            cmd += text(ar)
            cmd += ESC.lineFeed
        }

        if let vat = r.vatNumber, !vat.isEmpty {
            cmd += text("VAT: \(vat)")
            cmd += ESC.lineFeed
        }

        if let branch = r.branchName, !branch.isEmpty {
            cmd += text(branch)
            cmd += ESC.lineFeed
        }

        cmd += ESC.lineFeed
        cmd += text(separator())
        cmd += ESC.lineFeed

        // Order info
        cmd += ESC.left
        cmd += ESC.boldOn
        cmd += text("Order #\(r.orderNumber)")
        cmd += ESC.boldOff + ESC.lineFeed
        cmd += text("Type: \(r.orderType)")
        cmd += ESC.lineFeed
        cmd += text("Cashier: \(r.cashierName)")
        cmd += ESC.lineFeed
        cmd += text("Date: \(dateString())")
        cmd += ESC.lineFeed
        cmd += text(separator())
        cmd += ESC.lineFeed

        // Items
        for item in r.items {
            // Arabic name (primary)
            if !item.nameAr.isEmpty {
                cmd += ESC.boldOn
                cmd += text(item.nameAr)
                cmd += ESC.boldOff + ESC.lineFeed
            }
            // English name + qty x price
            let qtyPrice = "\(item.quantity) x \(formatSAR(item.unitPrice))"
            let totalStr = formatSAR(item.total)
            cmd += text(padLine(qtyPrice + " " + item.nameEn, totalStr))
            cmd += ESC.lineFeed

            if let mods = item.modifiers, !mods.isEmpty {
                cmd += text("  + \(mods)")
                cmd += ESC.lineFeed
            }
        }

        cmd += text(separator())
        cmd += ESC.lineFeed

        // Totals
        cmd += text(padLine("Subtotal:", formatSAR(r.subtotal)))
        cmd += ESC.lineFeed
        cmd += text(padLine("VAT (15%):", formatSAR(r.vatAmount)))
        cmd += ESC.lineFeed
        cmd += ESC.boldOn + ESC.dblHeight
        cmd += text(padLine("TOTAL:", formatSAR(r.total)))
        cmd += ESC.normal + ESC.boldOff + ESC.lineFeed

        cmd += text(separator())
        cmd += ESC.lineFeed

        // Payment
        cmd += text(padLine("Payment:", r.paymentMethod))
        cmd += ESC.lineFeed
        cmd += text(padLine("Paid:", formatSAR(r.amountPaid)))
        cmd += ESC.lineFeed
        if r.change > 0 {
            cmd += text(padLine("Change:", formatSAR(r.change)))
            cmd += ESC.lineFeed
        }

        cmd += ESC.lineFeed

        // QR Code (ZATCA)
        if let qr = r.qrData, !qr.isEmpty {
            cmd += ESC.center
            cmd += ESC.qrCode(qr)
            cmd += ESC.lineFeed
        }

        // Footer
        cmd += ESC.center
        if let footer = r.footer, !footer.isEmpty {
            cmd += text(footer)
            cmd += ESC.lineFeed
        }
        cmd += text("شكراً لزيارتكم")
        cmd += ESC.lineFeed

        // Feed & cut
        cmd += ESC.lineFeed + ESC.lineFeed + ESC.lineFeed + ESC.lineFeed
        cmd += ESC.cut

        return cmd
    }

    // MARK: - Network Send (TCP)

    private func sendToNetwork(data: Data, ip: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)

            func complete(_ value: Bool) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        connection.cancel()
                        complete(error == nil)
                    })
                case .failed, .cancelled:
                    complete(false)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                connection.cancel()
                complete(false)
            }
        }
    }

    // MARK: - Helpers

    private func text(_ str: String) -> [UInt8] {
        // ESC/POS Arabic printers typically use UTF-8
        return Array(str.utf8)
    }

    private func separator(_ width: Int = 48) -> String {
        String(repeating: "-", count: width)
    }

    private func padLine(_ left: String, _ right: String, width: Int = 48) -> String {
        let gap = max(1, width - left.count - right.count)
        return left + String(repeating: " ", count: gap) + right
    }

    private func formatSAR(_ amount: Double) -> String {
        String(format: "%.2f SAR", amount)
    }

    private func dateString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
