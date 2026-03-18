// SpotlightManager.swift — Index orders in Spotlight for system-wide search
import CoreSpotlight
import UniformTypeIdentifiers
import Foundation

@MainActor
final class SpotlightManager {
    static let shared = SpotlightManager()
    private init() {}

    private let domainId = "com.ampos.pos80.orders"

    /// Index a list of orders so they appear in Spotlight search.
    func indexOrders(_ orders: [Order]) {
        let items: [CSSearchableItem] = orders.map { order in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = order.orderNumber ?? "Order #\(order.displayNumber ?? 0)"
            attrs.contentDescription = "\(order.orderStatus.displayName) · \(order.totalSafe.sarFormatted)"
            attrs.keywords = [
                order.orderNumber,
                order.customerName,
                order.tableNumber,
                order.displayNumber.map { "#\($0)" },
                order.status
            ].compactMap { $0 }
            return CSSearchableItem(
                uniqueIdentifier: order.id,
                domainIdentifier: domainId,
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Remove all indexed order items (call on logout).
    func deleteAllOrderItems() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainId]) { _ in }
    }
}
