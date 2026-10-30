import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

struct StopLessonActivity: LiveActivityIntent {
    static var title: LocalizedStringResource = "结束课程实时活动"
    func perform() async throws -> some IntentResult {
        for activity in Activity<LessonActivity>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        return .result()
    }
}

private let lessonYellow = Color(red: 250/255, green: 192/255, blue: 61/255)
private let lessonGreen = Color(red: 192/255, green: 214/255, blue: 150/255)

struct ActivityPart: View {
    let state: LessonActivity.ContentState
    let leading: Bool
    var body: some View {
        TimelineView(.periodic(from: state.start.addingTimeInterval(-900), by: 30)) { context in
            let active = context.date >= state.start
            Group {
                if context.date >= state.end { Text(leading ? String(state.name.prefix(4)) : "已下课") }
                else if leading { Text(String(state.name.prefix(4))) }
                else if active { Text(timerInterval: state.start...state.end, countsDown: true).monospacedDigit().frame(maxWidth: 65) }
                else { Text(state.room.isEmpty ? "待确认" : state.room) }
            }.font(.caption).foregroundStyle(active ? lessonGreen : lessonYellow).lineLimit(1)
        }
    }
}

struct LessonLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivity.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Text(context.state.name).font(.headline)
                HStack {
                    Text("@" + context.state.room)
                    Spacer()
                    ActivityPart(state: context.state, leading: false)
                }
                Text(context.state.start, style: .time) + Text(" — ") + Text(context.state.end, style: .time)
                Button(intent: StopLessonActivity()) { Label("结束", systemImage: "xmark.circle") }
            }.padding().activityBackgroundTint(.black).activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.state.name).foregroundStyle(lessonGreen) }
                DynamicIslandExpandedRegion(.trailing) { Text("@" + context.state.room).foregroundStyle(lessonYellow) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack { ActivityPart(state: context.state, leading: false); Spacer(); Button(intent: StopLessonActivity()) { Text("结束") } }
                }
            } compactLeading: {
                ActivityPart(state: context.state, leading: true)
            } compactTrailing: {
                ActivityPart(state: context.state, leading: false)
            } minimal: {
                Image(systemName: "book.closed.fill").foregroundStyle(lessonGreen)
            }
        }
    }
}

@main struct LankeWidgets: WidgetBundle {
    var body: some Widget { LessonLiveWidget() }
}
