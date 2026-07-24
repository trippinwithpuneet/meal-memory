import SwiftUI

struct MainTabView: View {
    let householdId: UUID
    @EnvironmentObject private var importCoordinator: ImportCoordinator

    var body: some View {
        TabView {
            PlanTabView(householdId: householdId)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            RecipeBankView(householdId: householdId)
                .tabItem {
                    Label("Recipes", systemImage: "book.closed")
                }

            HouseholdView(householdId: householdId)
                .tabItem {
                    Label("Household", systemImage: "person.2")
                }
        }
        .tint(Theme.saffron)
        // A link shared into the app opens Add Recipe and auto-imports it.
        .sheet(item: $importCoordinator.pending) { item in
            AddRecipeSheetView(householdId: householdId, autoImportURL: item.url) { _ in }
        }
    }
}
