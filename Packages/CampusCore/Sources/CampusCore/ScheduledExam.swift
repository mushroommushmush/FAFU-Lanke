import Foundation

public struct ScheduledExam: Sendable {
    public let record: TableRecord
    public let slot: Lesson

    public func countdown(at now: Date) -> String {
        guard now < slot.end else { return "已结束" }
        guard now < slot.start else { return "考试中" }
        let seconds = slot.start.timeIntervalSince(now)
        if seconds >= 86400 {
            let hours = Int(seconds / 3600)
            return "\(hours / 24)天\(hours % 24)小时"
        }
        if seconds >= 3600 {
            let minutes = Int(seconds / 60)
            return "\(minutes / 60)小时\(minutes % 60)分钟"
        }
        return "\(max(1, Int(ceil(seconds / 60))))分钟"
    }

    private static let pattern = try! NSRegularExpression(pattern: #"^\s*([0-9]{4})\s*[年./-]\s*([0-9]{1,2})\s*[月./-]\s*([0-9]{1,2})\s*日?\s*[（(]?\s*([0-9]{1,2})\s*[:：]\s*([0-9]{2})\s*[-－–—~～至]\s*([0-9]{1,2})\s*[:：]\s*([0-9]{2})\s*[）)]?\s*$"#)

    public init?(record: TableRecord) {
        let source = record.value(["考试时间", "时间"])
        guard let match = Self.pattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) else { return nil }
        let text = source as NSString
        let values = (1..<match.numberOfRanges).compactMap { Int(text.substring(with: match.range(at: $0))) }
        guard values.count == 7 else { return nil }

        let calendar = SchoolSchedule.calendar
        let date = DateComponents(year: values[0], month: values[1], day: values[2])
        guard date.isValidDate(in: calendar), let midnight = calendar.date(from: date),
              (0..<24).contains(values[3]), (0..<60).contains(values[4]),
              (0..<24).contains(values[5]), (0..<60).contains(values[6]) else { return nil }
        let start = midnight.addingTimeInterval(Double(values[3] * 60 + values[4]) * 60)
        let end = midnight.addingTimeInterval(Double(values[5] * 60 + values[6]) * 60)
        guard end > start else { return nil }

        self.record = record
        self.slot = Lesson(id: "exam-" + record.id, name: record.title,
                           room: record.value(["考试地点", "考试教室", "考场", "地点"]),
                           start: start, end: end, manual: false)
    }
}

public enum RecordOrdering {
    public static func sorted(_ records: [TableRecord], byScore: Bool, ascending: Bool) -> [TableRecord] {
        // Preserve school order for ties and keep unknown values last in either direction.
        let keyed = records.enumerated().map { index, record in
            let value = byScore
                ? Double(record.value(["成绩", "总评成绩"]).trimmingCharacters(in: .whitespacesAndNewlines))
                : ScheduledExam(record: record)?.slot.start.timeIntervalSince1970
            return (index: index, record: record, value: value.flatMap { $0.isFinite ? $0 : nil })
        }
        return keyed.sorted { lhs, rhs in
            switch (lhs.value, rhs.value) {
            case let (a?, b?) where a != b: return ascending ? a < b : a > b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.index < rhs.index
            }
        }.map(\.record)
    }
}
