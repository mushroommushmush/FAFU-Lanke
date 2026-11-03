import Foundation
import SwiftSoup

public struct ProfessionalPage: Sendable {
    public static let keys = ["xn", "xq", "nj", "xy", "zy", "kb"]
    public let options: [String: [SelectOption]]
    public let selected: [String: String]
    public let fields: [String: String]
    public let action: String
    public let report: TimetableReport?
    public var title: String {
        let group = options["kb"]?.first { $0.value == selected["kb"] }?.label ?? ""
        return group.isEmpty ? "班级课表" : group
    }
}

public struct SavedProfessionalTimetable: Codable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let selection: [String: String]
    public let report: TimetableReport
    public var displayTitle: String { title.components(separatedBy: " · ").last ?? title }
    public init(id: String = UUID().uuidString, page: ProfessionalPage) throws {
        guard let report = page.report, !(page.selected["kb"] ?? "").isEmpty else { throw CampusError.message("请选择推荐课表并等待查询完成。") }
        self.id = id; title = page.title; selection = page.selected; self.report = report
    }
}

extension HTMLParser {
    public static func professional(_ html: String) throws -> ProfessionalPage {
        try requireAuthenticated(html)
        let doc = try SwiftSoup.parse(html)
        var options: [String: [SelectOption]] = [:], selected: [String: String] = [:]
        var fields = try hiddenFields(html)
        for key in ProfessionalPage.keys {
            guard let element = try doc.select("select[name=\(key)]").first() else { throw CampusError.unexpectedPage("专业课表筛选") }
            let items = try element.select("option").array().filter { !$0.hasAttr("disabled") }
            options[key] = try items.map { SelectOption(value: try $0.attr("value"), label: try $0.text()) }
            selected[key] = try (items.first { $0.hasAttr("selected") } ?? items.first)?.attr("value") ?? ""
            fields[key] = selected[key]
        }
        let action = try doc.select("form").first()?.attr("action") ?? ""
        var report: TimetableReport?
        if try doc.getElementById("Table6") != nil {
            report = try timetable(html, tableID: "Table6", pageOptions: PageOptions(years: options["xn"] ?? [], terms: options["xq"] ?? [], selected: Semester(year: selected["xn"] ?? "", term: selected["xq"] ?? "")))
        }
        return ProfessionalPage(options: options, selected: selected, fields: fields, action: action, report: report)
    }
}
