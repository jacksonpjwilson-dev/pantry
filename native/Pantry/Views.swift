import SwiftUI
import SwiftData
import FirebaseAuth
import Charts

private func number(_ value: Decimal) -> String { NSDecimalNumber(decimal: value).stringValue }
let categories = ["Fridge", "Freezer", "Pantry", "Produce", "Dairy", "Meat and fish", "Breakfast", "Baking", "Spices", "Snacks", "Drinks", "Household", "Other"]
struct RootView: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.modelContext) var context
    @Environment(\.scenePhase) var phase
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("theme") var theme = 0
    let colors: [Color] = [.teal, .indigo, .green, .orange, .red, .blue, .brown, .purple, .mint, .orange, .pink, .gray]
    var body: some View {
        TabView(selection: $store.route) {
            NavigationStack { Dashboard() }.tabItem { Label("Home", systemImage: "square.grid.2x2") }.tag("home")
            NavigationStack { InventoryView() }.tabItem { Label("Inventory", systemImage: "cabinet") }.tag("inventory")
            NavigationStack { ShoppingView() }.tabItem { Label("Shopping", systemImage: "cart") }.tag("shopping")
            NavigationStack { InboxView() }.tabItem { Label("Links", systemImage: "link") }.tag("inbox")
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }.tag("settings")
        }
        .tint(colors[max(0, min(theme, colors.count - 1))])
        .preferredColorScheme(appearance == "auto" ? nil : appearance == "dark" ? .dark : .light)
        .task { store.start(context: context) }
        .onChange(of: phase) { _, value in if value == .active { Task { await store.syncLogbook() } } }
        .alert("Pantry needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("OK") { store.error = nil } } message: { Text(store.error ?? "") }
    }
}
struct Dashboard: View {
    @EnvironmentObject var store: PantryStore
    @AppStorage("dashboardOrder") var order = "Low stock,Recently eaten,Link inbox,Bought,Shopping list,Expiring soon,History"
    @State var customize = false
    var cards: [String] { order.split(separator: ",").map(String.init) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("A little order. Less waste.").font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                    metric("Tracked", store.state.items.count); metric("In stock", store.state.items.filter { $0.qty > 0 }.count)
                    metric("Low", store.low.filter { $0.qty > 0 }.count); metric("Out", store.state.items.filter { $0.qty == 0 }.count)
                    metric("To link", store.inbox.count); metric("Shopping", store.state.shopping.filter { !$0.purchased }.count)
                }
                Label(store.status, systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary)
                if let date = store.lastSync { Text("Last successful sync \(date.formatted())").font(.caption) }
                ForEach(cards, id: \.self) { title in
                    NavigationLink { destination(title) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(title).font(.headline); Spacer(); Image(systemName: "chevron.right") }
                            Text(summary(title)).font(.subheadline).foregroundStyle(.secondary)
                        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 22)).shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    }.buttonStyle(.plain)
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle("Pantry")
        .refreshable { await store.syncLogbook() }
        .toolbar { Button("Customize", systemImage: "slider.horizontal.3") { customize = true } }
        .sheet(isPresented: $customize) { NavigationStack { List { ForEach(cards, id: \.self) { Text($0) }.onMove { source, destination in var array = cards; array.move(fromOffsets: source, toOffset: destination); order = array.joined(separator: ",") } }.environment(\.editMode, .constant(.active)).navigationTitle("Dashboard order").toolbar { Button("Done") { customize = false } } } }
    }
    func metric(_ title: String, _ count: Int) -> some View { VStack { Text("\(count)").font(.title.bold()); Text(title).font(.caption) }.frame(maxWidth: .infinity).padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 14)) }
    func summary(_ title: String) -> String {
        switch title {
        case "Low stock": return store.low.prefix(3).map(\.name).joined(separator: ", ").isEmpty ? "Everything stocked" : store.low.prefix(3).map(\.name).joined(separator: ", ")
        case "Link inbox": return "\(store.inbox.count) foods waiting for a verified relationship"
        case "Shopping list": return "\(store.state.shopping.filter { !$0.purchased }.count) items to buy"
        case "Expiring soon": return "\(store.expiring.count) recorded dates within seven days"
        case "Bought": return "Quickly add a purchase to your inventory"
        default: return "Browse your inventory transactions"
        }
    }
    @ViewBuilder func destination(_ title: String) -> some View {
        switch title {
        case "Low stock": InventoryView(filter: "low")
        case "Expiring soon": InventoryView(filter: "expiry")
        case "Shopping list": ShoppingView()
        case "Link inbox": InboxView()
        case "Bought": InventoryView()
        case "Recently eaten": HistoryView(reason: "eaten")
        default: HistoryView()
        }
    }
}
struct InventoryView: View {
    @EnvironmentObject var store: PantryStore
    @State var search = ""
    @State var category = "All"
    @State var sort = "Name"
    @State var add = false
    @State var scanner = false
    @State var barcode = ""
    @State var filter = "all"
    var items: [InventoryItem] {
        store.state.items.filter { item in
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || item.barcode == search) && (category == "All" || item.category == category) && (filter != "low" || item.status != "ok") && (filter != "expiry" || store.expiring.contains(where: { $0.id == item.id }))
        }.sorted { a, b in sort == "Quantity" ? a.qty < b.qty : sort == "Expiry" ? (a.expirationDate ?? .distantFuture) < (b.expirationDate ?? .distantFuture) : a.name.localizedStandardCompare(b.name) == .orderedAscending }
    }
    var body: some View {
        List {
            HStack {
                Picker("Category", selection: $category) { Text("All").tag("All"); ForEach(Array(Set(categories + store.state.items.map(\.category))).sorted(), id: \.self) { Text($0).tag($0) } }
                Picker("Sort", selection: $sort) { ForEach(["Name", "Quantity", "Expiry"], id: \.self) { Text($0).tag($0) } }
            }
            ForEach(items) { item in NavigationLink { ItemDetail(id: item.id) } label: { ItemRow(item: item) } }
            if items.isEmpty { ContentUnavailableView("Your shelves are ready", systemImage: "cabinet", description: Text("Add your first food or change your filters.")) }
        }.navigationTitle("Inventory").searchable(text: $search)
        .toolbar { Button("Scan", systemImage: "barcode.viewfinder") { scanner = true }; Button("Add", systemImage: "plus") { barcode = ""; add = true } }
        .sheet(isPresented: $add) { ItemEditor(item: InventoryItem(name: ""), initialBarcode: barcode) }
        .sheet(isPresented: $scanner) { BarcodeScanner { code in
            scanner = false
            if let found = store.state.items.first(where: { $0.barcode == code }) { search = found.name }
            else { barcode = code; add = true }
        } }
    }
}
struct ItemRow: View {
    var item: InventoryItem
    var body: some View { HStack { Image(systemName: item.status == "ok" ? "leaf" : "exclamationmark.circle").foregroundStyle(item.status == "ok" ? Color.teal : .orange); VStack(alignment: .leading) { Text(item.name); Text(item.category).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(number(item.qty)) \(item.unit)").monospacedDigit() } }
}
struct ItemDetail: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    var id: String
    @State var edit = false
    @State var amount = "1"
    @State var confirmDelete = false
    var item: InventoryItem? { store.state.items.first { $0.id == id } }
    var body: some View {
        Group {
            if let item {
                List {
                    Section { ItemRow(item: item); LabeledContent("Low at", value: item.lowAt.map(number) ?? "Not set")
                        if let expiry = item.expirationDate { LabeledContent(item.dateKind ?? "Expiration", value: expiry.formatted(date: .abbreviated, time: .omitted)) }
                        if let brand = item.brand, !brand.isEmpty { LabeledContent("Brand", value: brand) }
                        if let location = item.location, !location.isEmpty { LabeledContent("Location", value: location) }
                        if let notes = item.notes, !notes.isEmpty { Text(notes) }
                    }
                    Section("Adjust quantity") {
                        TextField("Amount", text: $amount).keyboardType(.decimalPad)
                        HStack { Button("Bought") { change(1, reason: "bought") }; Spacer(); Button("Used") { change(-1, reason: "manual") }; Spacer(); Button("Discard") { change(-1, reason: "discarded") } }
                    }
                    Button("Add to shopping list") { Task { await store.perform { if !store.state.shopping.contains(where: { $0.itemId == id && !$0.purchased }) { store.state.shopping.append(ShoppingItem(name: item.name, itemId: id)); try await store.saveShopping() } } } }
                    NavigationLink("Item history") { HistoryView(itemID: id) }
                    Button("Delete item", role: .destructive) { confirmDelete = true }
                }.navigationTitle(item.name).toolbar { Button("Edit") { edit = true } }.sheet(isPresented: $edit) { ItemEditor(item: item) }
            } else { ContentUnavailableView("Item removed", systemImage: "cabinet") }
        }.confirmationDialog("Delete this item? Historical transactions will be retained.", isPresented: $confirmDelete) { Button("Delete", role: .destructive) { Task { await store.perform { try await store.delete(id); dismiss() } } } }
    }
    func change(_ sign: Int, reason: String) { Task { await store.perform { guard let value = Decimal(string: amount), value > 0 else { throw InventoryError.invalidQuantity }; try await store.adjust(Adjustment(itemId: id, delta: value * Decimal(sign), reason: reason)) } } }
}
struct ItemEditor: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    @State var item: InventoryItem
    var initialBarcode = ""
    @State var low = ""
    @State var expiry = false
    @State var date = Date()
    @State var saving = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Food") { TextField("Name", text: $item.name); TextField("Category (custom allowed)", text: $item.category)
                    Picker("Unit", selection: $item.unit) { ForEach(Measures.units, id: \.self) { Text($0).tag($0) } }.disabled(store.state.items.contains(where: { $0.id == item.id }))
                    TextField("Low-stock threshold", text: $low).keyboardType(.decimalPad)
                    Text("Use quantity adjustments after saving to preserve the transaction history.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Details") { optionalText("Barcode", $item.barcode); optionalText("Brand", $item.brand); optionalText("Location", $item.location); optionalText("Notes", $item.notes)
                    Toggle("Record a date", isOn: $expiry)
                    if expiry { Picker("Date type", selection: Binding(get: { item.dateKind ?? "Best before" }, set: { item.dateKind = $0 })) { Text("Best before").tag("Best before"); Text("Expiration").tag("Expiration") }; DatePicker("Date", selection: $date, displayedComponents: .date); Text("Recorded dates alone do not determine food safety.").font(.caption) }
                }
            }.navigationTitle("Food details").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { saving = true; Task { await store.perform { guard low.isEmpty || Decimal(string: low) != nil else { throw InventoryError.invalidQuantity }; item.lowAt = low.isEmpty ? nil : Decimal(string: low); item.expirationDate = expiry ? date : nil; try await store.save(item); dismiss() }; saving = false } }.disabled(saving) } }
        }.onAppear { low = item.lowAt.map(number) ?? ""; expiry = item.expirationDate != nil; date = item.expirationDate ?? Date(); if !initialBarcode.isEmpty { item.barcode = initialBarcode } }
    }
    func optionalText(_ name: String, _ value: Binding<String?>) -> some View { TextField(name, text: Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 })) }
}
struct ShoppingView: View {
    @EnvironmentObject var store: PantryStore
    @State var name = ""
    @State var selected: String?
    @State var confirm = false
    var body: some View {
        List {
            Section("Add to groceries") { HStack { TextField("Item", text: $name); Button("Add", systemImage: "plus") { Task { await store.perform { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; store.state.shopping.append(ShoppingItem(name: name)); name = ""; try await store.saveShopping() } } } } }
            Section("To buy") { ForEach(store.state.shopping.filter { !$0.purchased }) { row in Button { selected = row.id; confirm = true; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: { HStack { Image(systemName: "circle"); Text(row.name); Spacer(); Text(number(row.quantity)) } } } }
            Section("Low-stock suggestions") { ForEach(store.low.filter { item in !store.state.shopping.contains { $0.itemId == item.id && !$0.purchased } }) { item in Button("Add \(item.name)") { Task { await store.perform { store.state.shopping.append(ShoppingItem(name: item.name, itemId: item.id, quantity: max(1, (item.lowAt ?? 0) - item.qty))); try await store.saveShopping() } } } } }
            Section("Shopping history") { ForEach(store.state.shopping.filter(\.purchased)) { row in HStack { Label(row.name, systemImage: "checkmark.circle.fill"); Spacer(); Button("Reorder") { Task { await store.perform { store.state.shopping.append(ShoppingItem(name: row.name, itemId: row.itemId, quantity: row.quantity)); try await store.saveShopping() } } } } } }
        }.navigationTitle("Shopping list")
        .confirmationDialog("Mark purchased", isPresented: $confirm) {
            if let id = selected { Button("Complete") { purchase(id, add: false) }; if store.state.shopping.first(where: { $0.id == id })?.itemId != nil { Button("Complete and add to inventory") { purchase(id, add: true) } } }
        } message: { Text("Inventory additions use a unique purchase ID to prevent duplicates.") }
    }
    func purchase(_ id: String, add: Bool) { Task { await store.perform { try await store.purchase(id, addInventory: add) } } }
}
struct InboxView: View {
    @EnvironmentObject var store: PantryStore
    @State var chosen: String?
    @State var itemID = ""
    @State var per = "1"
    var body: some View {
        List {
            Text("Confirm how much one logged serving uses. No uncertain matches are applied automatically.").font(.caption).foregroundStyle(.secondary)
            ForEach(store.inbox.keys.sorted(), id: \.self) { key in
                let source = store.inbox[key] ?? [:]
                Button { chosen = String(describing: source["fid"] ?? "") } label: { VStack(alignment: .leading) { Text(source["food"] as? String ?? "Unknown food"); Text("\(source["date"] ?? "") · \(source["amt"] ?? source["q"] ?? 1) \(source["unit"] ?? "servings")").font(.caption) } }
            }
            if store.inbox.isEmpty { ContentUnavailableView("All linked", systemImage: "link", description: Text("Unrecognized Logbook foods appear here after synchronization.")) }
        }.navigationTitle("Link inbox").refreshable { await store.syncLogbook() }
        .sheet(isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
            NavigationStack { Form {
                Picker("Pantry food", selection: $itemID) { Text("Select an item").tag(""); ForEach(store.state.items) { Text("\($0.name) (\($0.unit))").tag($0.id) } }
                TextField("Inventory units per logged serving", text: $per).keyboardType(.decimalPad)
                Button("Confirm relationship and sync") { guard let fid = chosen else { return }; Task { await store.perform { guard let amount = Decimal(string: per), amount > 0 else { throw InventoryError.verificationRequired }; try await store.link(fid: fid, itemID: itemID, per: amount); chosen = nil } } }.disabled(itemID.isEmpty)
                Button("Ignore this food") { guard let fid = chosen else { return }; Task { await store.perform { try await store.ignore(fid: fid); chosen = nil } } }
            }.navigationTitle("Verify serving").toolbar { Button("Cancel") { chosen = nil } } }
        }
    }
}
struct HistoryView: View {
    @EnvironmentObject var store: PantryStore
    var itemID: String? = nil
    var reason: String? = nil
    @State var search = ""
    var rows: [[String: Any]] { store.history.filter { (itemID == nil || $0["itemId"] as? String == itemID) && (reason == nil || $0["reason"] as? String == reason) && (search.isEmpty || String(describing: $0).localizedCaseInsensitiveContains(search)) }.sorted { ($0["ts"] as? Double ?? 0) > ($1["ts"] as? Double ?? 0) } }
    var body: some View {
        List(Array(rows.enumerated()), id: \.offset) { _, row in
            VStack(alignment: .leading, spacing: 6) {
                Text(row["itemName"] as? String ?? "Removed item").font(.headline)
                Text("\(row["qtyBefore"] ?? 0) → \(row["qtyAfter"] ?? 0) \(row["unit"] ?? "") · \(row["reason"] ?? "")")
                Text(Date(timeIntervalSince1970: (row["ts"] as? Double ?? 0) / 1000).formatted()).font(.caption).foregroundStyle(.secondary)
                if let source = row["source"] as? [String: Any], let food = source["food"] as? String { Text("Logbook: \(food) · \(source["date"] ?? "")").font(.caption) }
                if row["undone"] as? Bool != true, let id = row["id"] as? String { Button("Undo") { Task { await store.perform { try await store.undo(id) } } }.font(.caption) }
            }.padding(.vertical, 4)
        }.navigationTitle("History").searchable(text: $search)
    }
}
struct SettingsView: View {
    @EnvironmentObject var store: PantryStore
    @AppStorage("appearance") var appearance = "auto"
    @AppStorage("theme") var theme = 0
    @State var email = ""
    @State var password = ""
    @State var create = false
    @State var remove = false
    var body: some View {
        Form {
            Section("Account") {
                if let user = store.user { Text(user.email ?? "Signed in"); Button("Sign out") { Task { await store.perform { try store.signOut() } } } }
                else {
                    Text("Device-only inventory stays separate when you sign in. No automatic migration or cloud replacement occurs.").font(.caption)
                    TextField("Email", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never)
                    SecureField("Password", text: $password); Toggle("Create account", isOn: $create)
                    Button(create ? "Create account" : "Sign in") { Task { await store.perform { try await store.email(email, password: password, create: create) } } }.disabled(!store.configured)
                    Button("Sign in with Google") { Task { await store.perform { try await store.google() } } }.disabled(!store.configured)
                    Button("Send password reset") { Task { await store.perform { guard store.configured else { return }; try await Auth.auth().sendPasswordReset(withEmail: email) } } }.disabled(!store.configured)
                }
                if !store.configured { Text("Cloud not configured: add the registered iOS Firebase plist. Device-only mode works without it.").font(.caption) }
            }
            Section("Synchronization") { Text(store.status); Text("\(store.state.queue.count) queued quantity changes"); Button("Refresh inventory") { Task { await store.refresh() } }; Button("Check Logbook v2") { Task { await store.syncLogbook() } }; Text("Sync runs while Pantry is active. Native Logbook and Head Quarter adapters are not configured.").font(.caption) }
            Section("Appearance") {
                Picker("Mode", selection: $appearance) { Text("Automatic").tag("auto"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Picker("Colour", selection: $theme) { ForEach(Array(["Logbook Teal", "Midnight Navy & Gold", "Forest & Cream", "Sunset Coral", "Mono + Red", "Arctic", "Sand & Terracotta", "Electric Violet", "Graphite & Mint", "Aviator", "Rose & Charcoal", "Grey"].enumerated()), id: \.offset) { index, title in Text(title).tag(index) } }
            }
            Section("Notifications") { Button("Enable low-stock and date reminders") { Task { await store.perform { try await ReminderService.configure(items: store.state.items) } } }; Text("Optional local reminders use recorded dates. Open Pantry to update reminders after cloud changes.").font(.caption) }
            Section("Privacy") { Text("No private food records are sent to telemetry. Lock Screen widgets share counts only."); Button("Remove device-only data", role: .destructive) { remove = true }.disabled(store.user != nil) }
        }.navigationTitle("Settings").confirmationDialog("Remove this device's local inventory and history?", isPresented: $remove) { Button("Remove", role: .destructive) { Task { await store.perform { try store.clearDevice() } } } }
    }
}
