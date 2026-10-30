import Foundation

public struct Student: Codable, Equatable, Sendable {
    public let account: String
    public let name: String
    public init(account: String, name: String) { self.account = account; self.name = name }
}
public struct SelectOption: Codable, Hashable, Identifiable, Sendable {
    public let value: String
    public let label: String
    public var id: String { value }
    public init(value: String, label: String) { self.value = value; self.label = label }
}
public struct Semester: Codable, Equatable, Sendable {
    public let year: String
    public let term: String
    public var title: String { year.isEmpty ? "当前学期" : "\(year) · 第\(term)学期" }
    public init(year: String, term: String) { self.year = year; self.term = term }
}
public struct PageOptions: Codable, Sendable {
    public let years: [SelectOption]
    public let terms: [SelectOption]
    public let selected: Semester
    public init(years: [SelectOption], terms: [SelectOption], selected: Semester) {
        self.years = years; self.terms = terms; self.selected = selected
    }
}
public struct CourseCell: Codable, Identifiable, Sendable {
    public let id: String
    /// Monday = 1, Sunday = 7. Preserve source text, including week restrictions.
    public let weekday: Int
    public let period: String
    public let content: String
    public init(id: String, weekday: Int, period: String, content: String) {
        self.id = id; self.weekday = weekday; self.period = period; self.content = content
    }
}
public struct TableField: Codable, Equatable, Sendable {
    public let label: String
    public let value: String
    public init(label: String, value: String) { self.label = label; self.value = value }
}
public struct TableRecord: Codable, Identifiable, Sendable {
    public let id: String
    public let fields: [TableField]
    public init(id: String, fields: [TableField]) { self.id = id; self.fields = fields }
    public func value(_ labels: [String]) -> String {
        fields.first { labels.contains($0.label) }?.value ?? ""
    }
    public var title: String {
        let name = value(["课程名称", "考试课程", "课程"])
        return name.isEmpty ? (fields.first?.value ?? "未命名记录") : name
    }
}
public struct TimetableReport: Codable, Sendable {
    public let courses: [CourseCell]
    public let adjustments: String
    public let options: PageOptions
    public let fetchedAt: Date
    public init(courses: [CourseCell], adjustments: String, options: PageOptions, fetchedAt: Date = Date()) {
        self.courses = courses; self.adjustments = adjustments; self.options = options; self.fetchedAt = fetchedAt
    }
}
public struct RecordsReport: Codable, Sendable {
    public let records: [TableRecord]
    public let options: PageOptions
    public let fetchedAt: Date
    public init(records: [TableRecord], options: PageOptions, fetchedAt: Date = Date()) {
        self.records = records; self.options = options; self.fetchedAt = fetchedAt
    }
}
public struct CampusSnapshot: Codable, Sendable {
    public let schemaVersion: Int
    public let student: Student
    public var timetable: TimetableReport?
    public var grades: RecordsReport?
    public var exams: RecordsReport?
    public init(student: Student) { schemaVersion = 1; self.student = student }
}
public enum CampusError: LocalizedError, Equatable, Sendable {
    case message(String), sessionExpired, unexpectedPage(String), invalidEncoding, invalidDestination
    public var errorDescription: String? {
        switch self {
        case .message(let message): return message
        case .sessionExpired: return "登录已过期，请重新登录。已下载的数据仍可离线查看。"
        case .unexpectedPage(let page): return "未能识别\(page)页面，学校可能调整了页面结构。请使用“教务原网页”核对。"
        case .invalidEncoding: return "无法处理教务系统的中文编码，请检查输入。"
        case .invalidDestination: return "教务系统跳转到了其他地址，已停止发送请求。请检查学校是否更换了入口。"
        }
    }
}
