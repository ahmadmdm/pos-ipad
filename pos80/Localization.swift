// Localization.swift — Centralized Arabic/English localization for Ampos POS
import SwiftUI
import Combine

// MARK: - Localization Manager
@MainActor
final class L10n: ObservableObject {

    static let shared = L10n()
    private let key = "pos_language"

    @Published var language: Language {
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
    var approve: String { t("Approve", "اعتماد") }
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
    var tenantCode: String { t("Tenant Code", "رمز الفرع") }
    var tenantCodePlaceholder: String { t("Enter tenant code", "أدخل رمز الفرع") }
    var resolveTenant: String { t("Verify", "تحقق") }
    var tenantResolved: String { t("Restaurant verified", "تم التحقق من المطعم") }
    var enterTenantCodeFirst: String { t("Enter and verify the tenant code first", "أدخل رمز الفرع وتحقق منه أولاً") }
    var emailPlaceholder: String { t("Email address", "البريد الإلكتروني") }
    var password: String { t("Password", "كلمة المرور") }
    var signIn: String { t("Sign In", "تسجيل الدخول") }
    var signInWithPIN: String { t("Sign In with PIN", "الدخول بالرقم السري") }
    var pinTab: String { t("PIN", "رقم سري") }
    var passwordTab: String { t("Password", "كلمة مرور") }
    var quickCashierAccess: String { t("Quick cashier access", "وصول سريع للكاشير") }
    var loadingCashiers: String { t("Loading cashiers...", "جاري تحميل الكاشير...") }
    var managerApproval: String { t("Manager Approval", "اعتماد المدير") }
    var managerPin: String { t("Manager PIN", "الرقم السري للمدير") }
    var selectManager: String { t("Select manager", "اختر المدير") }
    var managerApprovalRequired: String { t("Manager approval is required for this action.", "هذه العملية تتطلب اعتماد المدير.") }
    var managerOnlyReports: String { t("Reports require manager access.", "التقارير تتطلب صلاحية المدير.") }
    var unlockReports: String { t("Unlock Reports", "فتح التقارير") }
    var approvedBy: String { t("Approved by", "اعتمد بواسطة") }
    var lastManagerApprovals: String { t("Recent Manager Approvals", "آخر اعتمادات المدير") }
    var noManagerApprovals: String { t("No manager approvals recorded yet.", "لا توجد اعتمادات مدير مسجلة بعد.") }
    var approvedAt: String { t("Approved at", "وقت الاعتماد") }

    // MARK: Tabs
    var tabPOS: String { t("POS", "نقطة البيع") }
    var tabOrders: String { t("Orders", "الطلبات") }
    var tabTables: String { t("Tables", "الطاولات") }
    var tabShift: String { t("Shift", "الوردية") }
    var tabReports: String { t("Reports", "التقارير") }
    var tabSettings: String { t("Settings", "الإعدادات") }

    func tabName(_ tab: String) -> String {
        switch tab.lowercased() {
        case "pos":          return tabPOS
        case "orders":       return tabOrders
        case "tables":       return tabTables
        case "shift":        return tabShift
        case "reports":      return tabReports
        case "inventory":    return tabInventory
        case "kds":          return tabKDS
        case "reservations": return tabReservations
        case "delivery":     return tabDelivery
        case "coupons":      return tabCoupons
        case "schedules":    return tabSchedules
        case "settings":     return tabSettings
        default:             return tab
        }
    }

    var tabInventory: String { t("Inventory", "المخزون") }
    var tabKDS: String { t("KDS", "شاشة المطبخ") }
    var tabReservations: String { t("Reservations", "الحجوزات") }
    var tabDelivery: String { t("Delivery", "التوصيل") }
    var tabCoupons: String { t("Coupons", "الكوبونات") }
    var tabSchedules: String { t("Schedules", "الجداول") }

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
    var sendToKitchen: String { t("Send to Kitchen", "إرسال للمطبخ") }
    var addExtras: String { t("Add extras", "إضافة مكوّنات") }
    var sentToKitchen: String { t("sent to kitchen", "أُرسل إلى المطبخ") }
    var kitchenRouteFailed: String { t("Kitchen routing failed", "فشل إرسال الطلب إلى المطبخ") }
    var paymentSuccessfulOrder: String { t("Payment successful! Order", "تمّ الدفع بنجاح! طلب") }
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
    var customerPhone: String { t("Customer phone", "هاتف العميل") }
    var lookupLoyalty: String { t("Lookup", "بحث") }
    var loyaltyCustomerLoaded: String { t("Loyalty customer loaded", "تم تحميل بيانات عميل الولاء") }
    var recentCustomers: String { t("Recent customers", "العملاء المتكررون") }
    var points: String { t("points", "نقطة") }
    var couponCode: String { t("Coupon Code", "كود الكوبون") }
    var enterCouponCode: String { t("Enter coupon code", "أدخل كود الكوبون") }
    var applyCoupon: String { t("Apply Coupon", "تطبيق الكوبون") }
    var removeCoupon: String { t("Remove Coupon", "إزالة الكوبون") }
    var couponInvalid: String { t("Coupon is invalid", "الكوبون غير صالح") }
    var addItemsBeforeCoupon: String { t("Add items before applying a coupon", "أضف عناصر قبل تطبيق الكوبون") }
    var enterCustomerPhone: String { t("Enter the customer's phone number", "أدخل رقم هاتف العميل") }
    func couponApplied(_ code: String) -> String { t("Coupon \(code) applied", "تم تطبيق الكوبون \(code)") }
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
    var cashDrop: String { t("Cash Drop", "سحب نقدي") }
    var cashDropAmount: String { t("Cash drop amount", "مبلغ السحب النقدي") }
    var recordCashDrop: String { t("Record Cash Drop", "تسجيل السحب النقدي") }
    var cashDropHistory: String { t("Cash Drop History", "سجل السحوبات النقدية") }
    var noCashDrops: String { t("No cash drops recorded", "لا توجد سحوبات نقدية مسجلة") }
    var closeShift: String { t("Close Shift", "إغلاق الوردية") }
    var closeShiftApproval: String { t("Approve shift closing", "اعتماد إغلاق الوردية") }
    var cashDropApproval: String { t("Approve cash drop", "اعتماد السحب النقدي") }
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
    func cashDropRecorded(_ amount: String) -> String { t("Cash drop recorded: \(amount)", "تم تسجيل سحب نقدي: \(amount)") }

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
    var cancelOrderApproval: String { t("Approve order cancellation", "اعتماد إلغاء الطلب") }
    var voidItem: String { t("Void Item", "إلغاء الصنف") }
    var voidItemApproval: String { t("Approve item void", "اعتماد إلغاء الصنف") }

    // MARK: Tables
    var tables: String { t("Tables", "الطاولات") }

    // MARK: Settings
    var settings: String { t("Settings", "الإعدادات") }
    var configurePos: String { t("Configure your POS", "إعدادات نقطة البيع") }
    var general: String { t("General", "عام") }
    var broadcasts: String { t("Broadcasts", "التنبيهات العامة") }
    var broadcastsInbox: String { t("Broadcast Inbox", "صندوق التنبيهات") }
    var noBroadcasts: String { t("No active broadcasts", "لا توجد تنبيهات عامة نشطة") }
    var dismiss: String { t("Dismiss", "إخفاء") }
    func unreadBroadcasts(_ count: Int) -> String { t("\(count) unread updates", "\(count) تحديثات غير مقروءة") }
    var viewBroadcasts: String { t("View Broadcasts", "عرض التنبيهات") }
    var managerConsoleLabel: String { t("MANAGER CONSOLE", "لوحة المدير") }
    var liveOperationsSnapshot: String { t("Live Operations Snapshot", "ملخص العمليات المباشر") }
    var needsAttention: String { t("Needs Attention", "يحتاج متابعة") }
    var operationsStableSummary: String { t("Operations look stable across shift, sync, and manager alerts.", "العمليات مستقرة حالياً عبر الوردية والمزامنة وتنبيهات الإدارة.") }
    var shiftCardTitle: String { t("Shift", "الوردية") }
    var shiftOpenStatus: String { t("Open", "مفتوحة") }
    var shiftClosedStatus: String { t("Closed", "مغلقة") }
    var needsAttentionShort: String { t("Needs attention", "تحتاج متابعة") }
    var queueLoadTitle: String { t("Queue Load", "ضغط الطلبات") }
    var queueLoadDetail: String { t("received/preparing/ready", "مستلم/تحضير/جاهز") }
    var offlineSyncTitle: String { t("Offline Sync", "مزامنة الأوفلاين") }
    var syncingNow: String { t("Syncing now", "تتم المزامنة الآن") }
    var syncStable: String { t("Stable", "مستقرة") }
    var reviewSync: String { t("Review sync", "راجع المزامنة") }
    var broadcastsCardTitle: String { t("Broadcasts", "التنبيهات العامة") }
    var noPendingNotices: String { t("No pending notices", "لا توجد تنبيهات معلقة") }
    var managerOverviewReady: String { t("Manager overview is current and ready for quick actions.", "ملخص المدير محدث وجاهز للإجراءات السريعة.") }
    var deviceOfflineMonitorQueue: String { t("Device is offline. Monitor pending sync queue closely.", "الجهاز غير متصل. راقب قائمة المزامنة المعلقة عن قرب.") }
    var noActiveShiftSummary: String { t("No active shift is open right now.", "لا توجد وردية نشطة مفتوحة حالياً.") }
    func activeOrdersNeedAttention(_ count: Int) -> String { t("\(count) active orders need service attention.", "هناك \(count) طلبات نشطة تحتاج متابعة الخدمة.") }
    func shiftReference(_ id: String) -> String { t("#\(id)", "#\(id)") }
    var noActiveShiftAlert: String { t("No active shift", "لا توجد وردية نشطة") }
    var deviceOfflineAlert: String { t("Device offline", "الجهاز غير متصل") }
    func pendingSyncOrdersAlert(_ count: Int) -> String { t("\(count) orders pending sync", "\(count) طلبات بانتظار المزامنة") }
    var offlineSyncNeedsAttentionAlert: String { t("Offline sync needs attention", "مزامنة الأوفلاين تحتاج متابعة") }
    func unreadBroadcastsAlert(_ count: Int) -> String { t("\(count) unread broadcasts", "\(count) تنبيهات غير مقروءة") }
    var pendingSyncQueue: String { t("Pending Sync Queue", "قائمة المزامنة المعلقة") }
    var noPendingOrders: String { t("No pending offline orders", "لا توجد طلبات أوفلاين معلقة") }
    var syncNow: String { t("Sync Now", "مزامنة الآن") }
    var lastSync: String { t("Last sync", "آخر مزامنة") }
    var syncFailed: String { t("Sync failed", "فشلت المزامنة") }
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
    var applyDiscountApproval: String { t("Approve discount", "اعتماد الخصم") }
    var removeDiscountApproval: String { t("Approve discount removal", "اعتماد حذف الخصم") }
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
    var exportReports: String { t("Export Reports", "تصدير التقارير") }
    var shareReports: String { t("Share Reports", "مشاركة التقارير") }
    var reportSummaryFile: String { t("report-summary.txt", "ملخص-التقارير.txt") }
    var reportCSVFile: String { t("report-data.csv", "بيانات-التقارير.csv") }
    var reportMetricsFile: String { t("report-metrics.csv", "مؤشرات-التقارير.csv") }
    var reportPaymentsFile: String { t("report-payments.csv", "مدفوعات-التقارير.csv") }
    var reportProductsFile: String { t("report-top-products.csv", "أفضل-المنتجات.csv") }
    var reportZATCAFile: String { t("report-zatca.csv", "تقارير-الزكاة.csv") }
    var reportTrendFile: String { t("report-trends.csv", "اتجاهات-التقارير.csv") }
    var reportOrderTypesFile: String { t("report-order-types.csv", "أنواع-الطلبات.csv") }

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
    var discountTypeAmount: String { t("Amount", "مبلغ") }
    var discountTypePercent: String { t("Percent", "نسبة") }
    var discountPercentPlaceholder: String { t("Discount percentage (0–100)", "نسبة الخصم (0–100)") }
    var invalidPercentage: String { t("Enter a percentage between 0 and 100", "أدخل نسبة بين 0 و 100") }
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

    // MARK: - Inventory
    var inventory: String { t("Inventory", "المخزون") }
    var inventorySubtitle: String { t("Manage raw materials, batches & recipes", "إدارة المواد الخام والدفعات والوصفات") }
    var rawMaterials: String { t("Raw Materials", "المواد الخام") }
    var batches: String { t("Batches", "الدفعات") }
    var recipes: String { t("Recipes", "الوصفات") }
    var addMaterial: String { t("Add Material", "إضافة مادة") }
    var editMaterial: String { t("Edit Material", "تعديل مادة") }
    var addBatch: String { t("Add Batch", "إضافة دفعة") }
    var rawMaterial: String { t("Raw Material", "المادة الخام") }
    var selectMaterial: String { t("Select Material", "اختر المادة") }
    var stock: String { t("Stock", "المخزون") }
    var currentStock: String { t("Current Stock", "المخزون الحالي") }
    var lowStockThreshold: String { t("Low Stock Threshold", "حد المخزون المنخفض") }
    var costPerUnit: String { t("Cost per Unit", "التكلفة لكل وحدة") }
    var batchNumber: String { t("Batch Number", "رقم الدفعة") }
    var expiryDate: String { t("Expiry Date", "تاريخ الانتهاء") }
    var selectProduct: String { t("Select a product to view its recipe", "اختر منتج لعرض وصفته") }
    var qty: String { t("Qty", "الكمية") }
    var expiry: String { t("Expiry", "الانتهاء") }
    var cost: String { t("Cost", "التكلفة") }
    var quantity: String { t("Quantity", "الكمية") }
    var unit: String { t("Unit", "الوحدة") }

    // MARK: - Coupons
    var coupons: String { t("Coupons", "الكوبونات") }
    var couponsSubtitle: String { t("Manage discount coupons", "إدارة كوبونات الخصم") }
    var addCoupon: String { t("Add Coupon", "إضافة كوبون") }
    var editCoupon: String { t("Edit Coupon", "تعديل كوبون") }
    var value: String { t("Value", "القيمة") }
    var description: String { t("Description", "الوصف") }
    var limits: String { t("Limits", "الحدود") }
    var minOrderValue: String { t("Min Order Value", "الحد الأدنى للطلب") }
    var maxDiscountAmount: String { t("Max Discount Amount", "الحد الأقصى للخصم") }
    var maxUses: String { t("Max Uses", "الحد الأقصى للاستخدام") }
    var validity: String { t("Validity", "الصلاحية") }
    var validFrom: String { t("Valid From", "صالح من") }
    var validUntil: String { t("Valid Until", "صالح حتى") }
    var active: String { t("Active", "نشط") }
    var inactive: String { t("Inactive", "غير نشط") }
    var usage: String { t("Usage", "الاستخدام") }
    var expires: String { t("Expires", "ينتهي") }

    // MARK: - KDS
    var kds: String { t("Kitchen Display", "شاشة المطبخ") }
    var kdsSubtitle: String { t("Live kitchen order queue", "قائمة طلبات المطبخ المباشرة") }
    var noKDSOrders: String { t("No orders in queue", "لا توجد طلبات في القائمة") }
    var stations: String { t("Stations", "المحطات") }
    var allStations: String { t("All Stations", "جميع المحطات") }
    var startPreparing: String { t("Start Preparing", "بدء التحضير") }
    var kitchenStations: String { t("Kitchen Stations", "محطات المطبخ") }
    var connecting: String { t("Connecting", "جارٍ الاتصال") }
    var retrying: String { t("Retrying", "إعادة المحاولة") }
    var pollingFallback: String { t("Polling", "استطلاع دوري") }
    func kdsRetryingRealtime(_ attempt: Int, _ max: Int) -> String { t("Realtime unavailable. Retrying \(attempt)/\(max)...", "الاتصال المباشر غير متاح. إعادة المحاولة \(attempt)/\(max)...") }
    var kdsRealtimeEndpointUnavailable: String { t("Realtime endpoint is not available on the server. Using polling.", "مسار التحديث المباشر غير متاح على الخادم. سيتم استخدام الاستطلاع الدوري.") }
    func kdsRealtimeUpgradeRejected(_ status: Int) -> String { t("Realtime upgrade failed with HTTP \(status). Using polling.", "فشل ترقية الاتصال المباشر برمز HTTP \(status). سيتم استخدام الاستطلاع الدوري.") }
    var kdsRealtimePollingFallback: String { t("Realtime is unavailable. Using polling fallback.", "التحديث المباشر غير متاح. سيتم استخدام الاستطلاع الدوري كخطة احتياط.") }
    var categories: String { t("Categories", "الفئات") }

    // MARK: - Reservations
    var reservations: String { t("Reservations", "الحجوزات") }
    var reservationsSubtitle: String { t("Manage table reservations", "إدارة حجوزات الطاولات") }
    var noReservations: String { t("No reservations found", "لا توجد حجوزات") }
    var addReservation: String { t("Add Reservation", "إضافة حجز") }
    var editReservation: String { t("Edit Reservation", "تعديل حجز") }
    var customerInfo: String { t("Customer Info", "معلومات العميل") }
    var date: String { t("Date", "التاريخ") }
    var time: String { t("Time", "الوقت") }
    var partySize: String { t("Party Size", "عدد الأشخاص") }
    var confirm: String { t("Confirm", "تأكيد") }
    var seat: String { t("Seat", "إجلاس") }
    var complete: String { t("Complete", "إكمال") }
    var edit: String { t("Edit", "تعديل") }
    var delete: String { t("Delete", "حذف") }

    // MARK: - Delivery
    var deliverySubtitle: String { t("Manage delivery partners & orders", "إدارة شركاء ومتطلبات التوصيل") }
    var deliveryOrders: String { t("Delivery Orders", "طلبات التوصيل") }
    var deliveryPartners: String { t("Delivery Partners", "شركاء التوصيل") }
    var noDeliveryOrders: String { t("No delivery orders", "لا توجد طلبات توصيل") }
    var addPartner: String { t("Add Partner", "إضافة شريك") }
    var editPartner: String { t("Edit Partner", "تعديل شريك") }
    var editDeliveryOrder: String { t("Edit Delivery Order", "تعديل طلب التوصيل") }
    var deliveryAddress: String { t("Delivery Address", "عنوان التوصيل") }
    var deliveryStatus: String { t("Delivery Status", "حالة التوصيل") }
    var selectPartner: String { t("Select Partner", "اختر الشريك") }
    var unassignedPartner: String { t("Unassigned", "غير معيّن") }
    var invalidDeliveryFee: String { t("Enter a valid delivery fee", "أدخل رسوم توصيل صحيحة") }
    var deliveryOrderUpdated: String { t("Delivery order updated", "تم تحديث طلب التوصيل") }
    var partnerSaved: String { t("Partner saved", "تم حفظ الشريك") }
    var vehicleLabel: String { t("Vehicle Label", "وصف المركبة") }
    var fee: String { t("Fee", "الرسوم") }

    // MARK: - Staff Schedules
    var staffSchedules: String { t("Staff Schedules", "جداول الموظفين") }
    var staffSchedulesSubtitle: String { t("Manage staff shifts & days off", "إدارة ورديات الموظفين وأيام الإجازة") }
    var noSchedules: String { t("No schedules for this date", "لا توجد جداول لهذا التاريخ") }
    var addSchedule: String { t("Add Schedule", "إضافة جدول") }
    var editSchedule: String { t("Edit Schedule", "تعديل جدول") }
    var bulkSchedule: String { t("Bulk Schedule", "جدولة متعددة") }
    var staffMember: String { t("Staff Member", "الموظف") }
    var selectStaff: String { t("Select Staff", "اختر الموظف") }
    var dayOff: String { t("Day Off", "يوم إجازة") }
    var shiftStart: String { t("Shift Start", "بداية الوردية") }
    var shiftEnd: String { t("Shift End", "نهاية الوردية") }
    var scheduleRange: String { t("Schedule Range", "نطاق الجدولة") }
    var fromDate: String { t("From Date", "من تاريخ") }
    var toDate: String { t("To Date", "إلى تاريخ") }
    var applyOnDays: String { t("Apply On Days", "تطبيق على الأيام") }
    var scheduleBranchRequired: String { t("Your account must be linked to a branch before creating schedules", "يجب ربط الحساب بفرع قبل إنشاء الجداول") }
    var completeScheduleFields: String { t("Select staff, date, and shift times first", "اختر الموظف والتاريخ وأوقات الوردية أولاً") }
    var invalidScheduleRange: String { t("End date must be the same as or after the start date", "يجب أن يكون تاريخ النهاية بعد أو مساوياً لتاريخ البداية") }
    var selectAtLeastOneScheduleDay: String { t("Select at least one weekday", "اختر يوماً واحداً على الأقل") }
    var noMatchingScheduleDates: String { t("No matching dates were generated for the selected range", "لم يتم توليد تواريخ مطابقة للنطاق المحدد") }
    var scheduleSaved: String { t("Schedule saved", "تم حفظ الجدول") }
    func bulkSchedulesCreated(_ count: Int) -> String { t("Created \(count) schedule entries", "تم إنشاء \(count) من الجداول") }

    // MARK: - 2FA & Auth
    var twoFactorAuth: String { t("Two-Factor Authentication", "المصادقة الثنائية") }
    var twoFactorSubtitle: String { t("Add an extra layer of security to your account", "أضف طبقة أمان إضافية لحسابك") }
    var enable2FA: String { t("Enable 2FA", "تفعيل المصادقة الثنائية") }
    var disable2FA: String { t("Disable 2FA", "تعطيل المصادقة الثنائية") }
    var scanQRCode: String { t("Scan this QR code with your authenticator app", "امسح رمز QR بتطبيق المصادقة") }
    var enterTOTPCode: String { t("Enter the 6-digit code from your authenticator app", "أدخل الرمز المكون من 6 أرقام من تطبيق المصادقة") }
    var totpCode: String { t("TOTP Code", "رمز المصادقة") }
    var verify: String { t("Verify", "تحقق") }
    var twoFAEnabled: String { t("2FA is enabled", "المصادقة الثنائية مفعّلة") }
    var twoFADisabled: String { t("2FA is disabled", "المصادقة الثنائية معطّلة") }
    var twoFARequired: String { t("Two-factor authentication required", "المصادقة الثنائية مطلوبة") }
    var twoFASetupSuccess: String { t("2FA enabled successfully", "تم تفعيل المصادقة الثنائية بنجاح") }
    var twoFADisableSuccess: String { t("2FA disabled successfully", "تم تعطيل المصادقة الثنائية بنجاح") }
    var secretKey: String { t("Secret Key", "المفتاح السري") }
    var confirmPasswordToDisable2FA: String { t("Confirm your current password to disable 2FA", "أكد كلمة المرور الحالية لتعطيل المصادقة الثنائية") }
    var currentPasswordRequired: String { t("Enter your current password", "أدخل كلمة المرور الحالية") }

    // MARK: - Change Password
    var changePassword: String { t("Change Password", "تغيير كلمة المرور") }
    var currentPassword: String { t("Current Password", "كلمة المرور الحالية") }
    var newPassword: String { t("New Password", "كلمة المرور الجديدة") }
    var confirmPassword: String { t("Confirm Password", "تأكيد كلمة المرور") }
    var passwordChanged: String { t("Password changed successfully", "تم تغيير كلمة المرور بنجاح") }
    var passwordsDoNotMatch: String { t("Passwords do not match", "كلمات المرور غير متطابقة") }

    // MARK: - Loyalty
    var loyaltyPoints: String { t("Loyalty Points", "نقاط الولاء") }
    var earnPoints: String { t("Earn Points", "كسب النقاط") }
    var redeemPoints: String { t("Redeem Points", "استبدال النقاط") }
    var pointsBalance: String { t("Points Balance", "رصيد النقاط") }
    var pointsToRedeem: String { t("Points to Redeem", "النقاط المراد استبدالها") }
    var redeemAsDiscount: String { t("Redeem as Discount", "استبدال كخصم") }
    var pointsEarned: String { t("Points earned successfully", "تم كسب النقاط بنجاح") }
    var pointsRedeemed: String { t("Points redeemed successfully", "تم استبدال النقاط بنجاح") }
    var insufficientPoints: String { t("Insufficient points", "نقاط غير كافية") }
    var loyaltyDiscount: String { t("Loyalty Discount", "خصم الولاء") }

    // MARK: - Product Availability
    var toggleAvailability: String { t("Toggle Availability", "تبديل التوفر") }
    var markUnavailable: String { t("Mark Unavailable", "تحديد غير متوفر") }
    var markAvailable: String { t("Mark Available", "تحديد متوفر") }
    var productUnavailable: String { t("Product marked as unavailable", "تم تحديد المنتج كغير متوفر") }
    var productAvailable: String { t("Product marked as available", "تم تحديد المنتج كمتوفر") }

    // MARK: - Reports (Extended)
    var dailyReport: String { t("Daily Report", "التقرير اليومي") }
    var monthlyReport: String { t("Monthly Report", "التقرير الشهري") }
    var profitabilityReport: String { t("Profitability", "الربحية") }
    var ordersReport: String { t("Orders Report", "تقرير الطلبات") }
    var revenue: String { t("Revenue", "الإيرادات") }
    var profit: String { t("Profit", "الربح") }
    var expenses: String { t("Expenses", "المصروفات") }
    var netIncome: String { t("Net Income", "صافي الدخل") }
    var margin: String { t("Margin", "الهامش") }
    var productName: String { t("Product", "المنتج") }
    var unitsSold: String { t("Units Sold", "الوحدات المباعة") }
    var selectDate: String { t("Select Date", "اختر التاريخ") }
    var reportDate: String { t("Report Date", "تاريخ التقرير") }
    var totalRevenueLbl: String { t("Total Revenue", "إجمالي الإيرادات") }
    var totalCost: String { t("Total Cost", "إجمالي التكلفة") }
    var totalProfit: String { t("Total Profit", "إجمالي الربح") }
    var accountingOverview: String { t("Accounting Overview", "ملخص المحاسبة") }
    var taxableSales: String { t("Taxable Sales", "المبيعات الخاضعة للضريبة") }
    var exemptSales: String { t("Exempt Sales", "المبيعات المعفاة") }
    var zeroRatedSales: String { t("Zero-Rated Sales", "المبيعات بنسبة صفرية") }
    var trialBalance: String { t("Trial Balance", "ميزان المراجعة") }
    var balanceSheet: String { t("Balance Sheet", "الميزانية العمومية") }
    var journalEntries: String { t("Journal Entries", "قيود اليومية") }
    var generalLedger: String { t("General Ledger", "دفتر الأستاذ") }
    var selectAccount: String { t("Select Account", "اختر الحساب") }
    var reference: String { t("Reference", "المرجع") }
    var noAccountingData: String { t("No accounting data available for this range", "لا توجد بيانات محاسبية متاحة لهذه الفترة") }
    var assets: String { t("Assets", "الأصول") }
    var liabilities: String { t("Liabilities", "الخصوم") }
    var equity: String { t("Equity", "حقوق الملكية") }
    var account: String { t("Account", "الحساب") }
    var debit: String { t("Debit", "مدين") }
    var credit: String { t("Credit", "دائن") }
    var balance: String { t("Balance", "الرصيد") }

    // MARK: - Tables (Extended)
    var addTable: String { t("Add Table", "إضافة طاولة") }
    var editTable: String { t("Edit Table", "تعديل الطاولة") }
    var deleteTable: String { t("Delete Table", "حذف الطاولة") }
    var tableNumber: String { t("Table Number", "رقم الطاولة") }
    var section: String { t("Section", "القسم") }
    var capacity: String { t("Capacity", "السعة") }
    var ringBell: String { t("Ring Bell", "رنين الجرس") }
    var bellRung: String { t("Bell rung for table", "تم رنين الجرس للطاولة") }
    var viewQR: String { t("View QR", "عرض QR") }
    var tableDeleted: String { t("Table deleted", "تم حذف الطاولة") }
    var tableUpdated: String { t("Table updated", "تم تحديث الطاولة") }

    // MARK: - Staff CRUD
    var editStaff: String { t("Edit Staff", "تعديل موظف") }
    var deleteStaff: String { t("Delete Staff", "حذف موظف") }
    var email: String { t("Email", "البريد الإلكتروني") }
    var role: String { t("Role", "الدور") }
    var pin: String { t("PIN", "الرقم السري") }
    var permissions: String { t("Permissions", "الصلاحيات") }
    var staffCreated: String { t("Staff member created", "تم إنشاء الموظف") }
    var staffUpdated: String { t("Staff member updated", "تم تحديث الموظف") }
    var staffDeleted: String { t("Staff member deactivated", "تم تعطيل الموظف") }
    var resetPIN: String { t("Reset PIN", "إعادة تعيين الرقم السري") }
    var pinUpdated: String { t("PIN updated", "تم تحديث الرقم السري") }

    // MARK: - Subscription
    var subscription: String { t("Subscription", "الاشتراك") }
    var subscriptionSubtitle: String { t("Your plan & usage details", "تفاصيل خطتك واستخدامك") }
    var currentPlan: String { t("Current Plan", "الخطة الحالية") }
    var branches: String { t("Branches", "الفروع") }
    var users: String { t("Users", "المستخدمين") }
    var products_l10n: String { t("Products", "المنتجات") }
    var used: String { t("Used", "مستخدم") }
    var of_l10n: String { t("of", "من") }

    // MARK: - Common
    var details: String { t("Details", "التفاصيل") }
    var nameAr: String { t("Name (Arabic)", "الاسم بالعربي") }
    var nameEn: String { t("Name (English)", "الاسم بالإنجليزي") }
    var name: String { t("Name", "الاسم") }
    var phone: String { t("Phone", "الهاتف") }
    var notes: String { t("Notes", "ملاحظات") }
    var done: String { t("Done", "تم") }
    var serverLogout: String { t("Logout from server", "تسجيل خروج من الخادم") }
}
