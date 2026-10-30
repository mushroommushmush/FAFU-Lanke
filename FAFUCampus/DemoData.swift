import Foundation
import CampusCore

enum DemoData {
    static var snapshot: CampusSnapshot {
        var result = CampusSnapshot(student: Student(account: "示例账号", name: "同学"))
        let options = PageOptions(years: [SelectOption(value: "2026-2027", label: "2026-2027")],
            terms: [SelectOption(value: "1", label: "1")], selected: Semester(year: "2026-2027", term: "1"))
        result.timetable = TimetableReport(courses: [
            CourseCell(id: "a", weekday: 1, period: "第1节 · 第2节", content: "植物学（示例）\n第1-16周\n示例教师 · 示例教室"),
            CourseCell(id: "b", weekday: 1, period: "第3节 · 第4节", content: "大学英语（示例）\n第1-16周，单周\n示例教师 · 示例教室"),
            CourseCell(id: "c", weekday: 3, period: "第5节 · 第6节", content: "高等数学（示例）\n第1-16周\n示例教师 · 示例教室")
        ], adjustments: "此处展示学校页面中的调课、停课、补课说明。示例内容不代表实际教学安排。", options: options)
        result.grades = RecordsReport(records: [
            TableRecord(id: "1", fields: [TableField(label: "课程名称", value: "植物学（示例）"), TableField(label: "成绩", value: "92"), TableField(label: "学分", value: "3.0"), TableField(label: "学年", value: "2026-2027"), TableField(label: "学期", value: "1")]),
            TableRecord(id: "2", fields: [TableField(label: "课程名称", value: "大学英语（示例）"), TableField(label: "成绩", value: "优秀"), TableField(label: "学分", value: "2.0"), TableField(label: "学年", value: "2026-2027"), TableField(label: "学期", value: "1")])
        ], options: options)
        result.exams = RecordsReport(records: [TableRecord(id: "1", fields: [
            TableField(label: "课程名称", value: "高等数学（示例）"), TableField(label: "考试时间", value: "时间以学校发布为准"),
            TableField(label: "考试地点", value: "示例考场"), TableField(label: "座位号", value: "12")])], options: options)
        return result
    }
}
