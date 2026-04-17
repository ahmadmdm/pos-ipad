// AppTips.swift — TipKit tip definitions shown to first-time users
import TipKit

// MARK: - Drag to Cart tip (shown on empty cart)
@available(iOS 17.0, *)
struct DragToCartTip: Tip {
    var title: Text { Text("Drag Products to Cart") }
    var message: Text? { Text("Drag any product card directly onto the cart panel to add it instantly.") }
    var image: Image? { Image(systemName: "hand.draw.fill") }
}

// MARK: - Keyboard shortcuts tip (shown in sidebar footer)
@available(iOS 17.0, *)
struct KeyboardShortcutsTip: Tip {
    var title: Text { Text("Keyboard Shortcuts") }
    var message: Text? { Text("Use ⌘1–⌘6 to switch tabs instantly. ⌘R refreshes the menu. ⌘, opens Settings.") }
    var image: Image? { Image(systemName: "keyboard.fill") }
}

// MARK: - Discover printers tip (shown in Printer Settings)
@available(iOS 17.0, *)
struct DiscoverPrintersTip: Tip {
    var title: Text { Text("Auto-Discover Printers") }
    var message: Text? { Text("Tap 'Discover Printers Automatically' to scan your local network and find ESC/POS printers instantly.") }
    var image: Image? { Image(systemName: "printer.fill") }
}

// MARK: - Context menu tip (shown on first long-press in orders)
@available(iOS 17.0, *)
struct OrderContextMenuTip: Tip {
    var title: Text { Text("Quick Actions") }
    var message: Text? { Text("Long-press any order to copy its number, download PDF, or cancel it — without opening the detail panel.") }
    var image: Image? { Image(systemName: "hand.tap.fill") }
}
