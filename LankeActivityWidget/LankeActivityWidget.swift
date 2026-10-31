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
            .monospacedDigit()
    }
}

struct LessonLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LessonActivity.self) { context in
            let active = context.state.hasStarted || (context.isStale && Date() >= context.state.start)
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.state.name).font(.headline).lineLimit(2)
                    Text("@" + (context.state.room.isEmpty ? "教室待确认" : context.state.room)).foregroundStyle(lessonYellow)
                    Text(courseTime(context.state)).font(.subheadline)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    LessonTimer(state: context.state, active: active)
                        .font(.system(size: 36, weight: .light, design: .rounded))
                        .frame(width: 130, alignment: .trailing).minimumScaleFactor(0.7)
                    Text(active ? "距离下课还有" : "距离上课还有").font(.caption)
                }.foregroundStyle(lessonGreen)
            }.padding(18).activityBackgroundTint(.black).activitySystemActionForegroundColor(.white).foregroundStyle(.white)
        } dynamicIsland: { context in
            let active = context.state.hasStarted || (context.isStale && Date() >= context.state.start)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(context.state.name).font(.headline).foregroundStyle(lessonGreen).lineLimit(2) }
                DynamicIslandExpandedRegion(.trailing) { Text("@" + context.state.room).foregroundStyle(lessonYellow).lineLimit(1) }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(courseTime(context.state)).font(.subheadline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            LessonTimer(state: context.state, active: active).font(.system(size: 28, weight: .light, design: .rounded)).frame(width: 110, alignment: .trailing)
                            Text(active ? "距离下课还有" : "距离上课还有").font(.caption)
                        }.foregroundStyle(lessonGreen)
                    }.padding(.top, 4)
                }
            } compactLeading: {
                Text(String(context.state.name.prefix(4))).font(.caption).lineLimit(1)
                    .foregroundStyle(active ? lessonGreen : lessonYellow)
            } compactTrailing: {
                Group {
                    if active { LessonTimer(state: context.state, active: true) }
                    else { Text(context.state.room.isEmpty ? "待确认" : context.state.room) }
                }.font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 46, alignment: .trailing).clipped()
                    .foregroundStyle(active ? lessonGreen : lessonYellow)
            } minimal: {
                Image(systemName: "book.closed.fill").foregroundStyle(active ? lessonGreen : lessonYellow)
            }
        }
    }
}

@main struct LankeWidgets: WidgetBundle {
    var body: some Widget { LessonLiveWidget() }
}
