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
    public var electives: RecordsReport?
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

/// Search only user-visible local records, never credentials or authentication material.
public struct AppSearchEntry: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let route: String
    public let fields: [TableField]
    public let keywords: String
    public var subtitle: String { fields.map { $0.value }.filter { !$0.isEmpty && $0 != title }.joined(separator: " · ") }
    public func matches(_ query: String) -> Bool {
        let text = ([title, category, keywords] + fields.flatMap { [$0.label, $0.value] }).joined(separator: " ")
        return query.split(whereSeparator: { $0.isWhitespace }).allSatisfy { text.localizedCaseInsensitiveContains(String($0)) }
    }
}
public enum AppSearchIndex {
    public static func entries(snapshot: CampusSnapshot?, manual: [Lesson], hidden: Set<String> = []) -> [AppSearchEntry] {
        let features: [(String, String, String)] = [
            ("我的课表", "schedule", "课程表 日程 列表 表格"),
            ("我的成绩", "grades", "分数 成绩查询 绩点 学分"),
            ("考试安排", "exams", "考试时间 考场 座位号"),
            ("我的", "account", "个人信息 学号 姓名 登录 自动登录 记住密码 恢复连接 刷新全部数据 离线缓存 清除数据 退出账号"),
            ("课表设置", "settings", "列表 表格 周数 开学日期 作息 上课时间 实时活动 灵动岛"),
            ("学分（选修）查询", "electives", "培养计划 通识 任意选修课 自然科学 文学 艺术 体育 人文 创新创业"),
            ("添加课程", "add", "手动 临时课程 新增"),
            ("教务原网页", "portal", "学校网站 登录 修改密码"),
            ("关于览课", "about", "版本 隐私 说明")
        ]
        var result = features.map { AppSearchEntry(id: "feature-" + $0.1, title: $0.0, category: "功能", route: $0.1, fields: [], keywords: $0.2) }
        guard let snapshot else { return result }
        result.append(AppSearchEntry(id: "student", title: snapshot.student.name, category: "个人信息", route: "account",
            fields: [TableField(label: "学号", value: snapshot.student.account)], keywords: "姓名 学号"))
        for course in snapshot.timetable?.courses ?? [] {
            result.append(AppSearchEntry(id: "course-" + course.id, title: course.content.components(separatedBy: .newlines).first ?? "课程", category: "课表", route: "record",
                fields: [TableField(label: "课程名称", value: course.content.components(separatedBy: .newlines).first ?? "课程"), TableField(label: "星期", value: "周" + String(course.weekday)), TableField(label: "节次", value: course.period), TableField(label: "学校原始信息", value: course.content)], keywords: "课程 教室 教师 周次"))
        }
        if let adjustment = snapshot.timetable?.adjustments, !adjustment.isEmpty {
            result.append(AppSearchEntry(id: "adjustments", title: "调停课说明", category: "调停课说明", route: "record", fields: [TableField(label: "学校原始说明", value: adjustment)], keywords: "调课 停课 补课"))
        }
        for lesson in manual where !hidden.contains(lesson.id) {
            result.append(AppSearchEntry(id: "manual-" + lesson.id, title: lesson.name, category: "手动课程", route: "manual", fields: [TableField(label: "教室", value: lesson.room), TableField(label: "开始", value: lesson.start.formatted(date: .numeric, time: .shortened)), TableField(label: "结束", value: lesson.end.formatted(date: .numeric, time: .shortened)), TableField(label: "详情", value: lesson.detail)], keywords: "临时课程"))
        }
        for (category, report) in [("成绩", snapshot.grades), ("考试", snapshot.exams), ("选修学分", snapshot.electives)] {
            for record in report?.records ?? [] {
                result.append(AppSearchEntry(id: category + "-" + record.id, title: record.title, category: category, route: "record", fields: record.fields, keywords: ""))
            }
        }
        return result
    }
}
