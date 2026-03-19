// Localization.swift — Centralized Arabic/English localization for Ampos POS
import SwiftUI

// MARK: - Localization Manager
@Observable
@MainActor
final class L10n {

    static let shared = L10n()
    private let key = "pos_language"

    var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: key)
        }
    }

    var isArabic: Bool { language == .arabic }

    private init() {
        let saved = UserDefaults.standard.string(forKey: key) ?? Language.english.rawValue
        language = Language(rawValue: saved) ?? .english
    }

    enum Language: String, CaseIterable {
        case english = "en"
        case arabic  = "ar"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .arabic:  return "العربية"
            }
        }
    }

    // MARK: - Convenience
    func t(_ en: String, _ ar: String) -> String {
        isArabic ? ar : en
    }
}

// MARK: - String Keys (organized by screen)
extension L10n {

    // MARK: Common
    var ok: String { t("OK", "حسناً") }
    var cancel: String { t("Cancel", "إلغاء") }
    var save: String { t("Save", "حفظ") }
    var error: String { t("Error", "خطأ") }
    var retry: String { t("Retry", "إعادة المحاولة") }
    var close: String { t("Close", "إغلاق") }
    var search: String { t("Search", "بحث") }
    var loading: String { t("Loading...", "جاري التحميل...") }
    var noData: String { t("No data available", "لا توجد بيانات") }

    // MARK: Auth
    var welcomeBack: String { t("Welcome Back", "أهلاً بعودتك") }
    var signInSubtitle: String { t("Sign in to start your shift", "سجّل الدخول لبدء وردِيتك") }
    var emailPlaceholder: String { t("Email address", "البريد الإلكتروني") }
    var password: String { t("Password", "كلمة المرور") }
    var signIn: String { t("Sign In", "تسجيل الدخول") }
    var signInWithPIN: String { t("Sign In with PIN", "الدخول بالرقم السري") }
    var pinTab: String { t("PIN", "رقم سري") }
    var passwordTab: String { t("Password", "كلمة مرور") }

    // MARK: Tabs
    var tabPOS: String { t("POS", "نقطة البيع") }
    var tabOrders: String { t("Orders", "الطلبات") }
    var tabTables: String { t("Tables", "الطاولات") }
    var tabShift: String { t("Shift", "الوردية") }
    var tabReports: String { t("Reports", "التقارير") }
    var tabSettings: String { t("Settings", "الإعدادات") }

    func tabName(_ tab: String) -> String {
        switch tab.lowercased() {
        case "pos":      return tabPOS
        case "orders":   return tabOrders
        case "tables":   return tabTables
        case "shift":    return tabShift
        case "reports":  return tabReports
        case "settings": return tabSettings
        default:         return tab
        }
    }

    // MARK: POS / Cart
    var searchProducts: String { t("Search products or scan barcode...", "ابحث عن منتج أو امسح الباركود...") }
    var allCategories: String { t("All", "الكل") }
    var order: String { t("Order", "الطلب") }
    var noTable: String { t("No Table", "بدون طاولة") }
    var cartEmpty: String { t("Cart is empty", "السلة فارغة") }
    var tapToAdd: String { t("Tap a product to add it", "اضغط على منتج لإضافته") }
    var subtotal: String { t("Subtotal", "المجموع الفرعي") }
    var discount: String { t("Discount", "الخصم") }
    var vat15: String { t("VAT (15%)", "ضريبة القيمة المضافة (١٥٪)") }
    var vat: String { t("VAT", "ضريبة القيمة المضافة") }
    var total: String { t("Total", "الإجمالي") }
    var openShiftFirst: String { t("Open a shift to accept payments", "افتح وردية لقبول المدفوعات") }
    var offlineMode: String { t("Offline mode — order will sync when connected", "وضع عدم الاتصال — سيتم المزامنة عند الإتصال") }
    var note: String { t("Note", "ملاحظة") }
    var hold: String { t("Hold", "تعليق") }
    var remove: String { t("Remove", "حذف") }
    var noProductsAvailable: String { t("No products available", "لا توجد منتجات") }

    // MARK: Payment
    var payment: String { t("Payment", "الدفع") }
    var totalAmount: String { t("Total Amount", "المبلغ الإجمالي") }
    var orderSummary: String { t("Order Summary", "ملخص الطلب") }
    var items: String { t("items", "عناصر") }
    var paymentMethod: String { t("Payment Method", "طريقة الدفع") }
    var single: String { t("Single", "دفعة واحدة") }
    var split: String { t("Split", "تقسيم") }
    var amount: String { t("Amount", "المبلغ") }
    var rest: String { t("Rest", "المتبقي") }
    var remaining: String { t("Remaining", "المتبقي") }
    var cashTendered: String { t("Cash Tendered", "المبلغ المُقدّم") }
    var exact: String { t("Exact", "المبلغ الصحيح") }
    var amountReceived: String { t("Amount received", "المبلغ المستلم") }
    var change: String { t("Change", "الباقي") }
    var insufficientAmount: String { t("Insufficient amount", "المبلغ غير كافي") }
    var customerOptional: String { t("Customer (Optional)", "العميل (اختياري)") }
    var customerName: String { t("Customer name", "اسم العميل") }
    func confirmPayment(_ method: String) -> String { t("Confirm \(method) Payment", "تأكيد الدفع \(method)") }
    var confirmSplitPayment: String { t("Confirm Split Payment", "تأكيد الدفع المقسّم") }
    var paymentSuccessful: String { t("Payment Successful!", "تمت عملية الدفع بنجاح!") }
    var downloadInvoice: String { t("Download Invoice", "تحميل الفاتورة") }
    var printReceipt: String { t("Print Receipt", "طباعة الإيصال") }
    var newOrder: String { t("New Order", "طلب جديد") }

