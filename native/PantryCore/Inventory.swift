import Foundation

public enum InventoryError: LocalizedError {
    case invalidQuantity, incompatibleUnits, missingItem, conflict, verificationRequired
    public var errorDescription: String? {
        switch self {
        case .invalidQuantity: return "The quantity is invalid or exceeds supported precision. Enter a finite amount; existing stock must be nonnegative."
        case .incompatibleUnits: return "These units cannot be converted without a verified serving or density relationship."
        case .missingItem: return "This item no longer exists. Refresh inventory and review the pending operation."
        case .conflict: return "A record changed or an operation identifier conflicts. Refresh and review the pending changes."
        case .verificationRequired: return "Confirm a compatible measurement or a positive verified serving relationship."
        }
    }
}
public enum Measures {
    // Exact decimal strings, matching the production engine (including its 240 ml cup).
    public static let units = ["count", "g", "kg", "oz", "lb", "ml", "L", "fl oz", "cup", "tbsp", "tsp"]
    private static let factors: [String: (String, String)] = ["g":("mass","1"),"kg":("mass","1000"),"mg":("mass","0.001"),"oz":("mass","28.349523125"),"lb":("mass","453.59237"),"ml":("volume","1"),"L":("volume","1000"),"fl oz":("volume","29.5735295625"),"cup":("volume","240"),"tbsp":("volume","14.78676478125"),"tsp":("volume","4.92892159375")]
    public static func convert(_ amount: Decimal, from: String, to: String) throws -> Decimal {
        guard amount >= 0 else { throw InventoryError.invalidQuantity }
        if from == to && units.contains(from) { return amount }
        guard let a = factors[from], let b = factors[to], a.0 == b.0 else { throw InventoryError.incompatibleUnits }
        let converted = amount * Decimal(string: a.1)! / Decimal(string: b.1)!
        guard !converted.isNaN else { throw InventoryError.invalidQuantity }
        return converted
    }
    public static func rounded(_ amount: Decimal) -> Decimal { var input = amount; var output = Decimal(); NSDecimalRound(&output, &input, 3, .plain); return output }
}
public struct InventoryItem: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var qty: Decimal
    public var unit: String
    public var category: String
    public var lowAt: Decimal?
    public var barcode: String?
    public var brand: String?
    public var purchaseDate: Date?
    public var expirationDate: Date?
    public var dateKind: String?
    public var location: String?
    public var notes: String?
    public var imageURL: String?
    public var createdAt: Double
    public var updatedAt: Double
    public var status: String { qty <= 0 ? "out" : lowAt.map { qty <= $0 ? "low" : "ok" } ?? "ok" }
    public init(id: String = UUID().uuidString, name: String, qty: Decimal = 0, unit: String = "count", category: String = "Pantry", lowAt: Decimal? = nil) {
        self.id = id; self.name = name; self.qty = qty; self.unit = unit; self.category = category; self.lowAt = lowAt
        createdAt = Date().timeIntervalSince1970 * 1000; updatedAt = createdAt
    }
}
public struct Adjustment: Codable, Identifiable {
    public var id: String
    public var itemId: String
    public var delta: Decimal
    public var reason: String
    public init(id: String = "m_" + UUID().uuidString, itemId: String, delta: Decimal, reason: String) { self.id = id; self.itemId = itemId; self.delta = delta; self.reason = reason }
    public func apply(to before: Decimal) throws -> (after: Decimal, applied: Decimal, unfulfilled: Decimal) {
        guard before >= 0, !delta.isNaN else { throw InventoryError.invalidQuantity }
        let requested = Measures.rounded(delta), sum = before + requested
        guard !requested.isNaN, !sum.isNaN else { throw InventoryError.invalidQuantity }
        let after = max(0, Measures.rounded(sum))
        return (after, after - before, requested - (after - before))
    }
}
public struct ShoppingItem: Codable, Identifiable, Equatable {
    public var id = UUID().uuidString
    public var name: String
    public var itemId: String?
    public var quantity: Decimal = 1
    public var category = "Other"
    public var priority = 0
    public var list = "Groceries"
    public var purchased = false
    public var addedToInventory = false
    public init(name: String, itemId: String? = nil, quantity: Decimal = 1) { self.name = name; self.itemId = itemId; self.quantity = quantity }
    public var purchaseOperationID: String { "purchase_" + id }
}
public enum LegacyIdentity {
    public static func hash(_ value: String) -> String {
        var h: UInt32 = 2166136261, h2: UInt32 = 5381
        for character in value.utf16 { h = (h ^ UInt32(character)) &* 16777619; h2 = (h2 &* 33) ^ UInt32(character) }
        return String(h, radix: 36) + String(h2, radix: 36)
    }
    public static func ledgerID(_ kind: String, key: String) -> String { kind + "_" + hash(key) }
}
public enum Expiry {
    public static func upcoming(_ item: InventoryItem, now: Date, days: Int, calendar: Calendar = .current) -> Bool {
        guard item.qty > 0, let expiry = item.expirationDate, let end = calendar.date(byAdding: .day, value: days, to: now) else { return false }
        return expiry <= end
    }
}
public struct HealthReport: Codable {
    public var version: String
    public var lastSuccessfulSync: Date?
    public var firebase: String
    public var logbook: String
    public var failedOperations: Int
    public var configurationIssues: [String]
    // Deliberately no inventory, user identifiers or food source payloads.
}
