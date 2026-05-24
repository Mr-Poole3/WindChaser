import Foundation

enum MetricFormatter {
    static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func distance(kilometers: Double) -> String {
        if kilometers >= 100 {
            return "\(Int(kilometers.rounded()))"
        }
        return String(format: "%.1f", kilometers)
    }

    static func distanceUnit(kilometers: Double) -> String {
        "km"
    }

    static func speed(kmh: Double?, isValid: Bool = true) -> String {
        guard isValid, let kmh else { return "--" }
        if kmh < 1.5 { return "<1.5" }
        return String(format: "%.1f", kmh)
    }

    static func speedUnit(kmh: Double?, isValid: Bool = true) -> String {
        guard isValid, let kmh, kmh >= 1.5 else { return kmh == nil || !isValid ? "" : "km/h" }
        return "km/h"
    }

    static func heartRate(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    static func cadence(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    static func power(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)"
    }

    static func altitude(meters: Double?) -> String {
        guard let meters else { return "--" }
        return abbreviatedInteger(meters)
    }

    static func grade(percent: Double?) -> String {
        guard let percent else { return "--" }
        return String(format: "%+.1f", percent)
    }

    static func calories(_ value: Int) -> String {
        abbreviatedInteger(Double(value))
    }

    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }

    private static func abbreviatedInteger(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded >= 10_000 {
            return String(format: "%.1fk", Double(rounded) / 1_000)
        }
        return "\(rounded)"
    }
}
