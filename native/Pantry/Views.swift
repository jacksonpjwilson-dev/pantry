import SwiftUI
import SwiftData
import FirebaseAuth
import Charts
import UniformTypeIdentifiers

private func number(_ value: Decimal) -> String { QuantityInput.formatted(value) }
private func recordedQuantity(_ source: [String: Any]) -> String {
    if let amount = source["amt"], !(amount is NSNull) { return "\(amount) \(source["unit"] as? String ?? "recorded units")" }
    return "\(source["q"] ?? 1) servings"
}
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
        .id(store.notificationScope)
        .safeAreaInset(edge: .top) { if !store.cacheWritable { Text("Local cache needs recovery. Existing storage is preserved.").font(.caption).padding().frame(maxWidth: .infinity).background(.orange.opacity(0.2)) } }
        .tint(colors[max(0, min(theme, colors.count - 1))])
        .preferredColorScheme(appearance == "auto" ? nil : appearance == "dark" ? .dark : .light)
        .sheet(item: $store.intentRequest) { request in
            NavigationStack { Form {
                Text("Account: \(store.user?.email ?? "This device only")")
                Text("\(request.name) · \(number(request.quantity))")
                Text(request.kind == "inventory" ? "Adds quantity in the food's existing inventory unit." : request.kind == "purchase" ? "Marks the shopping item complete without adding inventory." : "Adds a shopping item.")
                Button("Confirm") { Task { await store.perform { try await store.confirmIntent(request); store.intentRequest = nil } } }.disabled(!store.authenticationReady || store.busy || store.authenticating)
                Button("Cancel", role: .cancel) { store.intentRequest = nil }
            }.navigationTitle("Shortcut action") }
        }
        .task { store.start(context: context); await store.applyWidgetCommands() }
        .onChange(of: phase) { _, value in if value == .active { Task { await store.applyWidgetCommands(); await store.syncLogbook() } } }
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
        .navigationDestination(isPresented: Binding(get: { store.requestedPage != nil }, set: { if !$0 { store.requestedPage = nil } })) { HistoryView(reason: store.requestedPage == "recent" ? "eaten" : nil) }
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
    @State var scannedID: String?
    @State private var pendingBarcode: String?
    @State var filter = "all"
    var items: [InventoryItem] {
        store.state.items.filter { item in
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) || BarcodeIdentity.matches(item.barcode, search)) && (category == "All" || item.category == category) && (filter != "low" || item.status != "ok") && (filter != "expiry" || store.expiring.contains(where: { $0.id == item.id }))
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
        .onAppear { if filter == "all" { filter = store.requestedFilter }; if store.scanRequested { scanner = true; store.scanRequested = false } }
        .onChange(of: store.requestedFilter) { _, value in filter = value }
        .onChange(of: store.scanRequested) { _, value in if value { scanner = true; store.scanRequested = false } }
        .sheet(isPresented: $add) { ItemEditor(item: InventoryItem(name: ""), initialBarcode: barcode) }
        .sheet(isPresented: $scanner, onDismiss: {
            guard let code = pendingBarcode else { return }; pendingBarcode = nil
            if let found = store.state.items.first(where: { BarcodeIdentity.matches($0.barcode, code) }) { scannedID = found.id }
            else { barcode = code; add = true }
        }) { BarcodeScanner { code in pendingBarcode = code; scanner = false } }
        .navigationDestination(isPresented: Binding(get: { scannedID != nil }, set: { if !$0 { scannedID = nil } })) { if let id = scannedID { ItemDetail(id: id) } }
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
                    if let image = item.imageURL, let url = URL(string: image), url.scheme == "https" { AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }.frame(maxHeight: 200) }
                    Section { ItemRow(item: item); LabeledContent("Low at", value: item.lowAt.map(number) ?? "Not set")
                        if let expiry = item.expirationDate { LabeledContent(item.dateKind ?? "Expiration", value: expiry.formatted(date: .abbreviated, time: .omitted)) }
                        if let brand = item.brand, !brand.isEmpty { LabeledContent("Brand", value: brand) }
                        if let location = item.location, !location.isEmpty { LabeledContent("Location", value: location) }
                        if let notes = item.notes, !notes.isEmpty { Text(notes) }
                    }
                    Section("Adjust quantity") {
                        TextField("Amount", text: $amount).keyboardType(.decimalPad)
                        HStack { Button("Bought") { change(1, reason: "bought") }; Spacer(); Button("Used") { change(-1, reason: "manual") }; Spacer(); Button("Discard") { change(-1, reason: "discarded") } }.buttonStyle(.borderless)
                    }
                    Button("Add to shopping list") { Task { await store.perform { if !store.state.shopping.contains(where: { $0.itemId == id && !$0.purchased }) { store.state.shopping.append(ShoppingItem(name: item.name, itemId: id)); try await store.saveShopping() } } } }
                    QuantityChart(itemID: id, unit: item.unit)
                    NavigationLink("Item history") { HistoryView(itemID: id) }
                    Button("Delete item", role: .destructive) { confirmDelete = true }
                }.navigationTitle(item.name).toolbar { Button("Edit") { edit = true } }.sheet(isPresented: $edit) { ItemEditor(item: item) }
            } else { ContentUnavailableView("Item removed", systemImage: "cabinet") }
        }.confirmationDialog("Delete this item? Historical transactions will be retained.", isPresented: $confirmDelete) { Button("Delete", role: .destructive) { Task { await store.perform { try await store.delete(id); dismiss() } } } }
    }
    func change(_ sign: Int, reason: String) { Task { await store.perform { guard let value = QuantityInput.parse(amount), value > 0 else { throw InventoryError.invalidQuantity }; try await store.adjust(Adjustment(itemId: id, delta: value * Decimal(sign), reason: reason)) } } }
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
    @State var purchase = false
    @State var purchaseDate = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section("Food") { TextField("Name", text: $item.name); TextField("Category (custom allowed)", text: $item.category)
                    Picker("Unit", selection: $item.unit) { ForEach(Measures.units, id: \.self) { Text($0).tag($0) } }.disabled(store.state.items.contains(where: { $0.id == item.id }))
                    TextField("Low-stock threshold", text: $low).keyboardType(.decimalPad)
                    Text("Use quantity adjustments after saving to preserve the transaction history.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Details") { optionalText("Barcode", $item.barcode); optionalText("Brand", $item.brand); optionalText("Location", $item.location); optionalText("Notes", $item.notes); optionalText("Product image HTTPS URL", $item.imageURL)
                    Toggle("Record purchase date", isOn: $purchase)
                    if purchase { DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date) }
                    Toggle("Record a date", isOn: $expiry)
                    if expiry { Picker("Date type", selection: Binding(get: { item.dateKind ?? "Expiration" }, set: { item.dateKind = $0 })) { Text("Best before").tag("Best before"); Text("Expiration").tag("Expiration") }; DatePicker("Date", selection: $date, displayedComponents: .date); Text("Recorded dates alone do not determine food safety.").font(.caption) }
                }
            }.navigationTitle("Food details").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { saving = true; Task { await store.perform { guard low.isEmpty || QuantityInput.parse(low) != nil else { throw InventoryError.invalidQuantity }; item.lowAt = low.isEmpty ? nil : QuantityInput.parse(low); item.expirationDate = expiry ? date : nil; item.dateKind = expiry ? (item.dateKind ?? "Expiration") : nil; item.purchaseDate = purchase ? purchaseDate : nil; if let image = item.imageURL, !image.isEmpty, URL(string: image)?.scheme != "https" { throw InventoryErrorBridge.message("Product images require an HTTPS URL") }; try await store.save(item); dismiss() }; saving = false } }.disabled(saving) } }
        }.onAppear { low = item.lowAt.map(number) ?? ""; expiry = item.expirationDate != nil; date = item.expirationDate ?? Date(); purchase = item.purchaseDate != nil; purchaseDate = item.purchaseDate ?? Date(); if !initialBarcode.isEmpty { item.barcode = initialBarcode } }
    }
    func optionalText(_ name: String, _ value: Binding<String?>) -> some View { TextField(name, text: Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0 })) }
}
struct ShoppingView: View {
    @EnvironmentObject var store: PantryStore
    @State var name = ""
    @State var selected: String?
    @State var confirm = false
    @State var editing: ShoppingItem?
    @State var list = "Groceries"
    var body: some View {
        List {
            Picker("List", selection: $list) { ForEach(Array(Set(["Groceries"] + store.state.shopping.map(\.list))).sorted(), id: \.self) { Text($0).tag($0) } }
            Section("Shopping session") {
                Button("Start Live Activity") { Task { await store.perform { try ShoppingSession.start(completed: store.state.shopping.filter(\.purchased).count, total: store.state.shopping.count) } } }
                Button("Finish shopping session") { Task { await ShoppingSession.finish() } }
            }
            Section("Add to groceries") { HStack { TextField("Item", text: $name); Button("Add", systemImage: "plus") { Task { await store.perform { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; var row = ShoppingItem(name: name); row.list = list; store.state.shopping.append(row); name = ""; try await store.saveShopping() } } } } }
            Section("To buy") { ForEach(store.state.shopping.filter { !$0.purchased && $0.list == list }.sorted { $0.priority > $1.priority }) { row in Button { selected = row.id; confirm = true; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: { HStack { Image(systemName: "circle"); Text(row.name); Spacer(); Text(number(row.quantity)) } }.contextMenu { Button("Edit quantity, priority or list") { editing = row } } } }
            Section("Low-stock suggestions") { ForEach(store.low.filter { item in !store.state.shopping.contains { $0.itemId == item.id && !$0.purchased } }) { item in Button("Add \(item.name)") { Task { await store.perform { store.state.shopping.append(ShoppingItem(name: item.name, itemId: item.id, quantity: max(1, (item.lowAt ?? 0) - item.qty))); try await store.saveShopping() } } } } }
            Section("Shopping history") { ForEach(store.state.shopping.filter(\.purchased)) { row in HStack { Label(row.name, systemImage: "checkmark.circle.fill"); Spacer(); Button("Reorder") { Task { await store.perform { store.state.shopping.append(ShoppingItem(name: row.name, itemId: row.itemId, quantity: row.quantity)); try await store.saveShopping() } } } } } }
        }.navigationTitle("Shopping list")
        .sheet(item: $editing) { row in ShoppingEditor(row: row) }
        .confirmationDialog("Mark purchased", isPresented: $confirm) {
            if let id = selected { Button("Complete") { purchase(id, add: false) }; if store.state.shopping.first(where: { $0.id == id })?.itemId != nil { Button("Complete and add to inventory") { purchase(id, add: true) } } }
        } message: { Text("Inventory additions use a unique purchase ID to prevent duplicates.") }
    }
    func purchase(_ id: String, add: Bool) { Task { await store.perform { try await store.purchase(id, addInventory: add) } } }
}
struct InboxView: View {
    @EnvironmentObject var store: PantryStore
    var initialFoodID: String? = nil
    @State var newFood = false
    @State var chosen: String?
    @State var itemID = ""
    @State var per = "1"
    @State var linkMode = "per"
    @State var linkSearch = ""
    var body: some View {
        List {
            Text("Confirm how much one logged serving uses. No uncertain matches are applied automatically.").font(.caption).foregroundStyle(.secondary)
            ForEach(store.inbox.keys.sorted(), id: \.self) { key in
                let source = store.inbox[key] ?? [:]
                Button { chosen = String(describing: source["fid"] ?? "") } label: { VStack(alignment: .leading) { Text(source["food"] as? String ?? "Unknown food"); Text("\(source["date"] ?? "") · \(recordedQuantity(source))").font(.caption) } }
            }
            if store.inbox.isEmpty { ContentUnavailableView("All linked", systemImage: "link", description: Text("Unrecognized Logbook foods appear here after synchronization.")) }
        }.navigationTitle("Link inbox").refreshable { await store.syncLogbook() }
        .onAppear {
            if let fid = initialFoodID {
                let link = store.meta["links"]?[fid] as? [String: Any] ?? [:]
                itemID = link["itemId"] as? String ?? ""; per = (link["per"] as? NSNumber).map { QuantityInput.formatted($0.decimalValue) } ?? "1"
                linkMode = link["mode"] as? String ?? "per"; chosen = fid
            }
        }
        .sheet(isPresented: Binding(get: { chosen != nil }, set: { if !$0 { chosen = nil } })) {
            NavigationStack { Form {
                TextField("Search pantry foods", text: $linkSearch)
                Picker("Pantry food", selection: $itemID) { Text("Select an item").tag(""); ForEach(store.state.items.filter { linkSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(linkSearch) }.sorted { $0.name < $1.name }) { Text("\($0.name) (\($0.unit))").tag($0.id) } }
                Button("Create a new pantry food") { newFood = true }
                Picker("Relationship", selection: $linkMode) { Text("Verified units per serving").tag("per"); Text("Compatible recorded measurement").tag("auto") }
                if linkMode == "per" { TextField("Inventory units per logged serving", text: $per).keyboardType(.decimalPad) }
                else { Text("Only compatible measured units are converted. Missing measurements or mass/volume mismatches stop synchronization for review.").font(.caption) }
                Text("Already applied changes stay in History. Use Undo to reverse them; this relationship applies to future or waiting entries.").font(.caption)
                Button("Confirm relationship and sync") { guard let fid = chosen else { return }; Task { await store.perform { guard let amount = QuantityInput.parse(per), amount > 0 else { throw InventoryError.verificationRequired }; try await store.link(fid: fid, itemID: itemID, per: amount, mode: linkMode); chosen = nil } } }.disabled(itemID.isEmpty)
                Button("Ignore this food") { guard let fid = chosen else { return }; Task { await store.perform { try await store.ignore(fid: fid); chosen = nil } } }
            }.sheet(isPresented: $newFood) { ItemEditor(item: InventoryItem(name: "")) }.navigationTitle("Verify serving").toolbar { Button("Cancel") { chosen = nil } } }
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
                if let shortfall = row["unfulfilled"] as? NSNumber, shortfall.doubleValue != 0 { Text("Requested change: \(row["requestedDelta"] ?? "") \(row["unit"] ?? "") · Applied: \(row["delta"] ?? "") \(row["unit"] ?? "")").font(.caption) }
                Text(Date(timeIntervalSince1970: (row["ts"] as? Double ?? 0) / 1000).formatted()).font(.caption).foregroundStyle(.secondary)
                if let source = row["source"] as? [String: Any], let food = source["food"] as? String { Text("Logbook: \(food) · \(recordedQuantity(source)) · \(source["date"] ?? "")").font(.caption) }
                if row["undone"] as? Bool != true, row["reason"] as? String != "undo", let id = row["id"] as? String, let itemID = row["itemId"] as? String, store.state.items.contains(where: { $0.id == itemID }) { Button("Undo") { Task { await store.perform { try await store.undo(id) } } }.font(.caption).buttonStyle(.borderless) }
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
    @State var importing = false
    @State var preview: PantryStore.ImportPreview?
    @State var backupURL: URL?
    @State var cloudPreview: PantryStore.CloudMigrationPreview?
    struct PendingReview { var kind: String; var id: String }
    @State var pendingReview: PendingReview?
    @State var startDate = Date()
    @AppStorage("autoLowShopping") var autoLowShopping = false
    @AppStorage("notifyShopping") var notifyShopping = false
    @AppStorage("notifyReview") var notifyReview = false
    @AppStorage("notifyLow") var notifyLow = true
    @AppStorage("notifyExpiry") var notifyExpiry = true
    @AppStorage("quietStart") var quietStart = 22
    @AppStorage("expiryDays") var expiryDays = 3
    @AppStorage("quietEnd") var quietEnd = 8
    var body: some View {
        Form {
            Section("Account") {
                if let user = store.user { Text(user.email ?? "Signed in"); Button("Sign out") { Task { await store.perform { try store.signOut() } } }.disabled(store.busy || store.authenticating) }
                else {
                    Text("Device-only inventory stays separate when you sign in. No automatic migration or cloud replacement occurs.").font(.caption)
                    TextField("Email", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never)
                    SecureField("Password", text: $password); Toggle("Create account", isOn: $create)
                    Button(create ? "Create account" : "Sign in") { Task { await store.perform { try await store.email(email, password: password, create: create) } } }.disabled(!store.configured || !store.authenticationReady || store.busy || store.authenticating)
                    Button("Sign in with Google") { Task { await store.perform { try await store.google() } } }.disabled(!store.configured || !store.authenticationReady || store.busy || store.authenticating)
                    Button("Send password reset") { Task { await store.perform { guard store.configured else { return }; try await Auth.auth().sendPasswordReset(withEmail: email) } } }.disabled(!store.configured || !store.authenticationReady || store.busy || store.authenticating)
                }
                if !store.configured { Text(FirebaseSetup.issue ?? "Cloud is disabled for automated UI tests. Device-only mode works without it.").font(.caption) }
            }
            Section("Synchronization") {
                Toggle("Logbook v2 consumption sync", isOn: Binding(get: { store.logbookEnabled }, set: { enabled in Task { await store.perform { try await store.setLogbookEnabled(enabled) } } })).disabled(store.busy)
                DatePicker("Count Logbook food from", selection: $startDate, displayedComponents: .date)
                Button("Save consumption start date") { Task { await store.perform { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; try await store.setMeta("state", fields: ["startDate": formatter.string(from: startDate)]) } } }
                Text("Saved start date: \(store.meta["state"]?["startDate"] as? String ?? "Choose a date before syncing")").font(.caption)
                Text(store.status); Text("\(store.state.queue.count) queued quantity changes"); Button("Refresh inventory") { Task { await store.refresh() } }; Button("Check Logbook v2") { Task { await store.syncLogbook() } }; Text("Sync runs while Pantry is active. Native Logbook and Head Quarter adapters are not configured.").font(.caption) }
            if !store.state.queue.isEmpty || !(store.state.mutations ?? []).isEmpty || !(store.state.pendingShopping ?? []).isEmpty {
                Section("Review pending changes") {
                    ForEach(store.state.queue) { operation in Button("Quantity: \(operation.reason) \(number(operation.delta))") { pendingReview = PendingReview(kind: "quantity", id: operation.id) }.disabled(store.busy) }
                    ForEach(store.state.mutations ?? []) { operation in Button("Item details: \(store.state.items.first(where: { $0.id == operation.itemID })?.name ?? "Removed item")") { pendingReview = PendingReview(kind: "item", id: operation.id) }.disabled(store.busy) }
                    ForEach(store.state.pendingShopping ?? []) { row in Button("Shopping: \(row.name)") { pendingReview = PendingReview(kind: "shopping", id: row.id) }.disabled(store.busy) }
                }
            }
            if let links = store.meta["links"], !links.isEmpty {
                Section("Linked Logbook foods") { ForEach(links.keys.sorted(), id: \.self) { fid in
                    let link = links[fid] as? [String: Any] ?? [:]
                    NavigationLink("Change \(link["food"] as? String ?? fid) relationship") { InboxView(initialFoodID: fid) }
                    Button("Ignore \(link["food"] as? String ?? fid)") { Task { await store.perform { try await store.ignore(fid: fid) } } }
                } }
            }
            if let ignored = store.meta["ignored"], !ignored.isEmpty {
                Section("Ignored Logbook foods") { ForEach(ignored.keys.sorted(), id: \.self) { fid in Button("Restore \(ignored[fid] as? String ?? fid)") { Task { await store.perform { try await store.restoreIgnored(fid) } } } } }
            }
            Section("Appearance") {
                Picker("Mode", selection: $appearance) { Text("Automatic").tag("auto"); Text("Light").tag("light"); Text("Dark").tag("dark") }
                Picker("Colour", selection: $theme) { ForEach(Array(["Logbook Teal", "Midnight Navy & Gold", "Forest & Cream", "Sunset Coral", "Mono + Red", "Arctic", "Sand & Terracotta", "Electric Violet", "Graphite & Mint", "Aviator", "Rose & Charcoal", "Grey"].enumerated()), id: \.offset) { index, title in Text(title).tag(index) } }
            }
            Section("Low stock") { Toggle("Automatically add low-stock suggestions", isOn: $autoLowShopping) }
            Section("Notifications") {
                Toggle("Outstanding shopping reminders", isOn: $notifyShopping)
                Toggle("Synchronization and conflict review alerts", isOn: $notifyReview)
                Toggle("Low-stock reminders", isOn: $notifyLow)
                Toggle("Recorded date reminders", isOn: $notifyExpiry)
                Picker("Days before recorded date", selection: $expiryDays) { Text("Three").tag(3); Text("Seven").tag(7) }
                Stepper("Quiet hours start: \(quietStart):00", value: $quietStart, in: 0...23)
                Stepper("Quiet hours end: \(quietEnd):00", value: $quietEnd, in: 0...23)
                Button("Enable low-stock and date reminders") { Task { await store.perform { try await ReminderService.configure(items: store.state.items, scope: store.notificationScope, shoppingCount: store.state.shopping.filter { !$0.purchased }.count) } } }; Text("Optional local reminders use recorded dates. Open Pantry to update reminders after cloud changes.").font(.caption) }
            Section("Backups and migration") {
                Button("Prepare a private backup") { Task { await store.perform { backupURL = try store.exportBackup() } } }
                if let url = backupURL { ShareLink("Share backup", item: url) }
                if store.user != nil { Button("Review device-only import into cloud") { do { cloudPreview = try store.previewDeviceMigration() } catch { store.error = error.localizedDescription } } }
                Button("Import complete browser/device backup") { importing = true }.disabled(store.user != nil || !store.state.items.isEmpty || !store.history.isEmpty)
                Text("Import requires an empty device-only pantry and a complete backup. Review counts before confirming. Account sign-in never uploads it automatically.").font(.caption)
            }
            Section("Privacy") { Text("No private food records are sent to telemetry. Lock Screen widgets share counts only."); Button("Remove device-only data", role: .destructive) { remove = true }.disabled(store.user != nil) }
        }.navigationTitle("Settings")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do { let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }; preview = try store.previewBrowserImport(Data(contentsOf: url)) } catch { store.error = error.localizedDescription }
        }
        .sheet(item: $cloudPreview) { candidate in NavigationStack { Form {
            Text("Destination: \(store.user?.email ?? "Signed-in account")")
            Text("Import \(candidate.source.items.count) items, \(candidate.history.count) transactions and \(candidate.source.shopping.count) shopping records. The cloud pantry must be empty; existing records are never replaced. The device copy remains intact.")
            Text("An interrupted import can be resumed using this same device snapshot. Logbook sync is paused while the migration marker is pending.").font(.caption)
            Button("Confirm cloud import") { Task { await store.perform { try await store.migrateDevice(candidate); cloudPreview = nil } } }.disabled(store.busy)
            Button("Cancel", role: .cancel) { cloudPreview = nil }.disabled(store.busy)
        }.navigationTitle("Review cloud migration") } }
        .sheet(item: $preview) { candidate in NavigationStack { Form {
            Text("Import \(candidate.items.count) foods and \(candidate.ledger.count) historical transactions into this empty device-only pantry.")
            Text("Existing item and ledger identifiers will be retained. A copy of the original file is retained in the native backup.")
            Button("Confirm import") { Task { await store.perform { try store.importBrowser(candidate); preview = nil } } }
            Button("Cancel", role: .cancel) { preview = nil }
        }.navigationTitle("Review backup") } }
        .confirmationDialog("Keep the current cloud result?", isPresented: Binding(get: { pendingReview != nil }, set: { if !$0 { pendingReview = nil } })) {
            if let review = pendingReview { Button("Keep cloud data and stop retrying", role: .destructive) { Task { await store.perform { try await store.resolvePending(kind: review.kind, id: review.id); pendingReview = nil } } } }
        } message: { Text("Already saved changes remain in the cloud. The selected pending request will stop retrying after Pantry verifies the server. Use History to undo an applied quantity change.") }
        .confirmationDialog("Remove this device's local inventory and history?", isPresented: $remove) { Button("Remove", role: .destructive) { Task { await store.perform { try store.clearDevice() } } } }
    }
}

struct ShoppingEditor: View {
    @EnvironmentObject var store: PantryStore
    @Environment(\.dismiss) var dismiss
    @State var row: ShoppingItem
    @State var amount = "1"
    var body: some View {
        NavigationStack { Form {
            TextField("Name", text: $row.name)
            TextField("Quantity needed", text: $amount).keyboardType(.decimalPad)
            Picker("Optional inventory item", selection: Binding(get: { row.itemId ?? "" }, set: { row.itemId = $0.isEmpty ? nil : $0 })) {
                Text("Shopping only").tag("")
                ForEach(store.state.items) { Text("\($0.name) (\($0.unit))").tag($0.id) }
            }
            Text("Linked purchases add the entered quantity in that item's inventory unit, after confirmation.").font(.caption)
            TextField("Category", text: $row.category)
            TextField("List name", text: $row.list)
            Picker("Priority", selection: $row.priority) { Text("Normal").tag(0); Text("Soon").tag(1); Text("High").tag(2) }
        }.navigationTitle("Shopping item").toolbar {
            Button("Cancel") { dismiss() }
            Button("Save") { Task { await store.perform {
                guard let quantity = QuantityInput.parse(amount), quantity > 0, !row.name.trimmingCharacters(in: .whitespaces).isEmpty, !row.list.isEmpty else { throw InventoryError.invalidQuantity }
                row.quantity = quantity
                if let index = store.state.shopping.firstIndex(where: { $0.id == row.id }) { store.state.shopping[index] = row }
                try await store.saveShopping(); dismiss()
            } } }
        } }.onAppear { amount = number(row.quantity) }
    }
}
struct QuantityChart: View {
    @EnvironmentObject var store: PantryStore
    var itemID: String
    var unit: String
    struct Point: Identifiable { var id: String; var date: Date; var quantity: Double }
    var points: [Point] { store.history.filter { $0["itemId"] as? String == itemID && $0["unit"] as? String == unit }.compactMap { row in guard let id = row["id"] as? String, let ts = row["ts"] as? Double, let quantity = row["qtyAfter"] as? Double else { return nil }; return Point(id: id, date: Date(timeIntervalSince1970: ts / 1000), quantity: quantity) }.sorted { $0.date < $1.date } }
    var body: some View {
        if points.count > 1 { Section("Recorded quantity (\(unit))") { Chart(points) { point in LineMark(x: .value("Date", point.date), y: .value(unit, point.quantity)) }.frame(height: 150).accessibilityLabel("Inventory quantity history in \(unit)") } }
    }
}
