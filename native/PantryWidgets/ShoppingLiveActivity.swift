import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

struct ShoppingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShoppingActivity.self) { context in
            VStack(alignment: .leading) {
                Text(context.attributes.listName).font(.headline)
                Text("\(context.state.completed) of \(context.state.total) bought")
                ProgressView(value: Double(context.state.completed), total: Double(max(1, context.state.total)))
                Button(intent: FinishShoppingSessionIntent()) { Text("Finish shopping") }
            }.padding().widgetURL(URL(string: "pantry://shopping"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Groceries", systemImage: "cart") }
                DynamicIslandExpandedRegion(.trailing) { Text("\(max(0, context.state.total - context.state.completed)) left") }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack { Text(context.attributes.startedAt, style: .timer); Spacer(); Button(intent: FinishShoppingSessionIntent()) { Text("Finish") } }
                }
            } compactLeading: { Image(systemName: "cart") } compactTrailing: { Text("\(max(0, context.state.total - context.state.completed))") } minimal: { Image(systemName: "cart") }
            .widgetURL(URL(string: "pantry://shopping"))
        }
    }
}