    // MARK: Payment Methods
    var cash: String { t("Cash", "نقدي") }
    var card: String { t("Card", "بطاقة") }
    var applePay: String { t("Apple Pay", "آبل باي") }
    var mada: String { t("Mada", "مدى") }

    // MARK: Shift
    var shiftManagement: String { t("Shift Management", "إدارة الورديات") }
    var manageShift: String { t("Manage your cashier shift", "إدارة وردية الكاشير") }
    var shiftActive: String { t("Shift Active", "الوردية نشطة") }
    var live: String { t("LIVE", "مباشر") }
    var openingCash: String { t("Opening Cash", "النقد الافتتاحي") }
    var totalSales: String { t("Total Sales", "إجمالي المبيعات") }
    var totalOrders: String { t("Total Orders", "إجمالي الطلبات") }
    var cashSales: String { t("Cash Sales", "المبيعات النقدية") }
    var closeShift: String { t("Close Shift", "إغلاق الوردية") }
    var closingCash: String { t("Closing cash amount", "مبلغ الإغلاق النقدي") }
    var cashDifference: String { t("Cash Difference:", "فرق النقد:") }
    var closeShiftConfirmTitle: String { t("Close Shift", "إغلاق الوردية") }
    var closeShiftConfirmMsg: String { t("Are you sure you want to close the current shift?", "هل أنت متأكد من إغلاق الوردية الحالية؟") }
    var noActiveShift: String { t("No Active Shift", "لا توجد وردية نشطة") }
    var openShiftCTA: String { t("Open a shift to start accepting orders", "افتح وردية للبدء بقبول الطلبات") }
    var openingCashAmount: String { t("Opening Cash Amount", "مبلغ النقد الافتتاحي") }
    var openShift: String { t("Open Shift", "فتح وردية") }
    var shiftHistory: String { t("Shift History", "سجل الورديات") }
    var noShiftHistory: String { t("No shift history", "لا يوجد سجل ورديات") }
    func shiftOpened() -> String { t("Shift opened successfully", "تم فتح الوردية بنجاح") }
    func shiftClosed(_ sales: String) -> String { t("Shift closed. Total sales: \(sales)", "تم إغلاق الوردية. إجمالي المبيعات: \(sales)") }

    // MARK: Orders
    var orders: String { t("Orders", "الطلبات") }
    var searchOrders: String { t("Search orders...", "ابحث عن طلب...") }
    var allStatus: String { t("All", "الكل") }
    var received: String { t("Received", "مستلم") }
    var preparing: String { t("Preparing", "جاري التحضير") }
    var ready: String { t("Ready", "جاهز") }
    var paid: String { t("Paid", "مدفوع") }
    var cancelled: String { t("Cancelled", "ملغي") }
    var noOrdersFound: String { t("No orders found", "لم يتم العثور على طلبات") }
    var selectOrder: String { t("Select an order to view details", "اختر طلباً لعرض التفاصيل") }
    var actions: String { t("Actions", "الإجراءات") }
    var markPreparing: String { t("Mark Preparing", "تحضير") }
    var markReady: String { t("Mark Ready", "جاهز") }
    var markServed: String { t("Mark Served", "تم التقديم") }
    var cancelOrder: String { t("Cancel Order", "إلغاء الطلب") }
    var invoicePDF: String { t("Invoice PDF", "فاتورة PDF") }

    // MARK: Tables
    var tables: String { t("Tables", "الطاولات") }

    // MARK: Settings
    var settings: String { t("Settings", "الإعدادات") }
    var configurePos: String { t("Configure your POS", "إعدادات نقطة البيع") }
    var general: String { t("General", "عام") }
    var receipt: String { t("Receipt", "الإيصال") }
    var printer: String { t("Printer", "الطابعة") }
    var taxCompliance: String { t("Tax & Compliance", "الضريبة والامتثال") }
    var staff: String { t("Staff", "الموظفون") }
    var about: String { t("About", "حول") }
    var serverConnection: String { t("Server Connection", "اتصال الخادم") }
    var serverURL: String { t("Server URL", "رابط الخادم") }
    var appearance: String { t("Appearance", "المظهر") }
    var darkMode: String { t("Dark Mode", "الوضع الداكن") }
    var lightMode: String { t("Light", "فاتح") }
    var languageLabel: String { t("Language", "اللغة") }

