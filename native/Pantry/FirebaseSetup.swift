import Foundation
import FirebaseCore
#if DEBUG
import FirebaseAuth
import FirebaseFirestore
#endif

// A malformed local registration stays in device mode and explains how to repair it.
enum FirebaseSetup {
    static private(set) var issue: String?
    static func configure() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"), ProcessInfo.processInfo.arguments.contains("--firebase-emulator") {
            let options = FirebaseOptions(googleAppID: "1:123456789:ios:syntheticpantry", gcmSenderID: "123456789")
            options.apiKey = "synthetic-emulator-key"; options.projectID = "demo-pantry-native"
            FirebaseApp.configure(options: options)
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
            try? Auth.auth().signOut() // Fresh synthetic account per UI invocation; never used by release builds.
            Firestore.firestore().useEmulator(withHost: "127.0.0.1", port: 8080)
            return
        }
        #endif
        guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
        guard let file = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            issue = "Firebase is not configured. Run the local iOS configuration script with the registered iOS plist to enable sign-in."
            return
        }
        guard let options = FirebaseOptions(contentsOfFile: file), options.projectID == "logbook-e784a", options.bundleID == Bundle.main.bundleIdentifier else {
            issue = "Firebase registration does not match this app and the existing logbook-e784a project. Download the matching iOS plist and rerun configure-ios.py."
            return
        }
        let schemes = (Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []).flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        configureUsingPlist(file: file, options: options, schemes: schemes)
    }
    private static func configureUsingPlist(file: String, options: FirebaseOptions, schemes: [String]) {
        guard let data = FileManager.default.contents(atPath: file),
              let fields = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let reversed = fields["REVERSED_CLIENT_ID"] as? String, schemes.contains(reversed), options.clientID != nil else {
            issue = "Google sign-in URL scheme is missing. Rerun configure-ios.py with the registered iOS plist; it configures the redirect without editing source files."
            return
        }
        FirebaseApp.configure(options: options)
    }
}
