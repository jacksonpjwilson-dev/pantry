import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main struct PantryApp: App {
    @StateObject private var store = PantryStore()
    init() {
        if let file = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"), let options = FirebaseOptions(contentsOfFile: file), options.projectID == "logbook-e784a" { FirebaseApp.configure(options: options) }
    }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).onOpenURL { url in
            if !GIDSignIn.sharedInstance.handle(url), url.scheme == "pantry" { store.route = url.host ?? "home" }
        } }.modelContainer(for: LocalSnapshot.self)
    }
}
