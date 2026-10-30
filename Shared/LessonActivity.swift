import ActivityKit
import Foundation

struct LessonActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var room: String
        var start: Date
        var end: Date
    }
    var lessonID: String
    var account: String
}
