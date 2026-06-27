import SwiftUI

struct MainTabView: View {
    let householdId: UUID

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
    }
}
