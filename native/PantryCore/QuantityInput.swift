import Foundation

public enum QuantityInput {
    /// Parse the complete field, never just a numeric prefix such as "150" in "150 g".
    /// Grouping separators are rejected rather than guessed; the device decimal separator is honored.
    public static func parse(_ raw: String, locale: Locale = .current) -> Decimal? {
        let separator = locale.decimalSeparator ?? "."
        var normalized = ""
        for character in raw.trimmingCharacters(in: .whitespacesAndNewlines) {
            if String(character) == separator { normalized.append(".") }
            else if character == "." && separator != "." { return nil }
            else if let digit = character.wholeNumberValue, (0...9).contains(digit) { normalized.append(String(digit)) }
            else { normalized.append(character) }
        }
        let pattern = #"^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#
        guard normalized.range(of: pattern, options: .regularExpression) != nil,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return nil }
        return value
    }
    public static func formatted(_ value: Decimal, locale: Locale = .current) -> String {
        NSDecimalNumber(decimal: value).stringValue.replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}
