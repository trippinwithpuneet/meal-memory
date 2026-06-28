import SwiftUI

struct PlanTabView: View {
    let householdId: UUID
    @StateObject private var viewModel = MealPlanViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showAddRecipe = false
    @State private var showEmergencyMode = false

    var hasRecipes: Bool { !viewModel.recipes.isEmpty }
    var showOnboarding: Bool { viewModel.recipes.isEmpty && !viewModel.isLoading }

    var body: some View {
        NavigationStack {
            Group {
                if showOnboarding {
                    OnboardingEmptyStateView(showAddRecipe: $showAddRecipe)
                } else {
                    WeekGridView(viewModel: viewModel, householdId: householdId,
                                 onAddRecipeTapped: { showAddRecipe = true },
                                 onEmergencyTapped: { showEmergencyMode = true })
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showAddRecipe) {
            AddRecipeSheetView(householdId: householdId) { newRecipe in
                viewModel.recipes[newRecipe.id] = newRecipe
            }
        }
        .sheet(isPresented: $showEmergencyMode) {
            EmergencyModeView(
                recipes: Array(viewModel.recipes.values),
                householdId: householdId
            ) { recipe, date, mealType in
                Task { await viewModel.placeRecipe(recipe.id, on: date, mealType: mealType) }
            }
        }
        .task { await viewModel.load(householdId: householdId) }
        // Two-way sync between AppState.members and viewModel.members:
        // - When the Plan tab loads from DB, push to appState (HouseholdView picks it up)
        // - When HouseholdView edits a restriction, push to viewModel (conflict dot updates immediately)
        .onChange(of: viewModel.members) { _, loaded in
            if appState.members != loaded { appState.members = loaded }
        }
        .onChange(of: appState.members) { _, updated in
            if viewModel.members != updated { viewModel.members = updated }
        }
    }
}
