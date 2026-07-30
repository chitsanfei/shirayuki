import Foundation

/// Parses PicACG timestamps and produces localized relative dates.
nonisolated enum AppRelativeTime {
    /// Formats a raw timestamp relative to a reference date.
    static func string(
        from rawValue: String,
        relativeTo referenceDate: Date = Date(),
        locale: Locale = .current
    ) -> String {
        guard let date = parse(rawValue) else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: referenceDate)
    }

    /// Parses fractional ISO-8601, standard ISO-8601, or date-only values.
    static func parse(_ rawValue: String) -> Date? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: value)
    }
}
