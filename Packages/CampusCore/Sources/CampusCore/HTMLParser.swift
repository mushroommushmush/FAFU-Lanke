import Foundation
import SwiftSoup

public enum HTMLParser {
    public static func hiddenFields(_ html: String) throws -> [String: String] {
        let document = try SwiftSoup.parse(html)
        var fields: [String: String] = [:]
        for input in try document.select("input[type=hidden]").array() {
            let name = try input.attr("name")
            if !name.isEmpty { fields[name] = try input.attr("value") }
        }
        return fields
    }
    public static func loginAction(_ html: String) throws -> String {
        try SwiftSoup.parse(html).select("form").first()?.attr("action") ?? ""
    }
    public static func loginFields(_ html: String) throws -> [String: String] {
        var fields = try hiddenFields(html)
        let document = try SwiftSoup.parse(html)
        // Only the clicked submit control belongs in a browser form submission.
        // FAFU uses Button1 for login and Button2 for clearing/resetting the form.
        // Sending both can run the reset handler and return the login page.
        for input in try document.select("input[type=submit][name=Button1]:not([disabled]), input[type=radio][checked]:not([disabled])").array() {
            let name = try input.attr("name")
            if !name.isEmpty { fields[name] = try input.attr("value") }
        }
        // Prefer the student role if the page provides one.
        for input in try document.select("input[name=RadioButtonList1]").array() {
            let value = try input.attr("value")
            if value.contains("学生") { fields["RadioButtonList1"] = value }
        }
        return fields
    }
    public static func studentName(_ html: String) throws -> String? {
        let document = try SwiftSoup.parse(html)
        guard let element = try document.getElementById("xhxm") else { return nil }
        let text = try element.text().replacingOccurrences(of: "同学", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
    public static func alertMessage(_ html: String) -> String? {
        let pattern = #"alert\s*\(\s*['"]([^'"]+)['"]\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }
    public static func requireAuthenticated(_ html: String) throws {
        let document = try SwiftSoup.parse(html)
        if !(try document.select("input[name=txtUserName], input[name=TextBox2]")).isEmpty() {
            throw CampusError.sessionExpired
        }
        if let message = alertMessage(html) {
            if message.contains("登录") || message.contains("登陆") { throw CampusError.sessionExpired }
            throw CampusError.message(message)
        }
        let text = try document.text()
        if text.contains("请重新登陆") || text.contains("请重新登录") || text.contains("请先登录") {
            throw CampusError.sessionExpired
        }
    }
    public static func options(_ html: String) throws -> PageOptions {
        let document = try SwiftSoup.parse(html)
        func read(_ selector: String) throws -> ([SelectOption], String) {
            guard let select = try document.select(selector).first() else { return ([], "") }
            var result: [SelectOption] = []; var selected: String?
            for option in try select.select("option").array() {
                let label = try option.text()
                let value = option.hasAttr("value") ? try option.attr("value") : label
                if !result.contains(where: { $0.value == value }) { result.append(SelectOption(value: value, label: label)) }
                if option.hasAttr("selected") { selected = value }
            }
            return (result, selected ?? result.first?.value ?? "")
        }
        let years = try read("select[name=xnd], select[name=ddlxn]")
        let terms = try read("select[name=xqd], select[name=ddlxq]")
        return PageOptions(years: years.0, terms: terms.0, selected: Semester(year: years.1, term: terms.1))
    }
    public static func records(_ html: String, page: String) throws -> RecordsReport {
        try requireAuthenticated(html)
        let document = try SwiftSoup.parse(html)
        guard let table = try document.select("table[id=Datagrid1], table[id=DataGrid1], table[id=datagrid1]").first() else {
            let text = try document.text()
            if ["暂无成绩", "暂无考试", "没有考试安排", "无考试安排", "没有符合条件"].contains(where: text.contains) {
                return RecordsReport(records: [], options: try options(html))
            }
            throw CampusError.unexpectedPage(page)
        }
        let rows = try table.select("tr").array()
        var headers: [String] = []; var items: [TableRecord] = []
        for (index, row) in rows.enumerated() {
            let cells = row.children().array().filter { ["td", "th"].contains($0.tagName().lowercased()) }
            let values = try cells.map { try $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }
            if headers.isEmpty {
                if values.contains(where: { ["课程名称", "考试课程", "课程"].contains($0) }) { headers = values }
                continue
            }
            if values == headers { continue }
            guard values.count == headers.count else {
                let text = values.joined()
                if text.isEmpty || ["暂无", "没有符合", "无记录", "没有考试", "无考试"].contains(where: text.contains) { continue }
                throw CampusError.unexpectedPage(page)
            }
            if values.allSatisfy({ $0.isEmpty }) { continue }
            let fields = zip(headers, values).map { TableField(label: $0.0, value: $0.1) }
            items.append(TableRecord(id: "row-\(index)", fields: fields))
        }
        guard !headers.isEmpty else { throw CampusError.unexpectedPage(page) }
        return RecordsReport(records: items, options: try options(html))
    }

    private struct GridCell {
        let row: Int; let column: Int; let rowspan: Int; let text: String
    }
    private static func lines(_ cell: Element) throws -> String {
        let html = try cell.html().replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
        let document = try SwiftSoup.parseBodyFragment(html)
        return try document.text(trimAndNormaliseWhitespace: false)
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }
    public static func timetable(_ html: String) throws -> TimetableReport {
        try requireAuthenticated(html)
        let document = try SwiftSoup.parse(html)
        guard let table = try document.getElementById("Table1") else { throw CampusError.unexpectedPage("课表") }
        let rows = try table.select("tr").array()
        var grid: [[Int: GridCell]] = Array(repeating: [:], count: rows.count)
        var origins: [GridCell] = []
        for (rowIndex, row) in rows.enumerated() {
            var column = 0
            for cell in row.children().array().filter({ ["td", "th"].contains($0.tagName().lowercased()) }) {
                while grid[rowIndex][column] != nil { column += 1 }
                let rowspan = max(1, min(100, Int(try cell.attr("rowspan")) ?? 1))
                let colspan = max(1, min(20, Int(try cell.attr("colspan")) ?? 1))
                let item = GridCell(row: rowIndex, column: column, rowspan: rowspan, text: try lines(cell))
                origins.append(item)
                for r in rowIndex..<min(rows.count, rowIndex + rowspan) {
                    for c in column..<(column + colspan) { grid[r][c] = item }
                }
                column += colspan
            }
        }
        let dayNames = ["一", "二", "三", "四", "五", "六", "日"]
        var dayColumns: [Int: Int] = [:]; var headerRow = -1
        for cell in origins {
            let text = cell.text.replacingOccurrences(of: " ", with: "")
            for (index, day) in dayNames.enumerated() {
                if ["星期\(day)", "周\(day)", "礼拜\(day)"].contains(text) || (index == 6 && text == "星期天") {
                    dayColumns[cell.column] = index + 1; headerRow = max(headerRow, cell.row)
                }
            }
        }
        guard dayColumns.count >= 5, let firstDayColumn = dayColumns.keys.min() else {
            throw CampusError.unexpectedPage("课表列标题")
        }
        var courses: [CourseCell] = []
        for cell in origins where cell.row > headerRow {
            guard let weekday = dayColumns[cell.column], !cell.text.isEmpty else { continue }
            if ["上午", "下午", "晚上", "中午"].contains(cell.text) { continue }
            var periods: [String] = []
            for r in cell.row..<min(grid.count, cell.row + cell.rowspan) {
                for c in 0..<firstDayColumn {
                    if let label = grid[r][c]?.text, label.contains("节"), !periods.contains(label) { periods.append(label) }
                }
            }
            let period = periods.isEmpty ? "节次见课程详情" : periods.joined(separator: " · ")
            courses.append(CourseCell(id: "\(cell.row)-\(cell.column)", weekday: weekday, period: period, content: cell.text))
        }
        // Preserve adjustment notices instead of guessing how to merge canceled/moved sessions.
        let adjustments = try document.getElementById("DBGrid").map { try lines($0) } ?? ""
        return TimetableReport(courses: courses, adjustments: adjustments, options: try options(html))
    }
}
