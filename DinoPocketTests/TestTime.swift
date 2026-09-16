import Foundation

/// Kalender, locale, dan "sekarang" yang tetap, supaya test waktu tidak
/// bergantung pada zona waktu atau jam mesin yang menjalankannya.
///
/// Asia/Jakarta dipilih karena tidak punya daylight saving: satu hari
/// selalu 24 jam, sehingga "besok jam 9" tidak pernah bergeser.
enum TestTime {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    static let locale = Locale(identifier: "en_US")

    /// Rabu, 16 September 2026, 10.00 WIB.
    static let now = date(2026, 9, 16, 10, 0)

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
