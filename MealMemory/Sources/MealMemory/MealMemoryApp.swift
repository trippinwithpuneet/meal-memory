import SwiftUI

@main
struct MealMemoryApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var appState = AppState()
    @AppStorage("demo_mode_active") private var demoModeActive: Bool = true

    var body: some Scene {
        WindowGroup {
            Group {
                if demoModeActive {
                    MainTabView(householdId: DemoData.householdId)
                } else if authService.isSignedIn {
                    if let householdId = appState.householdId {
                        MainTabView(householdId: householdId)
                    } else {
                        HouseholdSetupView()
                            .environmentObject(appState)
                    }
                } else {
                    AuthView()
                }
            }
            // The app has a single fixed light palette (cream/navy/saffron).
            // Without this, on a phone set to Dark Mode the system chrome
            // (search bar, tab bar, toolbar) renders dark while content stays
            // light — which is why it looked different on Rachel's phone vs the
            // (light-mode) simulator. Lock to light until a real dark theme exists.
            .preferredColorScheme(.light)
            .environmentObject(authService)
            .environmentObject(appState)
            .onAppear {
                if demoModeActive {
                    appState.members = DemoData.members
                } else {
                    appState.loadHousehold()
                }
            }
        }
    }
}

// MARK: - AppState (lightweight session state)

@MainActor
final class AppState: ObservableObject {
    @Published var householdId: UUID?
    @Published var members: [Member] = []

    private let key = "household_id"
    private let restrictionsKey = "member_dietary_restrictions"

    func loadHousehold() {
        if let stored = UserDefaults.standard.string(forKey: key),
           let id = UUID(uuidString: stored) {
            householdId = id
        }
    }

    func setHousehold(_ id: UUID) {
        householdId = id
        UserDefaults.standard.set(id.uuidString, forKey: key)
    }

    func clearHousehold() {
        householdId = nil
        members = []
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: restrictionsKey)
    }

    // Persist member edits locally so they survive across sessions
    // even when the DB write fails (e.g., Simulator QUIC issues).
    func saveLocalMemberData() {
        let data = members.map { m -> [String: Any] in
            ["id": m.id.uuidString,
             "name": m.displayName,
             "restrictions": m.dietaryRestrictions]
        }
        UserDefaults.standard.set(data, forKey: restrictionsKey)
    }

    // Call after loading members from DB — overlays locally-saved edits so
    // in-session changes aren't lost on re-launch if the DB write failed.
    func applyLocalRestrictions() {
        guard let arr = UserDefaults.standard.array(forKey: restrictionsKey)
                as? [[String: Any]] else { return }
        let byId = Dictionary(uniqueKeysWithValues: arr.compactMap { d -> (String, [String: Any])? in
            guard let id = d["id"] as? String else { return nil }
            return (id, d)
        })
        for i in members.indices {
            guard let saved = byId[members[i].id.uuidString] else { continue }
            if let name = saved["name"] as? String, !name.isEmpty {
                members[i].displayName = name
            }
            if let r = saved["restrictions"] as? [String] {
                members[i].dietaryRestrictions = r
            }
        }
    }
}
