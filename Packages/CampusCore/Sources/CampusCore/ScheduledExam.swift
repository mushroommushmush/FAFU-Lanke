import Foundation

public struct ScheduledExam: Sendable {
    public let record: TableRecord
    public let slot: Lesson

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
