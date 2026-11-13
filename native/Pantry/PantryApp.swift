import SwiftUI
import SwiftData
import FirebaseCore
import GoogleSignIn

@main struct PantryApp: App {
    @StateObject private var store = PantryStore()
    init() {
        FirebaseSetup.configure()
    }
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).onOpenURL { url in
            if !GIDSignIn.sharedInstance.handle(url), url.scheme == "pantry" { store.open(url) }
        } }.modelContainer(for: LocalSnapshot.self)
    }
}
