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
            ZStack(alignment: .bottom) {
                if showOnboarding {
                    OnboardingEmptyStateView(showAddRecipe: $showAddRecipe)
                } else {
                    WeekGridView(viewModel: viewModel, householdId: householdId,
                                 onAddRecipeTapped: { showAddRecipe = true })
                }

                // Emergency mode trigger — only visible when recipes exist
                if hasRecipes {
                    Button { showEmergencyMode = true } label: {
                        HStack(spacing: 6) {
                            Text("🚨")
                            Text("What can I cook tonight?")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.navy)
                        .cornerRadius(22)
                        .shadow(color: Theme.navy.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        if hasRecipes {
                            ShareLink(item: viewModel.weeklyGroceryList()) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(Theme.navy)
                            }
                        }
                        Button { showAddRecipe = true } label: {
                            Image(systemName: "plus")
                                .foregroundColor(Theme.navy)
                        }
                    }
                }
            }
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
