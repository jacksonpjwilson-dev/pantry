import Foundation

public struct OfflineMutation: Codable, Identifiable {
    public var id = UUID().uuidString
    public var itemID: String
    public var payload: Data
    public var create: Bool
    public init(itemID: String, payload: Data, create: Bool) { self.itemID = itemID; self.payload = payload; self.create = create }
}
