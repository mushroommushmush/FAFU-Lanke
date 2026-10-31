import Foundation

public struct Lesson: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var room: String
    public var start: Date
    public var end: Date
    public var detail: String
    public var manual: Bool
    public init(id: String = UUID().uuidString, name: String, room: String, start: Date, end: Date, detail: String = "", manual: Bool = true) {
        self.id = id; self.name = name; self.room = room; self.start = start; self.end = end; self.detail = detail; self.manual = manual
    }
    public enum Phase: Equatable { case upcoming, soon, active, ended }
    public func phase(at now: Date) -> Phase {
        if now >= end { return .ended }
        if now >= start { return .active }
        return start.timeIntervalSince(now) <= 900 ? .soon : .upcoming
    }
}

public enum SchoolSchedule {
    public static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; c.firstWeekday = 2
        return c
    }
    public static let starts = [480, 530, 595, 645, 695, 840, 890, 950, 1000, 1105, 1155, 1205]
    public static func classroom(in lines: [String]) -> String {
        for line in lines.reversed() {
            // Course-change identifiers such as (换0420) are not room names.
            let cleaned = line.replacingOccurrences(of: "[（(]换[^）)]*[）)]", with: "", options: .regularExpression)
            let rooms = matches("(?<![\\p{Han}0-9])([\\p{Han}]\\s*[0-9]+(?:[-－][0-9]+)?)", cleaned)
            if let room = rooms.map({ $0[1] }).first(where: { !["换", "第", "周", "节"].contains(String($0.prefix(1))) }) {
                return room.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            }
        }
        return ""
    }
    public static func updateAge(_ date: Date, now: Date) -> String {
        let age = max(0, now.timeIntervalSince(date))
        if age > 30 * 86400 { return "更新于很久之前" }
        if age >= 86400 { return "更新于\(Int(age / 86400))天前" }
        return "更新于\(Int(age / 60))分钟前"
    }
    public static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    public static func dayKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    public static func monday(_ date: Date) -> Date {
        let offset = (calendar.component(.weekday, from: date) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: date))!
    }
    public static func week(on date: Date, beginning: Date) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: beginning), to: calendar.startOfDay(for: date)).day ?? 0
        return Int(floor(Double(days) / 7)) + 1
    }
    private static func matches(_ pattern: String, _ text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }
    public static func includes(week: Int, text: String) -> Bool {
        guard week > 0 else { return false }
        let ranges = matches("第?([0-9]+)(?:[-－—]([0-9]+))?周", text.replacingOccurrences(of: " ", with: ""))
        guard !ranges.isEmpty else { return false } // Unknown recurrence must not generate false reminders.
        let contains = ranges.contains { row in
            guard let a = Int(row[1]), let b = Int(row[2].isEmpty ? row[1] : row[2]), a <= b else { return false }
            return (a...b).contains(week)
        }
        return contains && (!text.contains("单") || week % 2 == 1) && (!text.contains("双") || week % 2 == 0)
    }
    public static func lessons(report: TimetableReport?, on date: Date, beginning: Date, starts: [Int] = starts) -> [Lesson] {
        guard let report, starts.count == 12 else { return [] }
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        let week = week(on: date, beginning: beginning)
        let midnight = calendar.startOfDay(for: date)
        var result: [Lesson] = []
        for cell in report.courses where cell.weekday == weekday {
            let lines = cell.content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let scheduleIndices = lines.indices.filter { lines[$0].contains("周") && !matches("[0-9]+", lines[$0]).isEmpty }
            for (offset, index) in scheduleIndices.enumerated() {
                let schedule = lines[index]
                guard index > 0, includes(week: week, text: schedule) else { continue }
                let periodMatch = matches("第([0-9,，、-]+)节", schedule).first
                let periodText = periodMatch?[1] ?? cell.period
                let numbers = matches("[0-9]+", periodText).compactMap { Int($0[0]) }
                guard let first = numbers.min(), let last = numbers.max(), first >= 1, last <= 12 else { continue }
                let next = offset + 1 < scheduleIndices.count ? scheduleIndices[offset + 1] - 1 : lines.count
                let tail = index + 1 < next ? Array(lines[(index + 1)..<next]) : []
                let room = classroom(in: tail)
                let start = calendar.date(byAdding: .minute, value: starts[first - 1], to: midnight)!
                let end = calendar.date(byAdding: .minute, value: starts[last - 1] + 45, to: midnight)!
                guard end > start else { continue }
                let name = lines[index - 1]
                let key = [report.options.selected.title, String(weekday), name, schedule, room, dayKey(date)].joined(separator: "|")
                result.append(Lesson(id: key, name: name, room: room, start: start, end: end, detail: ([name, schedule] + tail).joined(separator: "\n"), manual: false))
            }
        }
        return result.sorted { $0.start < $1.start }
    }
}
