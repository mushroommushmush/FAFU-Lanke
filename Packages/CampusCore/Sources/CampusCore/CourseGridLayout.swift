import Foundation

public struct CourseGridPlacement: Equatable, Sendable {
    public let column: Int
    public let columns: Int
}

public enum CourseGridLayout {
    public static func unique(_ lessons: [Lesson]) -> [Lesson] {
        var seen: Set<String> = []
        return lessons.filter { seen.insert($0.id).inserted }
    }
    public static func placements(_ lessons: [Lesson]) -> [String: CourseGridPlacement] {
        let sorted = unique(lessons).sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        var groups: [[Lesson]] = []
        var end = Date.distantPast
        for lesson in sorted {
            if groups.isEmpty || lesson.start >= end {
                groups.append([lesson]); end = lesson.end
            } else {
                groups[groups.count - 1].append(lesson); end = max(end, lesson.end)
            }
        }
        var result: [String: CourseGridPlacement] = [:]
        for group in groups {
            var ends: [Date] = [], indices: [String: Int] = [:]
            for lesson in group {
                let index = ends.firstIndex { $0 <= lesson.start } ?? ends.count
                if index == ends.count { ends.append(lesson.end) } else { ends[index] = lesson.end }
                indices[lesson.id] = index
            }
            for lesson in group {
                result[lesson.id] = CourseGridPlacement(column: indices[lesson.id] ?? 0, columns: max(1, ends.count))
            }
        }
        return result
    }
}
