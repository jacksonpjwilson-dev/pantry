import Foundation
import Security

/// Explicit configuration only. No private food data enters this adapter.
actor TelemetryAdapter {
    enum Status { case disconnected, configured, delivered }
    private(set) var status: Status = .disconnected
    private var endpoint: URL?
    func configure(endpoint: URL, token: String) throws {
        guard endpoint.scheme == "https", endpoint.user == nil, endpoint.password == nil, !token.isEmpty else { throw InventoryErrorBridge.message("Head Quarter requires HTTPS and an access token") }
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Pantry.HeadQuarter", kSecAttrAccount as String: "token"]
        SecItemDelete(base as CFDictionary)
        var insert = base; insert[kSecValueData as String] = Data(token.utf8); insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw InventoryErrorBridge.message("Head Quarter token could not be stored securely") }
        self.endpoint = endpoint; status = .configured
    }
    func send(_ report: HealthReport) async throws {
        guard let endpoint else { throw InventoryErrorBridge.message("Head Quarter is disconnected") }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Pantry.HeadQuarter", kSecAttrAccount as String: "token", kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else { throw InventoryErrorBridge.message("Head Quarter credential unavailable") }
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization"); request.httpBody = try JSONEncoder().encode(report)
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw InventoryErrorBridge.message("Head Quarter did not accept the health report") }
        status = .delivered
    }
}
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
