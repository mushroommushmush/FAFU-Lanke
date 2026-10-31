import Foundation

public struct HomeWidgetLesson: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var room: String
    public var start: Date
    public var end: Date
    public init(_ lesson: Lesson) {
        id = lesson.id; name = lesson.name; room = lesson.room; start = lesson.start; end = lesson.end
    }
    public init(id: String, name: String, room: String, start: Date, end: Date) {
        self.id = id; self.name = name; self.room = room; self.start = start; self.end = end
    }
}

public struct HomeWidgetSnapshot: Codable, Equatable, Sendable {
    public var lessons: [HomeWidgetLesson]
    public var sourceUpdatedAt: Date?
    public var coverageStart: Date?
    public var coverageEnd: Date?
    public init(lessons: [HomeWidgetLesson], sourceUpdatedAt: Date?, coverageStart: Date? = nil, coverageEnd: Date? = nil) {
        self.lessons = lessons.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        self.sourceUpdatedAt = sourceUpdatedAt
        self.coverageStart = coverageStart; self.coverageEnd = coverageEnd
    }
    public func covers(_ date: Date) -> Bool {
        (coverageStart == nil || date >= coverageStart!) && (coverageEnd == nil || date < coverageEnd!)
    }
    public func today(at date: Date) -> [HomeWidgetLesson] {
        lessons.filter { SchoolSchedule.calendar.isDate($0.start, inSameDayAs: date) }
    }
    public func next(at date: Date) -> HomeWidgetLesson? { today(at: date).first { $0.end > date } }
    public func timelineDates(after date: Date) -> [Date] {
        var dates: Set<Date> = [date]
        for lesson in lessons {
            for boundary in [lesson.start.addingTimeInterval(-900), lesson.start, lesson.end] where boundary > date {
                dates.insert(boundary)
            }
        }
        for offset in 1...7 {
            dates.insert(SchoolSchedule.calendar.date(byAdding: .day, value: offset, to: SchoolSchedule.calendar.startOfDay(for: date))!)
        }
        return dates.sorted().prefix(150).map { $0 }
    }
}
