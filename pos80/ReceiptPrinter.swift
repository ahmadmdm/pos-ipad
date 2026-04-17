// ReceiptPrinter.swift — ESC/POS network receipt printer for iPad
import Foundation
import Network
import UIKit

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

    /// Print a full receipt.
    /// - Parameter paperSize: "58mm" for narrow paper (32 cols) or "80mm" for standard (42 cols).
    func printReceipt(receipt: ReceiptData, ip: String, port: UInt16, paperSize: String = "80mm") async -> Bool {
        let width = paperSize == "58mm" ? 32 : 42
        let data = buildReceipt(receipt, width: width)
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

    private func buildReceipt(_ r: ReceiptData, width: Int = 42) -> [UInt8] {
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
        cmd += text(separator(width))
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
        cmd += text(separator(width))
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
            cmd += text(padLine(qtyPrice + " " + item.nameEn, totalStr, width: width))
            cmd += ESC.lineFeed

            if let mods = item.modifiers, !mods.isEmpty {
                cmd += text("  + \(mods)")
                cmd += ESC.lineFeed
            }
        }

        cmd += text(separator(width))
        cmd += ESC.lineFeed

        // Totals
        cmd += text(padLine("Subtotal:", formatSAR(r.subtotal), width: width))
        cmd += ESC.lineFeed
        cmd += text(padLine("VAT (15%):", formatSAR(r.vatAmount), width: width))
        cmd += ESC.lineFeed
        cmd += ESC.boldOn + ESC.dblHeight
        cmd += text(padLine("TOTAL:", formatSAR(r.total), width: width))
        cmd += ESC.normal + ESC.boldOff + ESC.lineFeed

        cmd += text(separator(width))
        cmd += ESC.lineFeed

        // Payment
        cmd += text(padLine("Payment:", r.paymentMethod, width: width))
        cmd += ESC.lineFeed
        cmd += text(padLine("Paid:", formatSAR(r.amountPaid), width: width))
        cmd += ESC.lineFeed
        if r.change > 0 {
            cmd += text(padLine("Change:", formatSAR(r.change), width: width))
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

    // MARK: - Network Send (TCP) — with retry & descriptive errors

    enum PrintError: LocalizedError {
        case connectionFailed(String)
        case sendFailed(String)
        case timeout
        case cancelled

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let detail): return "Printer connection failed: \(detail)"
            case .sendFailed(let detail):       return "Failed to send data: \(detail)"
            case .timeout:                       return "Printer connection timed out"
            case .cancelled:                     return "Print job was cancelled"
            }
        }
    }

    /// Send data to printer with automatic retry (up to `maxRetries` attempts, exponential backoff).
    private func sendToNetwork(data: Data, ip: String, port: UInt16, maxRetries: Int = 2, timeoutSeconds: Double = 10) async -> Bool {
        for attempt in 0...maxRetries {
            let result = await sendOnce(data: data, ip: ip, port: port, timeout: timeoutSeconds)
            if result { return true }
            if attempt < maxRetries {
                // Exponential backoff: 0.5s, 1.0s
                try? await Task.sleep(nanoseconds: UInt64(500_000_000 * (attempt + 1)))
            }
        }
        return false
    }

    private func sendOnce(data: Data, ip: String, port: UInt16, timeout: Double) async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)
            let timeoutItem = DispatchWorkItem { [weak connection] in
                connection?.cancel()
            }

            func complete(_ value: Bool) {
                guard !resumed else { return }
                resumed = true
                timeoutItem.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: data, completion: .contentProcessed { error in
                        complete(error == nil)
                        connection.cancel()
                    })
                case .failed:
                    complete(false)
                case .cancelled:
                    complete(false)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        }
    }

    // MARK: - Cash Drawer Kick

    /// Open the cash drawer via ESC/POS pulse command.
    func openCashDrawer(ip: String, port: UInt16) async -> Bool {
        // ESC p m t1 t2 — Pulse pin 2 for 100ms on / 100ms off
        let cmd: [UInt8] = [0x1B, 0x70, 0x00, 0x19, 0x19]
        return await sendToNetwork(data: Data(cmd), ip: ip, port: port, maxRetries: 1, timeoutSeconds: 5)
    }

    // MARK: - Helpers

    private func text(_ str: String) -> [UInt8] {
        // ESC/POS Arabic printers typically use UTF-8
        return Array(str.utf8)
    }

    private func separator(_ width: Int = 42) -> String {
        String(repeating: "-", count: width)
    }

    /// Column-aligned two-part line. Uses UTF-8 byte count so ASCII printable
    /// columns stay accurate regardless of Unicode content.
    private func padLine(_ left: String, _ right: String, width: Int = 42) -> String {
        let usedBytes = left.utf8.count + right.utf8.count
        let gap = max(1, width - usedBytes)
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

    // MARK: - Receipt PDF Generator (thermal-receipt size)

    /// Generate a narrow receipt-format PDF matching thermal printer paper.
    func generateReceiptPDF(receipt: ReceiptData, paperSize: String = "80mm") -> Data {
        let mmToPoints: CGFloat = 72.0 / 25.4
        let pageWidth = (paperSize == "58mm" ? 58 : 80) * mmToPoints
        let margin: CGFloat = 8
        let contentWidth = pageWidth - margin * 2

        let titleFont = UIFont.boldSystemFont(ofSize: 14)
        let headerFont = UIFont.boldSystemFont(ofSize: 11)
        let bodyFont = UIFont.systemFont(ofSize: 10)
        let smallFont = UIFont.systemFont(ofSize: 8)
        let boldBodyFont = UIFont.boldSystemFont(ofSize: 10)
        let bigBold = UIFont.boldSystemFont(ofSize: 13)

        let textColor = UIColor.black

        // --- Measurement pass: calculate total height ---
        var height: CGFloat = margin

        func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
            let attr: [NSAttributedString.Key: Any] = [.font: font]
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attr, context: nil)
            return ceil(rect.height)
        }

        // Store header
        height += textHeight(receipt.storeName, font: titleFont, width: contentWidth) + 2
        if let ar = receipt.storeNameAr, !ar.isEmpty {
            height += textHeight(ar, font: headerFont, width: contentWidth) + 2
        }
        if let vat = receipt.vatNumber, !vat.isEmpty {
            height += textHeight("VAT: \(vat)", font: smallFont, width: contentWidth) + 2
        }
        if let branch = receipt.branchName, !branch.isEmpty {
            height += textHeight(branch, font: bodyFont, width: contentWidth) + 2
        }
        height += 10 // spacing + separator

        // Order info
        height += textHeight("Order #\(receipt.orderNumber)", font: headerFont, width: contentWidth) + 2
        height += textHeight("Type: \(receipt.orderType)", font: bodyFont, width: contentWidth) + 2
        height += textHeight("Cashier: \(receipt.cashierName)", font: bodyFont, width: contentWidth) + 2
        height += textHeight(dateString(), font: smallFont, width: contentWidth) + 2
        height += 10

        // Items
        for item in receipt.items {
            if !item.nameAr.isEmpty {
                height += textHeight(item.nameAr, font: boldBodyFont, width: contentWidth) + 1
            }
            let line = "\(item.quantity) x \(String(format: "%.2f", item.unitPrice))  \(item.nameEn)"
            height += textHeight(line, font: bodyFont, width: contentWidth) + 1
            if let mods = item.modifiers, !mods.isEmpty {
                height += textHeight("  + \(mods)", font: smallFont, width: contentWidth) + 1
            }
            height += 3
        }
        height += 10

        // Totals
        height += 4 * (textHeight("X", font: bodyFont, width: contentWidth) + 3) // subtotal, vat, total, separator
        height += textHeight("X", font: bigBold, width: contentWidth) + 4 // TOTAL large
        height += 10

        // Payment
        height += 2 * (textHeight("X", font: bodyFont, width: contentWidth) + 3)
        if receipt.change > 0 {
            height += textHeight("X", font: bodyFont, width: contentWidth) + 3
        }
        height += 10

        // QR
        if receipt.qrData != nil {
            height += 100 // QR block
        }

        // Footer
        height += 30
        height += margin + 20 // bottom padding

        // --- Drawing pass ---
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: height)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let gc = ctx.cgContext
            var y: CGFloat = margin

            // Draw helpers
            func drawText(_ text: String, font: UIFont, alignment: NSTextAlignment = .natural, maxWidth: CGFloat? = nil) {
                let style = NSMutableParagraphStyle()
                style.alignment = alignment
                style.lineBreakMode = .byWordWrapping
                let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: style]
                let w = maxWidth ?? contentWidth
                let h = textHeight(text, font: font, width: w)
                let rect = CGRect(x: margin, y: y, width: w, height: h + 2)
                (text as NSString).draw(in: rect, withAttributes: attr)
                y += h + 2
            }

            func drawLine(_ text: String, right: String, font: UIFont) {
                let style = NSMutableParagraphStyle()
                style.alignment = .left
                let rStyle = NSMutableParagraphStyle()
                rStyle.alignment = .right
                let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: style]
                let rAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor, .paragraphStyle: rStyle]
                let h = textHeight(text, font: font, width: contentWidth)
                let rect = CGRect(x: margin, y: y, width: contentWidth, height: h + 2)
                (text as NSString).draw(in: rect, withAttributes: attr)
                (right as NSString).draw(in: rect, withAttributes: rAttr)
                y += h + 3
            }

            func drawSeparator() {
                gc.setStrokeColor(UIColor.darkGray.cgColor)
                gc.setLineDash(phase: 0, lengths: [2, 2])
                gc.setLineWidth(0.5)
                gc.move(to: CGPoint(x: margin, y: y))
                gc.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                gc.strokePath()
                gc.setLineDash(phase: 0, lengths: [])
                y += 6
            }

            // --- Header ---
            drawText(receipt.storeName, font: titleFont, alignment: .center)
            if let ar = receipt.storeNameAr, !ar.isEmpty {
                drawText(ar, font: headerFont, alignment: .center)
            }
            if let vat = receipt.vatNumber, !vat.isEmpty {
                drawText("VAT: \(vat)", font: smallFont, alignment: .center)
            }
            if let branch = receipt.branchName, !branch.isEmpty {
                drawText(branch, font: bodyFont, alignment: .center)
            }
            y += 4
            drawSeparator()

            // --- Order info ---
            drawText("Order #\(receipt.orderNumber)", font: headerFont)
            drawLine("Type:", right: receipt.orderType, font: bodyFont)
            drawLine("Cashier:", right: receipt.cashierName, font: bodyFont)
            drawText(dateString(), font: smallFont)
            y += 2
            drawSeparator()

            // --- Items ---
            for item in receipt.items {
                if !item.nameAr.isEmpty {
                    drawText(item.nameAr, font: boldBodyFont)
                }
                let totalStr = String(format: "%.2f", item.total)
                drawLine("\(item.quantity) x \(String(format: "%.2f", item.unitPrice))  \(item.nameEn)",
                         right: totalStr, font: bodyFont)
                if let mods = item.modifiers, !mods.isEmpty {
                    drawText("  + \(mods)", font: smallFont)
                }
                y += 2
            }
            drawSeparator()

            // --- Totals ---
            drawLine("Subtotal:", right: String(format: "%.2f SAR", receipt.subtotal), font: bodyFont)
            drawLine("VAT (15%):", right: String(format: "%.2f SAR", receipt.vatAmount), font: bodyFont)
            drawSeparator()
            drawLine("TOTAL:", right: String(format: "%.2f SAR", receipt.total), font: bigBold)
            y += 4
            drawSeparator()

            // --- Payment ---
            drawLine("Payment:", right: receipt.paymentMethod, font: bodyFont)
            drawLine("Paid:", right: String(format: "%.2f SAR", receipt.amountPaid), font: bodyFont)
            if receipt.change > 0 {
                drawLine("Change:", right: String(format: "%.2f SAR", receipt.change), font: bodyFont)
            }
            y += 4

            // --- QR Code ---
            if let qrString = receipt.qrData, !qrString.isEmpty,
               let qrImage = generateQRImage(from: qrString, size: 80) {
                let qrX = margin + (contentWidth - 80) / 2
                qrImage.draw(in: CGRect(x: qrX, y: y, width: 80, height: 80))
                y += 86
            }

            // --- Footer ---
            if let footer = receipt.footer, !footer.isEmpty {
                drawText(footer, font: smallFont, alignment: .center)
            }
            drawText("شكراً لزيارتكم", font: bodyFont, alignment: .center)
        }
    }

    /// Present AirPrint dialog with receipt-sized PDF
    @MainActor
    func printViaAirPrint(receipt: ReceiptData, paperSize: String = "80mm") {
        let pdfData = generateReceiptPDF(receipt: receipt, paperSize: paperSize)

        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Receipt #\(receipt.orderNumber)"
        printController.printInfo = printInfo
        printController.printingItem = pdfData
        printController.present(animated: true)
    }

    /// Generate QR code UIImage from string data
    private func generateQRImage(from string: String, size: CGFloat) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaleX = size / output.extent.width
        let scaleY = size / output.extent.height
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let ciCtx = CIContext()
        guard let cgImage = ciCtx.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
