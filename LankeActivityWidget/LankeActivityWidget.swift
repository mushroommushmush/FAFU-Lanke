import WidgetKit
import SwiftUI
import ActivityKit

private let lessonYellow = Color(red: 250/255, green: 192/255, blue: 61/255)
private let lessonGreen = Color(red: 192/255, green: 214/255, blue: 150/255)

private func clock(_ date: Date) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
    let c = calendar.dateComponents([.hour, .minute], from: date)
    return String(format: "%d:%02d", c.hour!, c.minute!)
}
private func courseTime(_ state: LessonActivity.ContentState) -> String { clock(state.start) + "-" + clock(state.end) }

struct LessonTimer: View {
    let state: LessonActivity.ContentState
    let active: Bool
    var body: some View {
        Text(timerInterval: active ? state.start...state.end : state.start.addingTimeInterval(-900)...state.start,
             countsDown: true, showsHours: false)
            .monospacedDigit().multilineTextAlignment(.trailing)
    }
}

private struct LessonSummary: View {
    let state: LessonActivity.ContentState
    let active: Bool
    let expanded: Bool
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                (Text(state.name).foregroundColor(.white) + Text(" @" + (state.room.isEmpty ? "待确认" : state.room)).foregroundColor(lessonYellow))
                    .font(expanded ? .subheadline.weight(.semibold) : .headline)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                LessonTimer(state: state, active: active)
                    .font(.system(size: expanded ? 30 : 36, weight: .light, design: .rounded))
                    .frame(width: expanded ? 96 : 112, alignment: .trailing)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(active ? lessonGreen : lessonYellow)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(courseTime(state)).frame(maxWidth: .infinity, alignment: .leading)
                Text(active ? "距下课还有" : "距上课还有").multilineTextAlignment(.trailing)
            }.font(.caption).foregroundStyle(.white)
        }
    }
}

struct LessonLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivity.self) { context in
            let active = context.state.hasStarted || (context.isStale && Date() >= context.state.start)
            LessonSummary(state: context.state, active: active, expanded: false)
                .padding(.horizontal, 24).padding(.vertical, 20)
                .activityBackgroundTint(.black).activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            let active = context.state.hasStarted || (context.isStale && Date() >= context.state.start)
            return DynamicIsland {
                // Keep every expanded element below the camera, out of the rounded upper wings.
                DynamicIslandExpandedRegion(.bottom) {
                    LessonSummary(state: context.state, active: active, expanded: true)
                        .padding(.horizontal, 8).padding(.top, 8).padding(.bottom, 12)
                }
            } compactLeading: {
                Text(String(context.state.name.prefix(4))).font(.caption).lineLimit(1)
                    .foregroundStyle(active ? lessonGreen : lessonYellow)
            } compactTrailing: {
                Group {
                    if active { LessonTimer(state: context.state, active: true) }
                    else { Text(context.state.room.isEmpty ? "待确认" : context.state.room) }
                }.font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 46, alignment: .trailing)
                    .foregroundStyle(active ? lessonGreen : lessonYellow)
            } minimal: {
                Image(systemName: "book.closed.fill").foregroundStyle(active ? lessonGreen : lessonYellow)
            }
            .contentMargins(.all, 24, for: .expanded)
            .contentMargins(.leading, 8, for: .compactLeading)
            .contentMargins(.trailing, 8, for: .compactTrailing)
        }
    }
}

@main struct LankeWidgets: WidgetBundle {
    var body: some Widget { LessonLiveWidget() }
}
