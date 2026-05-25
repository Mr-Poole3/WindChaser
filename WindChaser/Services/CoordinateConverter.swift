import CoreLocation

/// Converts WGS-84 GPS coordinates to GCJ-02 for MapKit display in mainland China.
/// CoreLocation returns WGS-84; Apple Maps tiles in China use GCJ-02, which causes ~50–500 m offset without conversion.
enum CoordinateConverter {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    static func isInChina(latitude: Double, longitude: Double) -> Bool {
        longitude >= 72.004 && longitude <= 137.8347
            && latitude >= 0.8293 && latitude <= 55.8271
    }

    static func wgs84ToGcj02(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        guard isInChina(latitude: latitude, longitude: longitude) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        let offset = gcj02Offset(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2D(
            latitude: latitude + offset.lat,
            longitude: longitude + offset.lon
        )
    }

    private static func gcj02Offset(latitude: Double, longitude: Double) -> (lat: Double, lon: Double) {
        var dLat = transformLat(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLon(x: longitude - 105.0, y: latitude - 35.0)
        let radLat = latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)
        return (dLat, dLon)
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}
