// ZATCALocalSigner.swift — Local ZATCA Phase 2 TLV QR code generation
// Generates the TLV-encoded Base64 QR code locally on the iPad
// so invoices are signed immediately even when offline.
// The full UBL XML signing is deferred to the backend on sync.

import Foundation
import CryptoKit

/// ZATCA Tag-Length-Value encoder for QR code generation (Phase 2 simplified)
enum ZATCALocalSigner {

    // MARK: - TLV QR Code Generation
    /// Generates a ZATCA-compliant TLV Base64 QR string locally
    /// - Parameters:
    ///   - sellerName: Business name (Arabic)
    ///   - vatNumber: 15-digit VAT registration number
    ///   - timestamp: Invoice date/time in ISO 8601
    ///   - totalWithVAT: Invoice total including VAT
    ///   - vatAmount: VAT amount
    /// - Returns: Base64-encoded TLV string for QR code
    static func generateQRBase64(
        sellerName: String,
        vatNumber: String,
        timestamp: String,
        totalWithVAT: Double,
        vatAmount: Double
    ) -> String {
        var tlvData = Data()

        // Tag 1: Seller Name
        appendTLV(tag: 1, value: sellerName, to: &tlvData)
        // Tag 2: VAT Registration Number
        appendTLV(tag: 2, value: vatNumber, to: &tlvData)
        // Tag 3: Timestamp (ISO 8601)
        appendTLV(tag: 3, value: timestamp, to: &tlvData)
        // Tag 4: Invoice Total (with VAT)
        appendTLV(tag: 4, value: String(format: "%.2f", totalWithVAT), to: &tlvData)
        // Tag 5: VAT Amount
        appendTLV(tag: 5, value: String(format: "%.2f", vatAmount), to: &tlvData)

        return tlvData.base64EncodedString()
    }

    /// Generates a SHA-256 hash of the invoice data for chain integrity
    static func invoiceHash(
        orderNumber: String,
        total: Double,
        vatAmount: Double,
        timestamp: String,
        previousHash: String?
    ) -> String {
        let input = "\(previousHash ?? "0")\(orderNumber)\(total)\(vatAmount)\(timestamp)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private TLV Helpers
    private static func appendTLV(tag: UInt8, value: String, to data: inout Data) {
        let valueBytes = Data(value.utf8)
        data.append(tag)
        // Length can be multi-byte for values > 127
        let length = valueBytes.count
        if length <= 127 {
            data.append(UInt8(length))
        } else {
            // Two-byte length
            data.append(0x82)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
        }
        data.append(valueBytes)
    }
}

// MARK: - Local Invoice Record
/// Stored locally on the iPad for offline invoices pending server sync
struct LocalInvoice: Codable, Identifiable {
    var id: String { invoiceId }
    let invoiceId: String          // UUID
    let orderLocalId: String       // Links to OfflineOrder.localId
    let orderNumber: String?
    let sellerNameAr: String
    let vatNumber: String
    let timestamp: String          // ISO 8601
    let subtotal: Double
    let vatAmount: Double
    let total: Double
    let qrCodeBase64: String       // TLV QR
    let invoiceHash: String        // SHA-256 chain hash
    let previousHash: String?
    var syncedToServer: Bool
    let createdAt: String

    static func create(
        orderLocalId: String,
        orderNumber: String?,
        sellerNameAr: String,
        vatNumber: String,
        subtotal: Double,
        discountAmount: Double,
        vatRate: Double = 0.15,
        previousHash: String?
    ) -> LocalInvoice {
        let taxableAmount = subtotal - discountAmount
        let vatAmount = taxableAmount * vatRate
        let total = taxableAmount + vatAmount
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let invoiceId = UUID().uuidString

        let qr = ZATCALocalSigner.generateQRBase64(
            sellerName: sellerNameAr,
            vatNumber: vatNumber,
            timestamp: timestamp,
            totalWithVAT: total,
            vatAmount: vatAmount
        )

        let hash = ZATCALocalSigner.invoiceHash(
            orderNumber: orderNumber ?? invoiceId,
            total: total,
            vatAmount: vatAmount,
            timestamp: timestamp,
            previousHash: previousHash
        )

        return LocalInvoice(
            invoiceId: invoiceId,
            orderLocalId: orderLocalId,
            orderNumber: orderNumber,
            sellerNameAr: sellerNameAr,
            vatNumber: vatNumber,
            timestamp: timestamp,
            subtotal: subtotal,
            vatAmount: vatAmount,
            total: total,
            qrCodeBase64: qr,
            invoiceHash: hash,
            previousHash: previousHash,
            syncedToServer: false,
            createdAt: timestamp
        )
    }
}

// MARK: - Local Invoice Store
@Observable
@MainActor
final class LocalInvoiceStore {

    static let shared = LocalInvoiceStore()
    private let storageKey = "local_invoices"
    private let lastHashKey = "zatca_last_local_hash"

    var invoices: [LocalInvoice] = []

    private init() { load() }

    var lastHash: String? {
        get { UserDefaults.standard.string(forKey: lastHashKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastHashKey) }
    }

    func createInvoice(
        orderLocalId: String,
        orderNumber: String?,
        sellerNameAr: String,
        vatNumber: String,
        subtotal: Double,
        discountAmount: Double
    ) -> LocalInvoice {
        let invoice = LocalInvoice.create(
            orderLocalId: orderLocalId,
            orderNumber: orderNumber,
            sellerNameAr: sellerNameAr,
            vatNumber: vatNumber,
            subtotal: subtotal,
            discountAmount: discountAmount,
            previousHash: lastHash
        )
        invoices.append(invoice)
        lastHash = invoice.invoiceHash
        save()
        return invoice
    }

    func markSynced(_ invoiceId: String) {
        if let idx = invoices.firstIndex(where: { $0.invoiceId == invoiceId }) {
            invoices[idx].syncedToServer = true
            save()
        }
    }

    var unsyncedInvoices: [LocalInvoice] {
        invoices.filter { !$0.syncedToServer }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LocalInvoice].self, from: data) else { return }
        invoices = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(invoices) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        // Cleanup: keep only last 200
        if invoices.count > 200 {
            let synced = invoices.filter { $0.syncedToServer }
            if synced.count > 100 {
                let toRemove = Set(synced.prefix(synced.count - 100).map { $0.invoiceId })
                invoices.removeAll { toRemove.contains($0.invoiceId) }
                save()
            }
        }
    }
}
