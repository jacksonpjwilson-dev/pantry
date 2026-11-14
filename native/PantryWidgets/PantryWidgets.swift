import SwiftUI
import WidgetKit
import AppIntents

struct Snapshot: TimelineEntry {
    var date: Date
    var low: Int
    var shopping: Int
    var expiry: Int
    var inbox: Int
    var updated: Date?
    var detail: WidgetSnapshot? = nil
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Snapshot { Snapshot(date: Date(), low: 0, shopping: 0, expiry: 0, inbox: 0, updated: nil) }
    func getSnapshot(in context: Context, completion: @escaping (Snapshot) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Snapshot>) -> Void) { completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(1800)))) }
    func read() -> Snapshot {
        let defaults = WidgetStorage.defaults
        return Snapshot(date: Date(), low: defaults?.integer(forKey: "low") ?? 0, shopping: defaults?.integer(forKey: "shopping") ?? 0, expiry: defaults?.integer(forKey: "expiry") ?? 0, inbox: defaults?.integer(forKey: "inbox") ?? 0, updated: defaults?.object(forKey: "updated") as? Date, detail: WidgetStorage.snapshot())
    }
}
struct Overview: View {
    var entry: Snapshot
    var kind: String
    @Environment(\.widgetFamily) var family
    var count: Int { kind == "shopping" ? entry.shopping : kind == "expiry" ? entry.expiry : kind == "inbox" ? entry.inbox : kind == "recent" ? entry.detail?.recentlyEaten.count ?? 0 : entry.low }
    var title: String { kind == "shopping" ? "To buy" : kind == "expiry" ? "Dates soon" : kind == "inbox" ? "To link" : kind == "recent" ? "Recently eaten" : "Low stock" }
    var icon: String { kind == "shopping" ? "cart" : kind == "expiry" ? "calendar" : kind == "inbox" ? "link" : "leaf" }
    var destination: URL? {
        let path: String
        switch kind {
        case "shopping": path = "shopping"
        case "inbox": path = "inbox"
        case "expiry": path = "inventory?filter=expiry"
        case "recent": path = "home?view=recent"
        case "sync": path = "settings"
        default: path = "inventory?filter=low"
        }
        return URL(string: "pantry://" + path)
    }
    var body: some View {
        Group {
            if kind == "sync" {
                VStack { Image(systemName: "arrow.triangle.2.circlepath"); Text(entry.detail?.syncStatus ?? "Open Pantry").font(.caption).lineLimit(2)
                    if family == .systemMedium || family == .systemLarge, let last = entry.detail?.lastSuccessfulSync { Text(last, style: .relative).font(.caption) }
                }
            } else if family == .accessoryInline { Text("\(title): \(count)") }
            else if family == .accessoryCircular { Gauge(value: Double(count), in: 0...Double(max(1, count))) { Image(systemName: icon) } currentValueLabel: { Text("\(count)") } }
            else {
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: icon).font(.headline)
                    Text(entry.updated == nil ? "—" : "\(count)").font(family == .systemSmall ? .largeTitle.bold() : .title2.bold())
                    if family == .systemMedium || family == .systemLarge {
                        if let snapshot = entry.detail {
                            let rows = kind == "shopping" ? snapshot.shopping : kind == "expiry" ? snapshot.expiry : kind == "recent" ? snapshot.recentlyEaten : snapshot.low
                            ForEach(Array(rows.prefix(family == .systemLarge ? 4 : 2))) { row in
                                HStack {
                                    if kind == "shopping" { Button(intent: WidgetPurchaseIntent(shoppingID: row.id, accountTag: snapshot.accountTag)) { Image(systemName: "circle") }.buttonStyle(.plain) }
                                    Text(row.title).lineLimit(1); Spacer(); Text(row.detail).font(.caption)
                                }
                            }
                            if family == .systemLarge { Divider(); Text("\(entry.expiry) dates soon · \(entry.shopping) to buy").font(.caption); ForEach(Array(snapshot.recentlyEaten.prefix(2))) { row in Text("Eaten: " + row.title).font(.caption).lineLimit(1) } }
                        }
                    }
                    if let updated = entry.updated { Text(updated, style: .relative).font(.caption).foregroundStyle(.secondary) }
                    else { Text("Open Pantry to update").font(.caption) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.containerBackground(.fill.tertiary, for: .widget).widgetURL(destination)
    }
}
struct CountWidget: Widget {
    var kind: String
    var title: String
    init() { kind = "low"; title = "Low stock" }
    init(kind: String, title: String) { self.kind = kind; self.title = title }
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "pantry." + kind, provider: Provider()) { entry in Overview(entry: entry, kind: kind) }
            .configurationDisplayName(title).description("Cached Pantry counts. Open the app to synchronize.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
@main struct PantryWidgetBundle: WidgetBundle {
    var body: some Widget {
        ShoppingLiveActivity()
        CountWidget(kind: "low", title: "Low stock")
        CountWidget(kind: "shopping", title: "Shopping")
        CountWidget(kind: "expiry", title: "Recorded dates")
        CountWidget(kind: "inbox", title: "Link inbox")
        CountWidget(kind: "recent", title: "Recently eaten")
        CountWidget(kind: "sync", title: "Synchronization")
    }
}
