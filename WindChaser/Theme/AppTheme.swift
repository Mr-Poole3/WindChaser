import SwiftUI

enum ThemePalette: Equatable {
    case dayLight
    case nightDark

    var panelBackground: Color {
        switch self {
        case .dayLight:
            Color(red: 0.97, green: 0.97, blue: 0.99)
        case .nightDark:
            Color(red: 0.04, green: 0.04, blue: 0.05)
        }
    }

    var cardBackground: Color {
        switch self {
        case .dayLight:
            .white
        case .nightDark:
            Color(red: 0.09, green: 0.09, blue: 0.11)
        }
    }

    var primaryText: Color {
        switch self {
        case .dayLight:
            Color(red: 0.05, green: 0.05, blue: 0.07)
        case .nightDark:
            Color(red: 0.97, green: 0.97, blue: 0.99)
        }
    }

    var secondaryText: Color {
        switch self {
        case .dayLight:
            Color(red: 0.39, green: 0.45, blue: 0.55)
        case .nightDark:
            Color(red: 0.58, green: 0.64, blue: 0.72)
        }
    }

    var borderColor: Color {
        switch self {
        case .dayLight:
            Color.black.opacity(0.06)
        case .nightDark:
            Color.white.opacity(0.08)
        }
    }

    var handleColor: Color {
        switch self {
        case .dayLight:
            Color.black.opacity(0.12)
        case .nightDark:
            Color.white.opacity(0.16)
        }
    }

    var accentColor: Color {
        switch self {
        case .dayLight:
            Color(red: 1.0, green: 0.35, blue: 0.12)
        case .nightDark:
            Color(red: 0.0, green: 0.98, blue: 0.57)
        }
    }

    var mapStyle: MapStyleChoice {
        switch self {
        case .dayLight:
            .standard
        case .nightDark:
            .muted
        }
    }
}

enum MapStyleChoice {
    case standard
    case muted
}

enum RideButtonStyle {
    static let pause = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let pauseForeground = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let resume = Color(red: 0.66, green: 0.90, blue: 0.63)
    static let resumeForeground = Color(red: 0.12, green: 0.28, blue: 0.10)
    static let end = Color(red: 0.91, green: 0.36, blue: 0.36)
    static let endForeground = Color.white
    static let routeOrange = Color.orange
}

enum SolarTheme {
    static func palette(at date: Date = .now, latitude: Double = 39.9042, longitude: Double = 116.4074) -> ThemePalette {
        isDaytime(at: date, latitude: latitude, longitude: longitude) ? .dayLight : .nightDark
    }

    static func isDaytime(at date: Date, latitude: Double, longitude: Double) -> Bool {
        let sunrise = solarEvent(on: date, latitude: latitude, longitude: longitude, sunrise: true)
        let sunset = solarEvent(on: date, latitude: latitude, longitude: longitude, sunrise: false)
        return date >= sunrise && date < sunset
    }

    private static func solarEvent(on date: Date, latitude: Double, longitude: Double, sunrise: Bool) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let dayStart = calendar.startOfDay(for: date)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1

        let latRad = latitude * .pi / 180
        let declinationRad = 23.45 * .pi / 180 * sin((360.0 / 365.0 * (Double(dayOfYear) - 81)) * .pi / 180)
        let hourAngle = acos(max(-1, min(1, -tan(latRad) * tan(declinationRad))))
        let solarOffsetHours = sunrise ? -hourAngle * 12 / .pi : hourAngle * 12 / .pi
        let timezoneOffset = Double(TimeZone.current.secondsFromGMT(for: date)) / 3_600
        let solarNoon = 12 - longitude / 15 + timezoneOffset
        let eventHour = solarNoon + solarOffsetHours

        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        let hour = Int(eventHour)
        let minute = Int((eventHour - Double(hour)) * 60)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? dayStart
    }
}