    // MARK: Order Types
    var dineIn: String { t("Dine In", "محلي") }
    var takeaway: String { t("Takeaway", "سفري") }
    var delivery: String { t("Delivery", "توصيل") }
    var orderType: String { t("Order Type", "نوع الطلب") }
    var selectTable: String { t("Select Table", "اختر طاولة") }
    var none: String { t("None", "بدون") }
    var applyDiscount: String { t("Apply Discount", "تطبيق الخصم") }
    var removeDiscount: String { t("Remove Discount", "حذف الخصم") }
    var orderNotes: String { t("Order Notes", "ملاحظات الطلب") }
    var saveNotes: String { t("Save Notes", "حفظ الملاحظات") }
    var heldOrders: String { t("Held Orders", "الطلبات المعلّقة") }
    var noHeldOrders: String { t("No held orders", "لا توجد طلبات معلّقة") }
    var holdSubtitle: String { t("Hold an order from the cart to save it for later", "علّق طلب من السلة لحفظه لاحقاً") }
    var restore: String { t("Restore", "استعادة") }
    var loadToCart: String { t("Load to Cart", "تحميل إلى السلة") }
    var heldOrderLoaded: String { t("Held order loaded into cart", "تم تحميل الطلب المعلّق إلى السلة") }
    var heldOrderLoadedPartial: String { t("Held order loaded with missing items skipped", "تم تحميل الطلب مع تجاوز العناصر غير المتاحة") }
    var heldOrderNotRestorable: String { t("This held order can't be loaded into the cart", "لا يمكن تحميل هذا الطلب المعلّق إلى السلة") }

    // MARK: Login Screen
    var professionalPOS: String { t("Professional Point of Sale", "نظام نقاط البيع الاحترافي") }
    var poweredBy: String { t("Powered by Ampos Platform", "مدعوم من منصة Ampos") }
    var fastOrderMgmt: String { t("Fast Order Management", "إدارة سريعة للطلبات") }
    var realTimeAnalytics: String { t("Real-Time Analytics", "تحليلات فورية") }
    var escPrinting: String { t("ESC/POS Printing", "طباعة ESC/POS") }
    var zatcaCompliant: String { t("ZATCA Compliant", "متوافق مع هيئة الزكاة") }

    // MARK: POS Extras
    func noResults(_ query: String) -> String { t("No results for \"\(query)\"", "لا نتائج لـ \"\(query)\"") }
    var discountAmountSAR: String { t("Discount amount (SAR)", "مبلغ الخصم (ريال)") }
    var noTablesConfigured: String { t("No tables configured", "لم يتم إعداد طاولات") }
    var cartSubtotalPrefix: String { t("Cart Subtotal:", "المجموع الفرعي للسلة:") }
    var processing: String { t("Processing...", "جاري المعالجة...") }

    // MARK: Settings extras
    var apiEndpoint: String { t("API endpoint", "رابط واجهة البرمجة") }
    var storeInfo: String { t("Store Info", "معلومات المتجر") }
    var businessName: String { t("Business Name", "اسم النشاط") }
    var currency: String { t("Currency", "العملة") }
    var timeZone: String { t("Time Zone", "المنطقة الزمنية") }
    var posBehavior: String { t("POS Behavior", "سلوك نقطة البيع") }
    var receiptPrinter: String { t("Receipt Printer", "طابعة الإيصالات") }
    var kitchenPrinter: String { t("Kitchen Printer", "طابعة المطبخ") }
    var saveAndTestPrint: String { t("Save & Test Print", "حفظ وطباعة تجريبية") }
    var vatConfiguration: String { t("VAT Configuration", "إعدادات الضريبة") }
    var zatcaIntegration: String { t("ZATCA Integration", "تكامل هيئة الزكاة") }
    var staffMembers: String { t("Staff Members", "أعضاء الفريق") }
    var addStaff: String { t("Add Staff", "إضافة موظف") }
    var noStaffMembers: String { t("No staff members", "لا يوجد موظفون") }
    var receiptOptions: String { t("Receipt Options", "خيارات الإيصال") }
    var receiptFormat: String { t("Receipt Format", "تنسيق الإيصال") }
    var receiptFooter: String { t("Receipt Footer", "تذييل الإيصال") }
    var saveReceiptSettings: String { t("Save Receipt Settings", "حفظ إعدادات الإيصال") }
    var invoice: String { t("Invoice", "فاتورة") }
    var items_label: String { t("Items", "العناصر") }
    var dark: String { t("Dark", "داكن") }
    var light: String { t("Light", "فاتح") }
    var switchTheme: String { t("Switch between light and dark theme", "التبديل بين الوضع الفاتح والداكن") }
    var opened: String { t("Opened at", "تم الفتح في") }
    var shift_word: String { t("Shift", "وردية") }
    var noShift: String { t("No Shift", "لا وردية") }
    var offline: String { t("Offline", "غير متصل") }
    var pending: String { t("pending", "بانتظار المزامنة") }
    func ordersCount(_ n: Int) -> String { t("\(n) orders", "\(n) طلبات") }
    func itemsCount(_ n: Int) -> String { t("\(n) items", "\(n) عناصر") }
}
