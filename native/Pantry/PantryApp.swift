import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main struct PantryApp: App {
    @StateObject private var store = PantryStore()
    init() {
        if !ProcessInfo.processInfo.arguments.contains("--ui-testing"), let file = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"), let options = FirebaseOptions(contentsOfFile: file), options.projectID == "logbook-e784a" { FirebaseApp.configure(options: options) }
    }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).onOpenURL { url in
            if !GIDSignIn.sharedInstance.handle(url), url.scheme == "pantry" { store.open(url) }
        } }.modelContainer(for: LocalSnapshot.self)
    }
}
