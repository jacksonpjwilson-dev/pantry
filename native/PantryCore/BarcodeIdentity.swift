import Foundation

public enum BarcodeIdentity {
    /// UPC-A is commonly returned by Apple's scanners as EAN-13 with a leading zero.
    /// Keep stored values intact; normalize only for comparison.
    public static func canonical(_ raw: String) -> String {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.utf8.count == 12 && code.utf8.allSatisfy({ (48...57).contains($0) }) { return "0" + code }
        return code
    }
    public static func matches(_ stored: String?, _ scanned: String) -> Bool {
        guard let stored else { return false }
        let left = canonical(stored), right = canonical(scanned)
        return !left.isEmpty && !right.isEmpty && left == right
    }
}
