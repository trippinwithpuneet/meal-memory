import SwiftUI

struct PlanTabView: View {
    let householdId: UUID
    @StateObject private var viewModel = MealPlanViewModel()
    @EnvironmentObject private var appState: AppState
    @State private var showAddRecipe = false
    @State private var showEmergencyMode = false

    // First-run coach-mark tour (demo mode only, shown once).
    @AppStorage("has_seen_coachmarks") private var hasSeenCoachmarks = false
    @AppStorage("demo_mode_active") private var demoModeActive = true
    @State private var showCoachMarks = false
    @State private var showExitDemoConfirm = false

    var hasRecipes: Bool { !viewModel.recipes.isEmpty }
    var showOnboarding: Bool { viewModel.recipes.isEmpty && !viewModel.isLoading }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if demoModeActive {
                    DemoModeBanner { showExitDemoConfirm = true }
                }

                Group {
                    if showOnboarding {
                        OnboardingEmptyStateView(showAddRecipe: $showAddRecipe)
                    } else {
                        WeekGridView(viewModel: viewModel, householdId: householdId,
                                     onAddRecipeTapped: { showAddRecipe = true },
                                     onEmergencyTapped: { showEmergencyMode = true })
                    }
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
        // Coach-mark tour overlays the whole screen, reading target frames tagged
        // with `.coachAnchor(_:)` inside WeekGridView.
        .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if showCoachMarks {
                    CoachMarkOverlay(
                        rects: anchors.mapValues { proxy[$0] },
                        onFinish: {
                            withAnimation { showCoachMarks = false }
                            hasSeenCoachmarks = true
                        }
                    )
                }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Start fresh?", isPresented: $showExitDemoConfirm, titleVisibility: .visible) {
            Button("Start Fresh", role: .destructive) {
                showCoachMarks = false
                demoModeActive = false
            }
            Button("Keep Exploring", role: .cancel) {}
        } message: {
            Text("Demo data will be cleared. You'll create your own account and build your real recipe collection from scratch.")
        }
        .task {
            await viewModel.load(householdId: householdId)
            maybeStartCoachMarks()
        }
        .onChange(of: viewModel.isLoading) { _, _ in maybeStartCoachMarks() }
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

    // Kick off the tour once, only in demo mode and only when the grid is on
    // screen (so the anchors exist to point at).
    private func maybeStartCoachMarks() {
        guard demoModeActive, !hasSeenCoachmarks, !showCoachMarks,
              hasRecipes, !viewModel.isLoading else { return }
        // Small delay lets the grid lay out so anchor frames resolve before the ring draws.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard demoModeActive, !hasSeenCoachmarks, hasRecipes else { return }
            withAnimation(.easeInOut) { showCoachMarks = true }
        }
    }
}

// MARK: - Demo-mode banner

// Slim, dismiss-by-signup banner shown while exploring the sample data.
private struct DemoModeBanner: View {
    var onMakeYours: () -> Void

    var body: some View {
        Button(action: onMakeYours) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("You're exploring a sample week")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Theme.navy)
                    Text("Your data stays private when you sign up.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                Text("Make it yours")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Theme.saffron))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    // Adaptive: warm cream in light, warm-dark surface in dark so the
                    // off-white title (Theme.navy) stays legible.
                    colors: [Color(light: "#fff8f0", dark: "#2b2118"),
                             Color(light: "#fdecd8", dark: "#3a2c1c")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
        }
        .buttonStyle(.plain)
    }
}
